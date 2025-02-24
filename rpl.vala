#! /usr/bin/env -S vala --vapidir=. --pkg gio-2.0 --pkg gio-unix-2.0 --pkg posix --pkg config --pkg cmdline --pkg pcre2 --pkg uchardet --pkg iconv slurp.vala
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


void info(string msg) {
	GLib.stderr.printf("%s", @"$msg\n");
}

void warn(string msg) {
	info(@"$program_name: $msg");
}

void die(int code, string msg) {
	warn(msg);
	exit(code);
}

enum Case {
	LOWER,
	UPPER,
	CAPITALIZED,
	MIXED
}

private Case casetype(StringBuilder str)
requires(str.len > 0)
{
	if (Memory.cmp(str.str.up(str.len), str.str, str.len) == 0) {
		return Case.UPPER;
	} else if (Memory.cmp(str.str.down(), str.str, str.len) == 0) {
		return Case.LOWER;
	}

	if (str.str[0].isupper()) {
		// Could be capitalized
		bool all_lower = true;

		for (var i = 1; i < str.len; i++) {
			if (!str.str[i].islower()) {
				all_lower = false;
			}
		}
		if (all_lower) {
			return Case.CAPITALIZED;
		}
	}
	return Case.MIXED;
}

private StringBuilder caselike(StringBuilder model, StringBuilder str) {
	if (str.len > 0) {
		switch (casetype(model)) {
		case Case.LOWER:
			var res = new StringBuilder();
			res.append_len(str.str.down(str.len), str.len);
			return res;
		case Case.UPPER:
			var res = new StringBuilder();
			res.append_len(str.str.up(str.len), str.len);
			return res;
		case Case.CAPITALIZED:
			var res = new StringBuilder();
			res.append_len(str.str.down(str.len), str.len);
			res.str.data[0] = res.str[0].toupper();
			return res;
		case Case.MIXED:
			var res = new StringBuilder();
			res.append_len(str.str, str.len);
			return res;
		}
	}
	return new StringBuilder();
}

ssize_t replace(int input_fd,
                owned StringBuilder initial_buf,
                string input_filename,
                int output_fd,
                Pcre2.Regex old_regex,
                int regex_opts,
                StringBuilder new_pattern,
                string? encoding) {
	ssize_t num_matches = 0;
	size_t buf_size = 1024 * 1024;

	var tonext = new StringBuilder();
	var retry_prefix = new StringBuilder();
	IConv.IConv? iconv_in = null;
	IConv.IConv? iconv_out = null;
	if (encoding != null && encoding != "ASCII" && encoding != "UTF-8") {
		iconv_in = IConv.IConv.open("UTF-8", encoding);
		iconv_out = IConv.IConv.open(encoding, "UTF-8");
	}
	var buf = (owned) initial_buf;
	ssize_t n_read = buf.len;
	while (true) {
		if (buf.len == 0) {
			Memory.copy(buf.data, retry_prefix.data, retry_prefix.len);
			n_read = Posix.read(input_fd, ((uint8*) buf.data) + retry_prefix.len, buf_size - retry_prefix.len);
			if (n_read < 0) {
				warn(@"error reading $input_filename: $(GLib.strerror(errno))\n");
				break;
			}
			buf.len = retry_prefix.len + n_read;
		}

		if (iconv_in != null && buf.len > 0) {
			char* buf_ptr = buf.data;
			size_t buf_len = buf.len;
			// Guess maximum input:output ratio required.
			size_t out_buf_size = buf.len * 8;
			var out_buf = new char[out_buf_size];
			char* out_buf_ptr = out_buf;
			size_t out_buf_len = out_buf.length;
			var rc = iconv_in.iconv(ref buf_ptr, ref buf_len, ref out_buf_ptr, ref out_buf_len);
			if (rc == -1) {
				// Try carrying invalid input over to next iteration in case it's
				// just incomplete.
				if (buf_ptr != buf.data) {
					retry_prefix = new StringBuilder.sized(buf_len);
					Memory.copy(retry_prefix.data, buf_ptr, buf_len);
					retry_prefix.len = (ssize_t) buf_len;
				} else {
					warn(@"error decoding $input_filename: $(GLib.strerror(errno))");
					warn("You can specify the encoding with --encoding");
					iconv_in.close();
					iconv_out.close();
					return -1;
				}
			} else {
				retry_prefix = new StringBuilder();
			}
			size_t out_len = out_buf_size - out_buf_len;
			buf = new StringBuilder.sized(out_len);
			Memory.copy(buf.data, out_buf, out_len);
			buf.len = (ssize_t) out_len;
		}

		var search_str = new StringBuilder.sized(buf_size * 2);

		search_str.append_len(tonext.str, tonext.len);
		search_str.append_len(buf.str, buf.len);
		if (search_str.len == 0) {
			break;
		}
		var result = new StringBuilder();
		size_t matching_from = 0;
		size_t start_pos;
		size_t end_pos = 0;
		Match ? match = null;
		int rc = 0;
		while (matching_from < search_str.len) {
			var do_partial = n_read > 0 ? Pcre2.MatchFlags.PARTIAL_HARD : 0;
			match = old_regex.match(search_str, matching_from, do_partial, out rc);
			if (rc != Pcre2.Error.NOMATCH) {
				if (rc == Pcre2.Error.PARTIAL) {
					tonext = (owned) search_str;
					buf_size *= 2;
					break;
				} else if (rc < 0) {
					if (iconv_in != null) {
						iconv_in.close();
						iconv_out.close();
					}
					warn(@"$input_filename: $(get_error_message(rc))");
					return -1;
				}
				start_pos = match.group_start(0);
				end_pos = match.group_end(0);
				result.append_len((string) ((uint8*) search_str.data + matching_from), (ssize_t) (start_pos - matching_from));
				num_matches += 1;

				var new_pattern_str = new StringBuilder.sized(new_pattern.len);
				new_pattern_str.append_len(new_pattern.str, new_pattern.len);
				var output = old_regex.substitute(
				                                  search_str, matching_from,
				                                  Pcre2.MatchFlags.NOTEMPTY | Pcre2.MatchFlags.SUBSTITUTE_MATCHED | Pcre2.MatchFlags.SUBSTITUTE_OVERFLOW_LENGTH | Pcre2.MatchFlags.SUBSTITUTE_REPLACEMENT_ONLY,
				                                  match,
				                                  new_pattern_str,
				                                  out rc
				);

				if (args_info.match_case_given) {
					var model_len = (ssize_t) (match.group_end(0) - match.group_start(0));
					var model = new StringBuilder.sized(model_len);
					model.append_len((string) ((uint8*) search_str.data + match.group_start(0)), model_len);
					var recased = caselike(model, output);
					output = (owned) recased;
				}
				result.append_len(output.str, output.len);
				matching_from = end_pos;
				if (start_pos == end_pos) {
					matching_from += 1;
				}
			} else {
				matching_from = search_str.len;
			}
		}
		if (match != null && rc != Pcre2.Error.PARTIAL) {
			tonext = new StringBuilder();
			result.append_len((string) ((uint8*) search_str.data + end_pos), (ssize_t) (search_str.len - end_pos));
		}

		ssize_t write_res = 0;
		if (iconv_out != null) {
			try {
				size_t bytes_written;
				string output = convert_with_iconv(result.str, result.len, (GLib.IConv) iconv_out, null, out bytes_written);
				write_res = Posix.write(output_fd, output, bytes_written);
			} catch (ConvertError e) {
				warn(@"output encoding error: $(GLib.strerror(errno))\n");
				iconv_in.close();
				iconv_out.close();
				return -1;
			}
		} else {
			write_res = Posix.write(output_fd, result.data, result.len);
		}
		if (write_res < 0) {
			warn(@"write error: $(GLib.strerror(errno))\n");
		}

		// Reset buffer for next iteration
		buf = new StringBuilder.sized(buf_size + 16);
	}

	return num_matches;
}

string program_name;
ArgsInfo args_info;

void remove_temp_file(string tmp_path) {
	int rc = FileUtils.remove(tmp_path);
	if (rc < 0) {
		warn(@"Error removing temporary file $tmp_path: $(GLib.strerror(errno))\n");
	}
}

// Adapted from https://valadoc.org/gio-2.0/GLib.File.enumerate_children.html
private List<string> get_dir_tree(File file) {
	var results = new List<string> ();
	try {
		FileEnumerator enumerator = file.enumerate_children(
		                                                    "standard::name,standard::type",
		                                                    FileQueryInfoFlags.NOFOLLOW_SYMLINKS,
		                                                    null);

		FileInfo info = null;
		while (((info = enumerator.next_file(null)) != null)) {
			File child = file.resolve_relative_path(info.get_name());
			if (info.get_file_type() == FileType.DIRECTORY) {
				results.concat(get_dir_tree(child));
			} else {
				results.append(child.get_path());
			}
		}
	} catch (GLib.Error e) {
		warn(@"error while recursively examining $(file.get_path()): $(e.message)");
	}
	return results;
}

int main(string[] args) {
	GLib.Log.set_always_fatal(LEVEL_CRITICAL);
	program_name = args[0];

	// Process command-line options
	args_info = {};
	if (ArgsInfo.parser(args, ref args_info) != 0) {
		exit(EXIT_FAILURE);
	}
	if (args_info.inputs.length < 2) {
		ArgsInfo.parser_print_help();
		exit(EXIT_FAILURE);
	}

	// If no files given, assume stdin
	var files = new List<string> ();
	foreach (var file in args_info.inputs[2 : ]) {
		files.append(file);
	}
	if (files.length() == 0) {
		if (args_info.recursive_given) {
			die(1, "cannot use --recursive with no file arguments!");
		}
		files.append("-");
	} else {
		// If we used --recursive, expand the list of files.
		if (args_info.recursive_given) {
			var expanded_files = new List<string> ();
			foreach (var file in files) {
				expanded_files.concat(get_dir_tree(File.new_for_path(file)));
			}
			files = (owned) expanded_files;
		}

		// Apply any globs.
		if (args_info.glob_given > 0) {
			var filtered_files = new List<string> ();
			foreach (var file in files) {
				for (var i = 0; i < args_info.glob_given; i++) {
					if (Posix.fnmatch(args_info.glob_arg[i], file, FNM_NOESCAPE | FNM_PERIOD) == 0) {
						filtered_files.append(file);
						break;
					}
				}
			}
			files = (owned) filtered_files;
		}

		// Check we do have some files to process.
		if (files.length() == 0) {
			die(1, "the given filename patterns did not match any files!");
		}
	}

	// Get old and new text patterns
	StringBuilder old_text;
	StringBuilder new_text;
	if (args_info.files_given) {
		old_text = slurp(File.new_for_commandline_arg(args_info.inputs[0]));
		new_text = slurp(File.new_for_commandline_arg(args_info.inputs[1]));
	} else {
		old_text = new StringBuilder(args_info.inputs[0]);
		new_text = new StringBuilder(args_info.inputs[1]);
	}

	// # Tell the user what is going to happen
	if (!args_info.quiet_given) {
		warn("%s \"%.*s\" with \"%.*s\" (%s; %s)".printf(
		                                                 args_info.dry_run_given ? "Simulating replacement of" : "Replacing",
		                                                 (int) old_text.len, old_text.str,
		                                                 (int) new_text.len, new_text.str,
		                                                 (args_info.ignore_case_given ? "ignoring case" : (args_info.match_case_given ? "matching case" : "case sensitive")),
		                                                 args_info.whole_words_given ? "whole words only" : "partial words matched"
		));
	}

	if (args_info.dry_run_given && !args_info.quiet_given) {
		warn("the files listed below would be modified in a replace operation");
	}

	string encoding = args_info.encoding_arg;

	var opts = Pcre2.CompileFlags.MULTILINE;
	if (args_info.fixed_strings_given) {
		opts |= Pcre2.CompileFlags.LITERAL;
	}
	if (args_info.whole_words_given) {
		opts |= Pcre2.CompileFlags.EXTRA_MATCH_WORD;
	}
	if (args_info.ignore_case_given || args_info.match_case_given) {
		opts |= Pcre2.CompileFlags.CASELESS;
	}
	int errorcode;
	size_t erroroffset;
	var regex = Pcre2.Regex.compile(old_text.data, opts, out errorcode, out erroroffset);
	if (errorcode < 0) {
		die(1, "bad regex %.*s (%s)".printf((int) old_text.len, old_text.str, get_error_message(errorcode)));
	}

	// Process files
	size_t total_files = 0;
	size_t matched_files = 0;
	size_t total_matches = 0;
	foreach (var filename in files) {
		bool have_perms = false;
		Posix.Stat perms = Posix.Stat() {
		};
		int input_fd;
		int output_fd;
		string tmp_path = null;
		if (filename == "-") {
			filename = "standard input";
			input_fd = GLib.stdin.fileno();
			output_fd = GLib.stdout.fileno();
		} else {
			// Check `filename` is a regular file, and get its permissions
			if (Posix.lstat(filename, out perms) != 0) {
				warn(@"skipping $filename: unable to read permissions; error: $(GLib.strerror(errno))");
				continue;
			}
			if (S_ISDIR(perms.st_mode)) {
				if (args_info.verbose_given) {
					warn(@"skipping directory $filename");
					continue;
				}
			}
			if (!S_ISREG(perms.st_mode)) {
				warn(@"skipping: $filename (not a regular file)");
				continue;
			}

			// Open the input file
			var fd = Posix.open(filename, Posix.O_RDONLY);
			if (fd < 0) {
				warn(@"skipping $filename: cannot open for reading; error: $(Posix.strerror(errno))\n");
				continue;
			}
			input_fd = fd;

			// Create the output file
			tmp_path = ".tmp.rpl-XXXXXX";
			fd = FileUtils.mkstemp(tmp_path);
			if (fd == -1) {
				warn(@"skipping $filename: cannot create temp file; error: $(Posix.strerror(errno))\n");
				continue;
			}
			output_fd = fd;

			// Set permissions and owner
			if (have_perms) {
				if (Posix.chown(tmp_path, perms.st_uid, perms.st_gid) != 0
				    || Posix.chmod(tmp_path, perms.st_mode) != 0) {
					warn(@"unable to set attributes of $filename; error: $(GLib.strerror(errno))");
					if (args_info.force_given) {
						warn("new file attributes may not match!");
					} else {
						warn(@"skipping $filename!");
						remove_temp_file(tmp_path);
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
			warn(@"processing: $filename");
		}

		// If we don't have an explicit encoding, guess
		const int encoding_buf_size = 1024 * 1024;
		var buf = new StringBuilder.sized(encoding_buf_size);
		if (encoding == null) {
			var detector = new UCharDet();

			// Scan at most 1MB, so we don't slurp a large file
			ssize_t n_bytes = 0;
			while (n_bytes < encoding_buf_size) {
				ssize_t n_read = Posix.read(input_fd, (uint8*) buf.data + n_bytes, encoding_buf_size);
				if (n_read < 0) {
					warn(@"error reading $filename: $(GLib.strerror(errno))\n");
					break;
				}
				if (n_read == 0) {
					break;
				}
				n_bytes += n_read;
			}
			buf.len = n_bytes;
			GLib.assert(detector.handle_data(buf.data) == 0);
			detector.data_end();
			encoding = detector.get_charset();
			if (args_info.verbose_given) {
				if (encoding != "") {
					warn(@"guessed encoding '$encoding'");
				} else {
					encoding = null;
					warn("unable to guess encoding");
				}
			}

			// Use locale encoding if none guessed.
			if (encoding == null) {
				get_charset(out encoding);
				if (args_info.verbose_given) {
					warn(@"could not guess encoding; using locale default '$encoding'");
				}
			}
		}

		// Process the file
		ssize_t num_matches = 0;
		num_matches = replace(input_fd, (owned) buf, filename, output_fd, regex, 0, new_text, encoding);

		if (Posix.close(input_fd) < 0) {
			warn(@"error closing $filename: $(GLib.strerror(errno))\n");
		}
		if (Posix.close(output_fd) < 0) {
			warn(@"error closing $filename: $(GLib.strerror(errno))\n");
		}

		// Delete temporary file if either we had an error (num_matches < 0)
		// or nothing changed (num_matches == 0).
		if (num_matches <= 0) {
			if (tmp_path != null) {
				unlink(tmp_path);
			}
			continue;
		}
		matched_files += 1;

		if (args_info.dry_run_given) {
			string fn;
			if (tmp_path == null) {
				fn = filename;
			} else {
				fn = Filename.canonicalize(filename);
				remove_temp_file(tmp_path);
			}

			if (!args_info.quiet_given) {
				info(@"  $fn\n");
			}

			total_matches += num_matches;
			continue;
		}

		if (args_info.prompt_given) {
			GLib.stderr.printf(@"\nSave \"$filename\"? ([Y]/N) ");

			string line = "";
			while (line == "" || !"Yy\nNn".contains(line[0].to_string())) {
				line = GLib.stdin.read_line();
			}

			if (line[0] == 'n' || line[0] == 'N') {
				info("Not saved");
				if (tmp_path != null) {
					remove_temp_file(tmp_path);
				}
				continue;
			}

			info("Saved");
		}

		if (tmp_path != null) {
			if (args_info.backup_given) {
				string backup_name = @"$filename~";
				var rc = FileUtils.rename(filename, backup_name);
				if (rc < 0) {
					warn(@"error renaming $filename to $backup_name; error: $(GLib.strerror(errno))");
					continue;
				}
			}

			// Rename the file
			int rc = FileUtils.rename(tmp_path, filename);
			if (rc == -1) {
				warn(@"could not replace $tmp_path with $filename: $(GLib.strerror(errno))\n");
				remove_temp_file(tmp_path);
				continue;
			}

			// Restore the times
			if (args_info.keep_times_given && have_perms) {
				var times = UTimBuf() {
					actime = perms.st_atime, modtime = perms.st_mtime
				};
				var rc2 = FileUtils.utime(filename, times);
				if (rc2 < 0) {
					warn(@"error setting timestamps of $filename: $(GLib.strerror(errno))");
				}
			}
		}

		total_matches += num_matches;
	}

	// We're about to exit, give a summary
	if (!args_info.quiet_given) {
		warn("%zu matches %s in %zu out of %zu file%s".printf(
		                                                      total_matches,
		                                                      args_info.dry_run_given ? "found" : "replaced",
		                                                      matched_files,
		                                                      total_files,
		                                                      total_files != 1 ? "s" : ""
		));
	}

	return EXIT_SUCCESS;
}