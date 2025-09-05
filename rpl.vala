#! /usr/bin/env -S vala --vapidir=. --pkg gio-2.0 --pkg gio-unix-2.0 --pkg posix --pkg gnu --pkg config --pkg cmdline --pkg pcre2 --pkg uchardet --pkg iconv prefix-stream.vala
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

/* Append to `a` the bytes of `b` from `start` to the end of `b`. */
private void append_string_builder_slice (StringBuilder a, StringBuilder b, ssize_t start, ssize_t end)
requires (0 <= start)
requires (start <= end)
requires (end <= b.len)
{
	a.append_len ((string) ((char *) b.str + start), end - start);
}

/* Append to `a` the bytes of `b` from `start` to the end of `b`. */
private void append_string_builder_tail (StringBuilder a, StringBuilder b, ssize_t start)
requires (0 <= start)
requires (start <= b.len) {
	append_string_builder_slice (a, b, start, b.len);
}

ssize_t replace (InputStream input,
                 string input_filename,
                 OutputStream? output,
                 Pcre2.Regex old_regex,
                 Pcre2.MatchFlags replace_opts,
                 StringBuilder new_pattern)
throws IOError {
	ssize_t num_matches = 0;
	size_t buf_size = 1024 * 1024;

	var tonext = new StringBuilder ();
	ssize_t tonext_offset = 0;
	var retry_prefix = new StringBuilder ();
	while (true) {
		// Read some data.
		ssize_t n_read = 0;
		var buf = new StringBuilder.sized (buf_size);
		append_string_builder_tail (buf, retry_prefix, 0);
		try {
			n_read = input.read (buf.data[buf.len: buf.allocated_len]);
		} catch (IOError e) {
			if (e.code == IOError.INVALID_DATA) {
				throw new IOError.INVALID_DATA ("error decoding input");
			} else if (e.code == IOError.PARTIAL_INPUT) {
				retry_prefix = new StringBuilder ();
				append_string_builder_slice (retry_prefix, buf, n_read, buf.len);
			} else {
				throw e;
			}
		}
		buf.len += n_read;
		if (args_info.verbose_given)
			warn (@"bytes read: $(n_read)\n");
		buf.len = retry_prefix.len + n_read;

		StringBuilder search_str;
		// If we have search data held over from last iteration, copy it
		// into a new buffer.
		if (tonext.len > 0) {
			search_str = new StringBuilder.sized (buf_size * 2);
			append_string_builder_tail (search_str, tonext, tonext_offset);
			append_string_builder_tail (search_str, buf, 0);
		} else {
			search_str = (owned) buf;
		}
		if (search_str.len == 0) {
			if (args_info.verbose_given)
				warn ("no input left, exiting");
			break;
		}

		var result = new StringBuilder ();
		size_t matching_from = 0;
		ssize_t start_pos;
		ssize_t end_pos = 0;
		Match? match = null;
		int rc = 0;
		while (true) {
			var do_partial = n_read > 0 ? Pcre2.MatchFlags.PARTIAL_HARD : 0;
			match = old_regex.match (search_str, matching_from, do_partial, out rc);
			if (rc == Pcre2.Error.NOMATCH) {
				tonext = new StringBuilder ();
				tonext_offset = 0;
				append_string_builder_tail (result, search_str, end_pos);
				break;
			} else if (rc < 0 && rc != Pcre2.Error.PARTIAL) { // GCOVR_EXCL_START
				warn (@"$input_filename: $(get_error_message(rc))");
				return -1; // GCOVR_EXCL_STOP
			}

			start_pos = (ssize_t) match.group_start (0);
			append_string_builder_slice (result, search_str, end_pos, start_pos);
			end_pos = (ssize_t) match.group_end (0);

			if (rc == Pcre2.Error.PARTIAL) {
				tonext_offset = start_pos;
				tonext = (owned) search_str;
				buf_size *= 2;
				break;
			} else
				num_matches += 1;

			var replacement = old_regex.substitute (
				search_str, matching_from,
				replace_opts | Pcre2.MatchFlags.NOTEMPTY | Pcre2.MatchFlags.SUBSTITUTE_MATCHED | Pcre2.MatchFlags.SUBSTITUTE_REPLACEMENT_ONLY,
				match,
				new_pattern,
				out rc
			);
			if (rc < 0) {
				warn (@"error in replacement: $(get_error_message(rc))");
				return -1;
			}

			if (args_info.match_case_given) {
				var model = new StringBuilder ();
				append_string_builder_slice (model, search_str, (ssize_t) match.group_start (0), (ssize_t) match.group_end (0));
				var recased = caselike (model, replacement);
				replacement = (owned) recased;
			}
			append_string_builder_tail (result, replacement, 0);
			matching_from = end_pos;
			if (start_pos == end_pos)
				matching_from += 1;
		}

		if (output != null) {
			size_t bytes_written;
			try {
				output.write_all (result.data, out bytes_written);
			} catch (IOError e) {
				if (e.code == IOError.INVALID_DATA) {
					throw new IOError.INVALID_DATA ("error encoding output");
				}
				throw e;
			}
		}
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
	    && args_info.verbose_given) // GCOVR_EXCL_START
		warn ("JIT compilation of regular expression failed");
	// GCOVR_EXCL_STOP

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
			Gnu.set_binary_mode (GLib.stdin.fileno (), Gnu.O_BINARY);
			input = new UnixInputStream (GLib.stdin.fileno (), false);
			Gnu.set_binary_mode (GLib.stdout.fileno (), Gnu.O_BINARY);
			output = new UnixOutputStream (GLib.stdout.fileno (), false);
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
				tmp_path = ".tmp.rpl-XXXXXX";
				var fd = FileUtils.mkstemp (tmp_path);
				if (fd == -1) { // GCOVR_EXCL_START
					warn (@"skipping $filename: cannot create temp file: $(Posix.strerror(errno))");
				} // GCOVR_EXCL_STOP
				output = new UnixOutputStream (fd, false);

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

		// If no encoding specified, reset guess for each file
		if (!args_info.encoding_given) {
			encoding = null;
		}

		if (args_info.verbose_given && !args_info.dry_run_given) {
			warn (@"processing $filename");
		}

		// If we don't have an explicit encoding, guess
		const int encoding_buf_size = 1024 * 1024;
		if (encoding == null) {
			var buf = new StringBuilder.sized (encoding_buf_size);
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
			var ok = detector.handle_data (buf.data);
			GLib.assert (ok == 0);
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

			// Prepend data sent to Uchardet to the rest of the input.
			input = new PrefixInputStream (buf.data, input);
		}

		// Set up character set conversion if required.
		if (encoding != null) {
			try {
				var iconverter = new CharsetConverter ("utf-8", encoding);
				input = new ConverterInputStream (input, iconverter);
				var oconverter = new CharsetConverter (encoding, "utf-8");
				output = new ConverterOutputStream (output, oconverter);
			} catch (GLib.Error e) {}
		}

		// Process the file
		ssize_t num_matches = 0;
		try {
			num_matches = replace (input, filename, output, regex, replace_opts, new_text);
		} catch (IOError e) { // GCOVR_EXCL_START
			warn (@"error processing $filename: $(e.message); skipping!");
			if (e.code == IOError.INVALID_DATA) {
				warn ("you can specify the encoding with --encoding");
			}
			try {
				input.close ();
			} catch (IOError e) {}
			num_matches = -1;
		} // GCOVR_EXCL_STOP

		try {
			input.close ();
		} catch (IOError e) { // GCOVR_EXCL_START
			warn (@"error closing $filename: $(e.message)");
		} // GCOVR_EXCL_STOP
		if (output != null) {
			try {
				output.close ();
			} catch (IOError e) { // GCOVR_EXCL_START
				warn (@"error closing $filename: $(e.message)");
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
					warn (@"error renaming $filename to $backup_name; error: $(GLib.strerror(errno))");
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
