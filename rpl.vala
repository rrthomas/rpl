#! /usr/bin/env -S vala --vapidir=. --pkg gio-2.0 --pkg posix --pkg gnu --pkg config --pkg cmdline --pkg pcre2 --pkg uchardet --pkg iconv fd-stream.vala prefix-input-stream.vala
// rpl: search and replace text in files
//
// © 2025 Reuben Thomas <rrt@sc3d.org>
//
// This program is free software; you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation; either version 3, or (at your option)
// any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; if not, see <https://www.gnu.org/licenses/>.

using Config;
using Posix;
using Pcre2;
using Gengetopt;


void info (string msg) {
	GLib.stderr.printf ("%s", @"$msg\n");
}

void warn (string msg) {
	info (@"$program_name: $msg");
}

void die (int code, string msg) { // GCOVR_EXCL_LINE
	warn (msg);
	exit (code);
}

enum Case {
	LOWER,
	UPPER,
	CAPITALIZED,
	MIXED
}

// A suitable buffer size for stream I/O.
const int STREAM_BUF_SIZE = 1024 * 1024;

private Case casetype (StringBuilder str)
requires (str.len > 0)
{
	if (Memory.cmp (str.str.up (str.len), str.str, str.len) == 0) {
		return Case.UPPER;
	} else if (Memory.cmp (str.str.down (), str.str, str.len) == 0) {
		return Case.LOWER;
	}

	int index = 0;
	unichar c = 0;
	var ok = str.str.get_next_char (ref index, out c);
	GLib.assert (ok);
	if (c.isupper ()) {
		// Could be capitalized
		bool all_lower = true;

		while (str.str.get_next_char (ref index, out c)) {
			if (!c.islower ()) {
				all_lower = false;
			}
		}
		if (all_lower) {
			return Case.CAPITALIZED;
		}
	}
	return Case.MIXED;
}

private StringBuilder caselike (StringBuilder model, StringBuilder str) {
	var res = new StringBuilder ();
	if (str.len > 0) {
		switch (casetype (model)) {
		case Case.LOWER:
			res.append_len (str.str.down (str.len), str.len);
			break;
		case Case.UPPER:
			res.append_len (str.str.up (str.len), str.len);
			break;
		case Case.CAPITALIZED: {
			int index = 0;
			unichar c = 0;
			var ok = str.str.get_next_char (ref index, out c);
			GLib.assert (ok);
			res.append_unichar (str.str.get_char ().toupper ());
			res.append_len (((string) ((char *) str.str + index)).down (str.len - index), str.len - index);
			break;
		}
		case Case.MIXED:
			res.append_len (str.str, str.len);
			break;
		}
	}
	return res;
}

// Append to `a` the bytes of `b` from `start` to the end of `b`.
private void append_string_builder_slice (StringBuilder a, StringBuilder b, ssize_t start, ssize_t end)
requires (0 <= start)
requires (start <= end)
requires (end <= b.len)
{
	a.append_len ((string) ((char *) b.str + start), end - start);
}

// Append to `a` the bytes of `b` from `start` to the end of `b`.
private void append_string_builder_tail (StringBuilder a, StringBuilder b, ssize_t start)
requires (0 <= start)
requires (start <= b.len) {
	append_string_builder_slice (a, b, start, b.len);
}

private StringBuilder? validate_utf8 (StringBuilder buf) {
	var retry_prefix = new StringBuilder ();
	// Check that input is valid UTF-8
	char *end_valid;
	buf.str.validate (buf.len, out end_valid);
	size_t num_valid = end_valid - (char *)buf.str;
	retry_prefix.append_len ((string) end_valid, (ssize_t) (buf.len - num_valid));
	buf.truncate (num_valid);
	if (end_valid == (char *) buf.str) { // GCOV_EXCL_START
		return null;
	} // GCOV_EXCL_STOP
	return retry_prefix;
}

private StringBuilder? to_utf8 (IConv.IConv iconv_in, ref StringBuilder buf) {
	var retry_prefix = new StringBuilder ();
	// Convert input to UTF-8
	unowned char[] buf_ptr = (char[]) buf.data;
	size_t buf_len = buf.len;
	// Guess maximum input:output ratio required.
	size_t out_buf_size = buf.len * 8;
	var out_buf = new StringBuilder.sized (out_buf_size);
	unowned char[] out_buf_ptr = (char[]) out_buf.data;
	size_t out_buf_len = out_buf_size;
	var rc = iconv_in.iconv (ref buf_ptr, ref buf_len, ref out_buf_ptr, ref out_buf_len);
	// Try carrying invalid input over to next iteration in case it's
	// just incomplete.
	retry_prefix.append_len ((string) buf_ptr, (ssize_t) buf_len);
	// If we failed to convert anything, error immediately.
	if (rc == -1 && buf_ptr == (char[]) buf.data) {
		return null;
	}
	size_t out_len = out_buf_size - out_buf_len;
	buf = (owned) out_buf;
	buf.len = (ssize_t) out_len;
	buf.truncate (buf.len);
	return retry_prefix;
}

private delegate ssize_t ReaderType (StringBuilder buf) throws IOError;
private delegate void WriterType (uint8 *buf, size_t len) throws IOError;

ssize_t replace (InputStream input,
                 string input_filename,
                 OutputStream? output,
                 Pcre2.Regex old_regex,
                 Pcre2.MatchFlags replace_opts,
                 StringBuilder new_pattern,
                 IConv.IConv? iconv_in,
                 IConv.IConv? iconv_out)
throws IOError {
	bool lookbehind = old_regex.pattern_info_maxlookbehind () != 0;
	ssize_t num_matches = 0;
	const size_t MAX_LOOKBEHIND_BYTES = 255 * 6; // 255 characters (PCRE2's hardwired limit) in UTF-8.
	size_t buf_size = STREAM_BUF_SIZE;
	var retry_prefix = new StringBuilder ();
	var at_bob = true;

	// Helper function to read input.
	ReaderType read_with_prefix = (buf) => {
		append_string_builder_tail (buf, retry_prefix, 0);
		size_t n_read = 0;
		do {
			input.read_all (
				((uint8[]) ((uint8*)buf.data + buf.len))[0 : size_t.min (buf_size - buf.len, STREAM_BUF_SIZE)],
				out n_read
			);
			buf.len += (ssize_t) n_read;
		} while (n_read > 0 && buf.len < buf_size);
		if (args_info.verbose_given) {
			warn (@"bytes read: $(n_read)\n");
		}
		return buf.len;
	};

	// Helper function to write output from a small output buffer.
	WriterType write_output = (buf, len) => {
		size_t tot_written = 0;
		do {
			size_t n_written;
			output.write_all (((uint8[]) (buf + tot_written))[0 : size_t.min (STREAM_BUF_SIZE, len - tot_written)], out n_written);
			tot_written += n_written;
		} while (tot_written < len);
	};

	var tonext = new StringBuilder ();
	var lookbehind_margin = new StringBuilder ();
	size_t n_read = 0;
	do {
		var buf = new StringBuilder.sized (buf_size);
		n_read = read_with_prefix (buf);

		// Convert or validate input, getting back any invalid suffix.
		if (buf.len == 0) {
			retry_prefix = new StringBuilder ();
		} else if (iconv_in == null) {
			retry_prefix = validate_utf8 (buf);
		} else {
			retry_prefix = to_utf8 (iconv_in, ref buf);
		}

		// If we failed to convert anything, error immediately.
		if (retry_prefix == null) {
			warn (@"error decoding $input_filename: $(GLib.strerror(errno))");
			if (args_info.encoding_given) {
				warn ("--encoding does not match file contents");
			} else {
				warn ("you can specify the encoding with --encoding"); // GCOV_EXCL_LINE
			}
			return -1;
		}

		StringBuilder search_str;
		// If we have no search data held over from last iteration, and
		// we're not using lookbehind, use the input directly.
		if (tonext.len == 0 && !lookbehind) {
			search_str = (owned) buf;
		} else {
			// If we're using lookbehind, use it as the start of the buffer.
			if (lookbehind) {
				search_str = new StringBuilder (lookbehind_margin.str);
				// Append any search data held over from last time.
				append_string_builder_tail (search_str, tonext, 0);
			} else {
				// If we're not using lookbehind, reuse `tonext`.
				search_str = (owned) tonext;
				tonext = new StringBuilder ();
			}
			// Finally, append the data we read.
			append_string_builder_tail (search_str, buf, 0);
		}

		var result = new StringBuilder ();
		size_t match_from = lookbehind_margin.len;
		ssize_t end_pos = lookbehind_margin.len;
		var do_partial = n_read > 0 ? Pcre2.MatchFlags.PARTIAL_HARD : 0;
		var notbol = at_bob ? 0 : Pcre2.MatchFlags.NOTBOL;
		while (true) {
			// Do match, and return on error.
			int rc = 0;
			Match? match = old_regex.match (search_str, match_from, do_partial | notbol | Pcre2.MatchFlags.NO_UTF_CHECK, out rc);
			if (rc < 0 && rc != Pcre2.Error.NOMATCH && rc != Pcre2.Error.PARTIAL) { // GCOVR_EXCL_START
				warn (@"$input_filename: $(get_error_message(rc))");
				return -1; // GCOVR_EXCL_STOP
			}

			// Append unmatched input to result.
			ssize_t start_pos = rc == Pcre2.Error.NOMATCH ? search_str.len : (ssize_t) match.group_start (0);
			append_string_builder_slice (result, search_str, end_pos, start_pos);
			end_pos = (ssize_t) match.group_end (0);

			// If the match is zero-width and at the end of the buffer, but
			// not the end of the input, treat it as partial.
			if (do_partial != 0 && start_pos == end_pos && start_pos == search_str.len) {
				rc = Pcre2.Error.PARTIAL;
			}

			// If we didn't get a match, break for more input.
			if (rc == Pcre2.Error.NOMATCH) {
				break;
			} else if (rc == Pcre2.Error.PARTIAL) {
				// For a partial match, copy text to re-match and grow buffer.
				tonext = new StringBuilder ();
				append_string_builder_tail (tonext, search_str, start_pos);
				match_from = start_pos;
				buf_size = size_t.max (buf_size, 2 * tonext.len + STREAM_BUF_SIZE);
				break;
			}

			// Perform substitutions.
			var replacement = old_regex.substitute (
				search_str, match_from,
				replace_opts | Pcre2.MatchFlags.NOTEMPTY | Pcre2.MatchFlags.SUBSTITUTE_MATCHED | Pcre2.MatchFlags.SUBSTITUTE_REPLACEMENT_ONLY | Pcre2.MatchFlags.NO_UTF_CHECK,
				match,
				new_pattern,
				out rc
			);
			if (rc < 0) {
				warn (@"error in replacement: $(get_error_message(rc))");
				return -1;
			}

			// Match case of replacement to case of original if required.
			if (args_info.match_case_given) {
				var model = new StringBuilder ();
				append_string_builder_slice (model, search_str, (ssize_t) match.group_start (0), (ssize_t) match.group_end (0));
				var recased = caselike (model, replacement);
				replacement = (owned) recased;
			}

			// Add replacement to result.
			append_string_builder_tail (result, replacement, 0);

			// Move past the match.
			num_matches += 1;
			match_from = end_pos;
			if (start_pos == end_pos) {
				// If we're at the end of the input, break.
				if (end_pos == search_str.len) {
					break;
				}
				unichar c;
				int c_len = 0;
				((string) ((char *)search_str.data + end_pos)).get_next_char (ref c_len, out c);
				match_from += c_len;
			}
		}

		// If we're using lookbehind, keep some of the buffer for next time.
		if (lookbehind) {
			lookbehind_margin = new StringBuilder ();
			append_string_builder_slice (
				lookbehind_margin,
				search_str,
				ssize_t.max (0, (ssize_t) (match_from - MAX_LOOKBEHIND_BYTES)),
				(ssize_t) match_from
			);
		}

		if (output != null) {
			// Write output.
			size_t bytes_written;
			if (iconv_out != null) {
				try {
					string converted = convert_with_iconv (result.str, result.len, (GLib.IConv) iconv_out, null, out bytes_written);
					write_output (converted.data, bytes_written);
				} catch (ConvertError e) {
					warn (@"output encoding error: $(GLib.strerror(errno))");
					return -1;
				}
			} else {
				write_output (result.data, result.len);
			}
		}

		at_bob = false;
	} while (n_read != 0);

	if (args_info.verbose_given) {
		warn ("no input left, exiting");
	}

	return num_matches;
}

string program_name;
ArgsInfo args_info;

void remove_temp_file (string tmp_path) {
	int rc = FileUtils.remove (tmp_path);
	if (rc < 0) { // GCOVR_EXCL_START
		warn (@"error removing temporary file $tmp_path: $(GLib.strerror(errno))");
	} // GCOVR_EXCL_STOP
}

// Adapted from https://valadoc.org/gio-2.0/GLib.File.enumerate_children.html
private List<string> get_dir_tree (File file) {
	var results = new List<string> ();
	try {
		FileEnumerator enumerator = file.enumerate_children (
			"standard::name,standard::type",
			FileQueryInfoFlags.NOFOLLOW_SYMLINKS,
			null);

		FileInfo info = null;
		while (((info = enumerator.next_file (null)) != null)) {
			File child = file.resolve_relative_path (info.get_name ());
			if (info.get_file_type () == FileType.DIRECTORY) {
				results.concat (get_dir_tree (child));
			} else {
				results.append (child.get_path ());
			}
		}
	} catch (GLib.Error e) { // GCOVR_EXCL_START
		warn (@"error while recursively examining $(file.get_path()): $(e.message)");
	} // GCOVR_EXCL_STOP
	return results;
}

StringBuilder slurp_patterns (string filename) {
	uint8[] input = null;
	try {
		FileUtils.get_data (filename, out input);
	} catch (GLib.Error e) {
		die (1, "error reading patterns file $(filename)");
	}
	return new StringBuilder.from_buffer ((char[]) input);
}

int main (string[] argv) {
	Intl.setlocale (ALL, "");

	string[] args;
#if WINDOWS
	args = Win32.get_command_line ();
#else
	args = argv;
#endif
	GLib.Log.set_always_fatal (LEVEL_CRITICAL);
	program_name = args[0];

	// Process command-line options
	args_info = {};
	// gengetopt parser always returns 0 or calls exit() itself.
	var res = ArgsInfo.parser (args, ref args_info);
	GLib.assert (res == 0);
	if (args_info.inputs.length < 2) {
		ArgsInfo.parser_print_help ();
		exit (EXIT_FAILURE);
	}

	// If no files given, assume stdin
	var files = new List<string> ();
	foreach (var file in args_info.inputs[2 : ]) {
		files.append (file);
	}
	if (files.length () == 0) {
		if (args_info.recursive_given) {
			die (1, "cannot use --recursive with no file arguments!");
		}
		files.append ("-");
	} else {
		// If we used --recursive, expand the list of files.
		if (args_info.recursive_given) {
			var expanded_files = new List<string> ();
			foreach (var file in files) {
				if (FileUtils.test (file, FileTest.IS_DIR)) {
					expanded_files.concat (get_dir_tree (File.new_for_path (file)));
				} else {
					expanded_files.append (file);
				}
			}
			files = (owned) expanded_files;
		}

		// Apply any globs.
		if (args_info.glob_given > 0) {
			var filtered_files = new List<string> ();
			foreach (var file in files) {
				for (var i = 0; i < args_info.glob_given; i++) {
					if (Posix.fnmatch (args_info.glob_arg[i], file, FNM_NOESCAPE | FNM_PERIOD) == 0) {
						filtered_files.append (file);
						break;
					}
				}
			}
			files = (owned) filtered_files;
		}

		// Check we do have some files to process.
		if (files.length () == 0) {
			die (1, "the given filename patterns did not match any files!");
		}
	}

	// Get old and new text patterns
	StringBuilder old_text;
	StringBuilder new_text;
	if (args_info.files_given) {
		old_text = slurp_patterns (args_info.inputs[0]);
		new_text = slurp_patterns (args_info.inputs[1]);
	} else {
		old_text = new StringBuilder (args_info.inputs[0]);
		new_text = new StringBuilder (args_info.inputs[1]);
	}

	// Tell the user what is going to happen
	if (!args_info.quiet_given) {
		warn ("%s \"%.*s\" with \"%.*s\" (%s; %s)".printf (
				  args_info.dry_run_given ? "simulating replacement of" : "replacing",
				  (int) old_text.len, old_text.str,
				  (int) new_text.len, new_text.str,
				  (args_info.ignore_case_given ? "ignoring case" : (args_info.match_case_given ? "matching case" : "case sensitive")),
				  args_info.whole_words_given ? "whole words only" : "partial words matched"
		));
	}

	if (args_info.dry_run_given && !args_info.quiet_given) {
		warn ("the files listed below would be modified in a replace operation");
	}

	string encoding = args_info.encoding_arg;

	var ccontext = new Pcre2.CompileContext ();
	if (args_info.whole_words_given) {
		ccontext.set_extra_options (Pcre2.ExtraCompileFlags.MATCH_WORD);
	}

	var opts = Pcre2.CompileFlags.MULTILINE | Pcre2.CompileFlags.UTF | Pcre2.CompileFlags.UCP;
	Pcre2.MatchFlags replace_opts = 0;
	if (args_info.fixed_strings_given) {
		opts = Pcre2.CompileFlags.LITERAL; // Override default options, which are incompatible with LITERAL.
		replace_opts |= Pcre2.MatchFlags.SUBSTITUTE_LITERAL;
	}
	if (args_info.ignore_case_given || args_info.match_case_given) {
		opts |= Pcre2.CompileFlags.CASELESS;
	}
	int errorcode;
	size_t erroroffset;
	var regex = Pcre2.Regex.compile ((Pcre2.Uchar[]) old_text.data, opts, out errorcode, out erroroffset, ccontext);
	if (regex == null) {
		die (1, "bad regex %.*s (%s)".printf ((int) old_text.len, old_text.str, get_error_message (errorcode)));
	}
	if (regex.jit_compile (JitCompileFlags.COMPLETE | JitCompileFlags.PARTIAL_HARD) != 0
	    && args_info.verbose_given) { // GCOVR_EXCL_START
		warn ("JIT compilation of regular expression failed");
	} // GCOVR_EXCL_STOP

	// Process files
	size_t total_files = 0;
	size_t matched_files = 0;
	size_t total_matches = 0;
	foreach (var filename in files) {
		bool have_perms = false;
		Posix.Stat perms = Posix.Stat () {};
		InputStream input;
		OutputStream output;
		string tmp_path = null;
		if (filename == "-") {
			filename = "standard input";
			Gnu.set_binary_mode (Posix.STDIN_FILENO, Gnu.O_BINARY);
			input = new FdInputStream (Posix.STDIN_FILENO);
			Gnu.set_binary_mode (Posix.STDOUT_FILENO, Gnu.O_BINARY);
			output = new FdOutputStream (Posix.STDOUT_FILENO);
		} else {
			// Check `filename` is a regular file, and get its permissions
			if (Posix.lstat (filename, out perms) != 0) {
				warn (@"skipping $filename: $(GLib.strerror(errno))");
				continue;
			}
			have_perms = true;
			if (S_ISDIR (perms.st_mode)) {
				warn (@"skipping directory $filename");
				continue;
			} else if (!S_ISREG (perms.st_mode)) {
				warn (@"skipping $filename: not a regular file");
				continue;
			}

			// Open the input file
			try {
				input = File.new_for_path (filename).read ();
			} catch (GLib.Error e) { // GCOVR_EXCL_START
				warn (@"skipping $filename: $(e.message)");
				continue;
			} // GCOVR_EXCL_STOP

			// Create the output file
			if (args_info.dry_run_given) {
				output = null;
			} else {
				tmp_path = Path.build_filename(Path.get_dirname (filename), ".tmp.rpl-XXXXXX");
				int fd = FileUtils.mkstemp (tmp_path);
				if (fd == -1) { // GCOVR_EXCL_START
					warn (@"skipping $filename: cannot create temp file: $(Posix.strerror(errno))");
					continue;
				} // GCOVR_EXCL_STOP
				output = new FdOutputStream (fd);

				// Set permissions and owner
				errno = 0;
				if ((Posix.chown (tmp_path, perms.st_uid, perms.st_gid) != 0 && errno != ENOSYS)
				    || Posix.chmod (tmp_path, perms.st_mode) != 0) {
					warn (@"unable to set attributes of $filename: $(GLib.strerror(errno))");
					if (args_info.force_given) {
						warn ("new file attributes may not match!");
					} else {
						warn (@"skipping $filename!");
						remove_temp_file (tmp_path);
						continue;
					}
				}
			}
		}

		total_files += 1;

		if (args_info.verbose_given && !args_info.dry_run_given) {
			warn (@"processing $filename");
		}

		// If we don't have an explicit encoding, guess
		var buf = new StringBuilder.sized (STREAM_BUF_SIZE);
		if (!args_info.encoding_given) {
			var detector = new UCharDet ();

			// Scan at most 1MB, so we don't slurp a large file
			try {
				size_t n_bytes = 0;
				input.read_all (buf.data[buf.len: buf.allocated_len], out n_bytes);
				buf.len += (ssize_t) n_bytes;
				if (args_info.verbose_given)
					warn (@"bytes read to guess encoding: $(buf.len)\n");
			} catch (IOError e) { // GCOVR_EXCL_START
				warn (@"error reading $filename: $(e.message); skipping!");
				continue;
			} // GCOVR_EXCL_STOP
			var ok = detector.handle_data (buf.data) == 0;
			GLib.assert (ok);
			detector.data_end ();
			var encoding_guessed = false;
			encoding = detector.get_charset ();
			if (encoding != "") {
				if (args_info.verbose_given) {
					warn (@"guessed encoding '$encoding'");
				}
				encoding_guessed = true;
			} else { // GCOVR_EXCL_START
				encoding = null;
				if (args_info.verbose_given) {
					warn ("unable to guess encoding");
				}
			} // GCOVR_EXCL_STOP

			// Use locale encoding if none guessed.
			if (encoding == null) { // GCOVR_EXCL_START
				get_charset (out encoding);
				if (args_info.verbose_given) {
					warn (@"could not guess encoding; using locale default '$encoding'");
				}
			} // GCOVR_EXCL_STOP

			if (encoding_guessed && (encoding == "ASCII" || encoding == "UTF-8")) {
				if (args_info.verbose_given) {
					warn (@"guessed an encoding that does not require iconv");
				}
				encoding = null;
			}

			// Prepend data sent to UCharDet to the rest of the input.
			input = new PrefixInputStream (buf.data, input);
		}

		// Process the file
		ssize_t num_matches = 0;
		IConv.IConv? iconv_in = null;
		IConv.IConv? iconv_out = null;
		if (encoding != null) {
			iconv_in = IConv.IConv.open ("UTF-8", encoding);
			iconv_out = IConv.IConv.open (encoding, "UTF-8");
		}
		try {
			num_matches = replace (input, filename, output, regex, replace_opts, new_text, iconv_in, iconv_out);
		} catch (IOError e) { // GCOVR_EXCL_START
			warn (@"error processing $filename: $(e.message); skipping!");
			try {
				input.close ();
			} catch (IOError e) {}
			num_matches = -1;
		} // GCOVR_EXCL_STOP
		if (iconv_in != null) {
			iconv_in.close ();
			iconv_out.close ();
		}

		try {
			input.close ();
		} catch (IOError e) { // GCOVR_EXCL_START
			warn (@"error closing $filename: $(GLib.strerror(errno))");
		} // GCOVR_EXCL_STOP
		if (output != null) {
			try {
				output.close ();
			} catch (IOError e) { // GCOVR_EXCL_START
				warn (@"error closing output: $(GLib.strerror(errno))");
			} // GCOVR_EXCL_STOP
		}

		// Delete temporary file if either we had an error (num_matches < 0)
		// or nothing changed (num_matches == 0).
		if (num_matches <= 0) {
			if (tmp_path != null) {
				remove_temp_file (tmp_path);
			}
			continue;
		}
		matched_files += 1;

		if (args_info.prompt_given) {
			GLib.stderr.printf (@"\nUpdate \"$filename\"? [Y/n] ");

			string line = null;
			do {
				line = GLib.stdin.read_line ();
			} while (line != "" && !"YyNn".contains (line[0].to_string ()));

			if (line != "" && "Nn".contains (line[0].to_string ())) {
				info ("Not updated");
				if (tmp_path != null) {
					remove_temp_file (tmp_path);
				}
				continue;
			}

			info ("Updated");
		}

		if (tmp_path != null) {
			if (args_info.backup_given) {
				string backup_name = @"$filename~";
				var rc = FileUtils.rename (filename, backup_name);
				if (rc < 0) {
					warn (@"error renaming $filename to $backup_name: $(GLib.strerror(errno))");
					remove_temp_file (tmp_path);
					continue;
				}
			}

			// Overwrite the result
			try {
				var src = File.new_for_path (tmp_path);
				var dst = File.new_for_path (filename);
				src.move (dst, FileCopyFlags.OVERWRITE);
			} catch (GLib.Error e) {
				warn (@"could not move $tmp_path to $filename: $(GLib.strerror(errno))");
				remove_temp_file (tmp_path);
				continue;
			}

			// Restore the times
			if (args_info.keep_times_given && have_perms) {
				timespec times[] = { (timespec) Gnu.get_stat_atime (perms), (timespec) Gnu.get_stat_mtime (perms) };
				var rc2 = utimensat (AT_FDCWD, filename, times);
				if (rc2 < 0) { // GCOVR_EXCL_START
					warn (@"error setting timestamps of $filename: $(GLib.strerror(errno))");
				} // GCOVR_EXCL_STOP
			}
		}

		total_matches += num_matches;
	}

	// We're about to exit, give a summary
	if (!args_info.quiet_given) {
		warn ("%zu matches %s in %zu out of %zu file%s".printf (
				  total_matches,
				  args_info.dry_run_given ? "found" : "replaced",
				  matched_files,
				  total_files,
				  total_files != 1 ? "s" : ""
		));
	}

	return EXIT_SUCCESS;
}
