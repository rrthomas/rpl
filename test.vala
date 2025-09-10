#! /usr/bin/env -S vala --vapidir=. --pkg gio-2.0 --pkg posix --pkg gnu testcase.vala slurp.vala
// rpl tests
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

using Posix;

public string slurp_file (string filename) throws Error {
	string contents;
	FileUtils.get_contents (filename, out contents);
	return contents;
}

errordomain TestError {
	TESTERROR;
}

Subprocess start_prog (string prog, string[] args) throws TestError {
	var cmd = new Array<string>.take_zero_terminated(args);
	cmd.prepend_val (prog);
	Subprocess proc = null;
	try {
		proc = new Subprocess.newv (cmd.data,
									SubprocessFlags.SEARCH_PATH_FROM_ENVP
									| SubprocessFlags.STDIN_PIPE
									| SubprocessFlags.STDOUT_PIPE
									| SubprocessFlags.STDERR_PIPE);
	} catch (Error e) {
		print (@"error starting command $(string.joinv(" ", cmd.data)): $(e.message)\n");
		throw new TestError.TESTERROR ("could not run command");
	}
	return proc;
}

struct Output {
	public string std_out;
	public string std_err;
}

Subprocess check_prog (string prog, string[] args) throws Error {
	var proc = start_prog (prog, args);
	proc.wait_check (null);
	return proc;
}

bool try_sudo (string[] cmd) {
	try {
		var cmd_args = new Array<string>.take_zero_terminated(cmd);
		cmd_args.prepend_val ("-n");
		check_prog ("sudo", cmd_args.data);
		return true;
	} catch (Error e) {
		print ("cannot sudo, skipping test\n");
		Test.skip ();
		return false;
	}
}

Output run_prog (string prog, string[] args, int expected_rc = 0) {
	string std_out = "";
	string std_err = "";
	try {
		var proc = start_prog (prog, args);
		try {
			proc.wait ();
		} catch {}
		if (proc.get_if_exited ()) {
			assert_true (proc.get_exit_status () == expected_rc);
		}
		var stdout_pipe = proc.get_stdout_pipe ();
		var stderr_pipe = proc.get_stderr_pipe ();
		std_out = slurp (stdout_pipe);
		std_err = slurp (stderr_pipe);
	} catch (Error e) {
		print (@"error in command $prog $(string.joinv(" ", args)): $(e.message)\n");
	}
	return Output () {
			   std_out = std_out, std_err = std_err
	};
}

// Base class for rpl tests
class TestRpl : GeeTestCase {
	protected string rpl;
	protected string test_files_dir;
	public string test_result_dir;

	public TestRpl(string bin_dir, string test_files_dir) {
		base ("TestRpl");
		this.rpl = Path.build_filename (bin_dir, "rpl");
		this.test_files_dir = test_files_dir;
	}

	public Output run (string[] args, int expected_rc = 0) {
		return run_prog (rpl, args, expected_rc);
	}

	public override void set_up () {
		try {
			test_result_dir = DirUtils.make_tmp ("rpl.test.XXXXXX");
		} catch (FileError e) {
			print ("error creating temporary directory\n");
			assert_no_error (e);
		}
	}

	public override void tear_down () {
		run_prog ("rm", { "-rf", test_result_dir });
	}
}

class TestRplOutputFile : TestRpl {
	public string test_result_root;

	public TestRplOutputFile(string bin_dir, string test_files_dir) {
		base (bin_dir, test_files_dir);
	}

	public override void set_up () {
		base.set_up ();
		this.test_result_root = Path.build_filename (test_result_dir, "test.txt");
	}

	public bool result_matches (string file) {
		var expected_file = Path.build_filename (test_files_dir, file);
		try {
			check_prog ("diff", { "-r", expected_file, test_result_root });
		} catch (Error e) {
			return false;
		}
		return true;
	}
}

// Each set of tests that uses a particular input test file or directory is
// a class inheriting from this one.
abstract class TestRplFile : TestRplOutputFile {
	public string test_data_root;
	public string test_data;

	private TestRplFile(string bin_dir, string test_files_dir, string test_data) {
		base (bin_dir, test_files_dir);
		this.test_data = test_data;
		this.test_data_root = Path.build_filename (test_files_dir, test_data);
	}

	public override void set_up () {
		base.set_up ();
		this.test_result_root = Path.build_filename (test_result_dir, test_data);
		run_prog ("cp", { "-r", test_data_root, test_result_dir });
		run_prog ("chmod", { "-R", "u+w", test_result_dir });
	}
}

class EncodingTests : TestRplFile {
	public EncodingTests(string bin_dir, string test_files_dir) {
		base (bin_dir, test_files_dir, "lorem-iso-8859-1.txt");
		add_test ("test_bad_encoding", test_bad_encoding);
		add_test ("test_explicit_encoding", test_explicit_encoding);
	}

	void test_bad_encoding () {
		var output = run ({ "--encoding=utf-8", "Lorem", "L-O-R-E-M", test_result_root });
		assert_true (output.std_err.contains ("error decoding"));
	}

	void test_explicit_encoding () {
		run ({ "--encoding=iso-8859-1", "Lorem", "L-O-R-E-M", test_result_root });
		assert_true (result_matches ("lorem-iso-8859-1_explicit-encoding_expected.txt"));
	}
}

// This class contains all the tests that don't actually use a file.
class NoFileTests : TestRpl {
	public NoFileTests(string bin_dir, string test_files_dir) {
		base (bin_dir, test_files_dir);

		add_test ("test_no_arguments", test_no_arguments);
		add_test ("test_help", test_help);
		add_test ("test_full_help", test_full_help);
		add_test ("test_version", test_version);
		add_test ("test_nonexistent_option", test_nonexistent_option);
		add_test ("test_nonexistent_input", test_nonexistent_input);
		add_test ("test_nonexistent_patterns_file", test_nonexistent_patterns_file);
		add_test ("test_input_is_directory", test_input_is_directory);
	}

	void test_no_arguments () {
		var output = run ({ }, 1);
		assert_true (output.std_out.contains ("Search and replace text in files."));
	}

	void test_help () {
		var output = run ({ "--help" });
		assert_true (output.std_out.contains ("Search and replace text in files."));
	}

	void test_full_help () {
		var output = run ({ "--full-help" });
		assert_true (output.std_out.contains ("use extended regex syntax [IGNORED]"));
	}

	void test_version () {
		var output = run ({ "--version" });
		assert_true (output.std_out.contains ("NO WARRANTY, to the extent"));
	}

	void test_nonexistent_option () {
		var output = run ({ "--foo" }, 1);
		// The exact message varies by libc (it comes from getopt_long), but
		// should contain the name of the unrecognized option.
		assert_true (output.std_err.contains ("foo"));
	}

	void test_nonexistent_input () {
		var output = run ({ "in", "out", "nonexistent.txt" });
		assert_true (output.std_err.contains ("skipping nonexistent.txt: "));
	}

	void test_nonexistent_patterns_file () {
		var output = run ({ "--files", "in", "out", "nonexistent.txt" }, 1);
		assert_true (output.std_err.contains ("error reading patterns file"));
	}

	void test_input_is_directory () {
		var output = run ({ "amét", "amèt", test_result_dir });
		assert_true (output.std_err.contains ("skipping directory"));
	}
}

// This class contains all the tests that don't use an input file.
class OutputFileTests : TestRplOutputFile {
	public OutputFileTests(string bin_dir, string test_files_dir) {
		base (bin_dir, test_files_dir);

		add_test ("test_multi_buffer_matches", test_multi_buffer_matches);
		add_test ("test_buffer_crossing_character", test_buffer_crossing_character);
		add_test ("test_empty_match_at_buffer_end", test_empty_match_at_buffer_end);
		add_test ("test_recursive_no_file_arguments", test_recursive_no_file_arguments);
		add_test ("test_bad_regex", test_bad_regex);
		add_test ("test_non_file_input", test_non_file_input);
	}

	void test_multi_buffer_matches () {
		try {
			var file = File.new_for_path (test_result_root);
			FileOutputStream os = file.create (FileCreateFlags.NONE);
			os.write (string.nfill (2 * 1024 * 1024, 'a').data);
			os.close ();
		} catch (GLib.Error e) {
			print ("error writing to temporary file\n");
			assert_no_error (e);
		}
		run ({ "a+", "b", test_result_root });
		assert_true (result_matches ("one-b.txt"));
	}

	void test_buffer_crossing_character () {
		try {
			var file = File.new_for_path (test_result_root);
			FileOutputStream os = file.create (FileCreateFlags.NONE);
			os.write ("a".data);
			var s = new StringBuilder ();
			for (var i = 0; i < 2 * 1000 * 1000; i++) {
				s.append_unichar ('á');
			}
			os.write (s.data);
			os.close ();
		} catch (GLib.Error e) {
			print ("error writing to temporary file\n");
			assert_no_error (e);
		}
		run ({ "á", "b", test_result_root });
		assert_true (result_matches ("many-a-acute_buffer-crossing-character_expected.txt"));
	}

	void test_empty_match_at_buffer_end () {
		try {
			var file = File.new_for_path (test_result_root);
			FileOutputStream os = file.create (FileCreateFlags.NONE);
			os.write (string.nfill (2 * 1000 * 1000, 'a').data);
			os.close ();
		} catch (GLib.Error e) {
			print ("error writing to temporary file\n");
			assert_no_error (e);
		}
		run ({ "a?", "b", test_result_root });
		assert_true (result_matches ("empty-match-at-buffer-end_expected.txt"));
	}

	void test_recursive_no_file_arguments () {
		var output = run ({ "--recursive", "foo", "bar" }, 1);
		assert_true (output.std_err.contains ("cannot use --recursive with no file arguments!"));
	}

	void test_bad_regex () {
		var output = run ( {"(foo", "bar" }, 1);
		assert_true (output.std_err.contains ("bad regex (foo"));
	}

	void test_non_file_input () {
		var output = run ( {"foo", "bar",
#if WINDOWS
							"nul:"
#else
							"/dev/null"
#endif
						   });
		assert_true (output.std_err.contains ("not a regular file"));
	}
}

class LoremTests : TestRplFile {
	public LoremTests(string bin_dir, string test_files_dir) {
		base (bin_dir, test_files_dir, "lorem.txt");
		add_test ("test_ignore_case", test_ignore_case_verbose);
		add_test ("test_match_case", test_match_case);
		add_test ("test_no_flags", test_no_flags);
		add_test ("test_use_regexp", test_use_regexp);
		add_test ("test_dry_run", test_dry_run);
		add_test ("test_quiet", test_quiet);
		add_test ("test_ignores_dash_E", test_ignores_dash_E);
		add_test ("test_bad_replacement", test_bad_replacement);
		add_test ("test_input_on_stdin", test_input_on_stdin);
		add_test ("test_recursive_used_with_file", test_recursive_used_with_file);
		add_test ("test_bad_output_encoding", test_bad_output_encoding);
		add_test ("test_bad_ASCII_output", test_bad_ascii_output);
	}

	void test_ignore_case_verbose () {
		var output = run ({ "-iv", "Lorem", "L-O-R-E-M", test_result_root });
		assert_true (output.std_err.contains ("processing "));
		assert_true (result_matches ("lorem_ignore-case_expected.txt"));
	}

	void test_match_case () {
		run ({ "lorem", "loReM", test_result_root });
		assert_true (result_matches ("lorem_match-case_expected.txt"));
	}

	void test_no_flags () {
		run ({ "Lorem", "L-O-R-E-M", test_result_root });
		assert_true (result_matches ("lorem_no-flags_expected.txt"));
	}

	void test_use_regexp () {
		run ({ "a[a-z]+", "coffee", test_result_root });
		assert_true (result_matches ("lorem_use-regexp_expected.txt"));
	}

	void test_dry_run () {
		run ({ "--dry-run", "Lorem", "L-O-R-E-M", test_result_root });
		assert_true (result_matches ("lorem.txt"));
	}

	void test_quiet () {
		var output = run ({ "--quiet", "Lorem", "L-O-R-E-M", test_result_root });
		assert_true (output.std_err.length == 0);
		assert_true (result_matches ("lorem_no-flags_expected.txt"));
	}

	void test_ignores_dash_E () {
		run ({ "-E", "Lorem", "L-O-R-E-M", test_result_root });
		assert_true (result_matches ("lorem_no-flags_expected.txt"));
	}

	void test_bad_replacement () {
		var output = run ({ "Lorem", "$input", test_result_root });
		assert_true (output.std_err.contains ("error in replacement"));
	}

	void test_input_on_stdin () {
		try {
			var proc = start_prog (rpl, { "Lorem", "L-O-R-E-M" });
			var stdin_pipe = proc.get_stdin_pipe ();
			var stdout_pipe = proc.get_stdout_pipe ();
			stdin_pipe.write (slurp_file (test_result_root).data);
			stdin_pipe.close ();
			var std_out = slurp (stdout_pipe);
			var expected_file = Path.build_filename (test_files_dir, "lorem_no-flags_expected.txt");
			assert_true (std_out == slurp_file (expected_file));
		} catch (Error e) {
			print ("error communicating with rpl\n");
			assert_no_error (e);
		}
	}

	void test_recursive_used_with_file () {
		run ({ "--recursive", "Lorem", "L-O-R-E-M", test_result_root });
		assert_true (result_matches ("lorem_no-flags_expected.txt"));
	}

	void test_bad_output_encoding () {
		var output = run ({ "--encoding=iso-8859-1", "amet", "amαt", test_result_root }, 0);
		assert_true (output.std_err.contains ("output encoding error"));
	}

	void test_bad_ascii_output () {
		var output = run ({ "--encoding=ascii", "amet", "amαt", test_result_root }, 0);
		assert_true (output.std_err.contains ("output encoding error"));
	}
}

class LoremUtf8Tests : TestRplFile {
	public LoremUtf8Tests(string bin_dir, string test_files_dir) {
		base (bin_dir, test_files_dir, "lorem-utf-8.txt");
		add_test ("test_utf_8", test_utf_8);
		add_test ("test_whole_words", test_whole_words);
		add_test ("test_patterns_in_files", test_patterns_in_files);
		add_test ("test_fixed_strings", test_fixed_strings);
		add_test ("test_match_case_non_ascii", test_match_case_non_ascii);
		add_test ("test_keep_times", test_keep_times);
		add_test ("test_without_keep_times", test_without_keep_times);
		add_test ("test_prompt_yes", test_prompt_yes);
		add_test ("test_prompt_no", test_prompt_no);
		add_test ("test_prompt_empty", test_prompt_empty);
		add_test ("test_force", test_force);
		add_test ("test_force_fail", test_force_fail);
		add_test ("test_set_attributes_fail", test_set_attributes_fail);
		add_test ("test_unreadable_input", test_unreadable_input);
		add_test ("test_unwritable_input", test_unwritable_input);
		add_test ("test_backup_file_unwritable", test_backup_file_unwritable);
	}

	void test_utf_8 () {
		run ({ "amét", "amèt", test_result_root });
		assert_true (result_matches ("lorem-utf-8_utf-8_expected.txt"));
	}

	void test_whole_words () {
		run ({ "--whole-words", "in", "out", test_result_root });
		assert_true (result_matches ("lorem-utf-8_whole-words_expected.txt"));
	}

	void test_patterns_in_files () {
		var in_file = Path.build_filename (test_files_dir, "in.txt");
		var out_file = Path.build_filename (test_files_dir, "out.txt");
		run ({ "--files", "--whole-words", in_file, out_file, test_result_root });
		assert_true (result_matches ("lorem-utf-8_whole-words_expected.txt"));
	}

	void test_fixed_strings () {
		run ({ "--fixed-strings", "t.", "t$$", test_result_root });
		assert_true (result_matches ("lorem-utf-8_fixed-strings_expected.txt"));
	}

	void test_match_case_non_ascii () {
		run ({ "-m", "\\w+", "éowyn", test_result_root });
		assert_true (result_matches ("lorem-utf-8_match-case-non-ascii_expected.txt"));
	}

	void test_keep_times () {
		run_prog ("touch", { "-r", test_data_root, test_result_root });
		run ({ "--keep-times", "in", "out", test_result_root });
		Posix.Stat perms = Posix.Stat () {};
		assert_true (Posix.lstat (test_data_root, out perms) == 0);
		var orig_mtime = (timespec) Gnu.get_stat_mtime (perms);
		assert_true (Posix.lstat (test_result_root, out perms) == 0);
		var new_mtime = (timespec) Gnu.get_stat_mtime (perms);
		assert_true (orig_mtime.tv_sec == new_mtime.tv_sec &&
					 orig_mtime.tv_nsec == new_mtime.tv_nsec);
	}

	void test_without_keep_times () {
		run ({ "in", "out", test_result_root });
		Posix.Stat perms = Posix.Stat () {};
		assert_true (Posix.lstat (test_data_root, out perms) == 0);
		var orig_mtime = (timespec) Gnu.get_stat_mtime (perms);
		assert_true (Posix.lstat (test_result_root, out perms) == 0);
		var new_mtime = (timespec) Gnu.get_stat_mtime (perms);
		assert_true (!(orig_mtime.tv_sec == new_mtime.tv_sec &&
					   orig_mtime.tv_nsec == new_mtime.tv_nsec));
	}

	private void prompt_test (string input, string expected) {
		try {
			var proc = start_prog (rpl, { "--whole-words", "--prompt", "in", "out", test_result_root });
			var stdin_pipe = proc.get_stdin_pipe ();
			var stderr_pipe = proc.get_stderr_pipe ();
			stdin_pipe.write (input.data);
			stdin_pipe.close ();
			var std_err = slurp (stderr_pipe);
			assert_true (std_err.contains ("? [Y/n] "));
			assert_true (std_err.contains (expected));
		} catch (Error e) {
			print ("error communicating with rpl\n");
			assert_no_error (e);
		}
	}

	void test_prompt_yes () {
		prompt_test ("y\n", "Updated");
		assert_true (result_matches ("lorem-utf-8_whole-words_expected.txt"));
	}

	void test_prompt_no () {
		prompt_test ("n\n", "Not updated");
		assert_true (!result_matches ("lorem-utf-8_whole-words_expected.txt"));
	}

	void test_prompt_empty () {
		prompt_test ("\n", "Updated");
		assert_true (result_matches ("lorem-utf-8_whole-words_expected.txt"));
	}

	void test_force () {
		if (!try_sudo ({ "chown", "0:0", test_result_root }) ||
			!try_sudo ({ "chmod", "644", test_result_root })) {
			return;
		}
		var output = run_prog ("sudo", { "-n", rpl, "--force", "amét", "amèt", test_result_root });
		assert_true (result_matches ("lorem-utf-8_utf-8_expected.txt"));
		assert_true (!output.std_err.contains ("unable to set attributes"));
		assert_true (!output.std_err.contains ("new file attributes may not match"));
	}

	void test_force_fail () {
		if (!try_sudo ({ "chown", "0:0", test_result_root }) ||
			!try_sudo ({ "chmod", "777", test_result_root }) ||
			!try_sudo ({ "chmod", "755", test_result_dir })) {
			return;
		}
		var output = run ({ "--force", "amét", "amèt", test_result_root });
		assert_true (output.std_err.contains ("unable to set attributes"));
		assert_true (output.std_err.contains ("new file attributes may not match"));
	}

	void test_set_attributes_fail () {
		if (!try_sudo ({ "chown", "0:0", test_result_root }) ||
			!try_sudo ({ "chmod", "777", test_result_root }) ||
			!try_sudo ({ "chmod", "755", test_result_dir })) {
			return;
		}
		var output = run ({ "amét", "amèt", test_result_root });
		assert_true (output.std_err.contains ("unable to set attributes"));
		assert_true (output.std_err.contains ("skipping"));
	}

	void test_unreadable_input () {
#if WINDOWS
		Test.skip ();
#else
		assert_true (Posix.chmod (test_result_root, 0000) == 0);
		var output = run ({ "amét", "amèt", test_result_root });
		assert_true (output.std_err.contains (@"skipping $test_result_root"));
#endif
	}

	void test_unwritable_input () {
#if WINDOWS
		Test.skip ();
#else
		assert_true (Posix.chmod (test_result_dir, 0500) == 0);
		assert_true (Posix.chmod (test_result_root, 0777) == 0);
		var output = run ({ "amét", "amèt", test_result_root });
		assert_true (output.std_err.contains ("could not move"));
		// Allow test directory to be deleted.
		assert_true (Posix.chmod (test_result_dir, 0700) == 0);
#endif
	}

	void test_backup_file_unwritable () {
#if WINDOWS
		Test.skip ();
#else
		var backup_file = @"$test_result_root~";
		try {
			assert_true (File.new_for_path (backup_file).create (0).close ());
		} catch (Error e) {
			print ("error creating dummy backup file\n");
			assert_no_error (e);
		}
		assert_true (Posix.chmod (test_result_dir, 0500) == 0);
		var output = run ({ "--backup", "amét", "amèt", test_result_root });
		assert_true (output.std_err.contains ("error renaming"));
		// Allow test directory to be deleted.
		assert_true (Posix.chmod (test_result_dir, 0700) == 0);
#endif
	}
}

class Utf8SigTests : TestRplFile {
	public Utf8SigTests(string bin_dir, string test_files_dir) {
		base (bin_dir, test_files_dir, "utf-8-sig.txt");
		add_test ("test_utf_8_sig", test_utf_8_sig);
	}

	void test_utf_8_sig () {
		run ({ "BOM mark", "BOM", test_result_root });
		assert_true (result_matches ("utf-8-sig_utf-8-sig_expected.txt"));
	}
}

class MixedCaseTests : TestRplFile {
	public MixedCaseTests(string bin_dir, string test_files_dir) {
		base (bin_dir, test_files_dir, "mixed-case.txt");
		add_test ("test_mixed_replace_lower", test_mixed_replace_lower);
	}

	void test_mixed_replace_lower () {
		run ({ "-m", "MixedInput", "MixedOutput", test_result_root });
		assert_true (result_matches ("mixed-case_mixed-replace-lower_expected.txt"));
	}
}

class BackreferenceTests : TestRplFile {
	public BackreferenceTests(string bin_dir, string test_files_dir) {
		base (bin_dir, test_files_dir, "aba.txt");
		add_test ("test_backreference_numbering", test_backreference_numbering);
	}

	void test_backreference_numbering () {
		run ({ "a(b)a", "$1", test_result_root });
		assert_true (result_matches ("aba_backreference-numbering_expected.txt"));
	}
}

class EmptyMatchesTests : TestRplFile {
	public EmptyMatchesTests(string bin_dir, string test_files_dir) {
		base (bin_dir, test_files_dir, "abc-123.txt");
		add_test ("test_empty_matches", test_empty_matches);
	}

	void test_empty_matches () {
		run ({ "^", "#", test_result_root });
		assert_true (result_matches ("abc-123_empty-matches_expected.txt"));
	}
}

class DirTests : TestRplFile {
	public DirTests(string bin_dir, string test_files_dir) {
		base (bin_dir, test_files_dir, "test-dir");
		add_test ("test_recursive", test_recursive);
		add_test ("test_backup", test_backup);
	}

	void test_recursive () {
		run ({ "--recursive", "foo", "bar", test_result_root });
		assert_true (result_matches ("test-dir-expected"));
	}

	void test_backup () {
		run ({ "--backup", "--recursive", "foo", "bar", test_result_root });
		assert_true (result_matches ("test-dir-backup-expected"));
	}
}

class GlobTests : TestRplFile {
	public GlobTests(string bin_dir, string test_files_dir) {
		base (bin_dir, test_files_dir, "test-tree");
		add_test ("test_globs", test_globs);
		add_test ("test_globs_no_match", test_globs_no_match);
	}

	void test_globs () {
		run ({ "--recursive", "--glob=*.txt", "foo", "bar", test_result_root });
		assert_true (result_matches ("test-tree-expected"));
	}

	void test_globs_no_match () {
		var output = run ({ "--recursive", "--glob=*.foo", "foo", "bar", test_result_root }, 1);
		assert_true (output.std_err.contains ("the given filename patterns did not match any files!"));
	}
}

public int main (string[] args) {
	var test_files_dir = Environment.get_variable ("TEST_FILES_DIR");
	var bin_dir = Path.get_dirname (args[0]);
	Test.init (ref args);
	Test.set_nonfatal_assertions ();
	TestSuite.get_root ().add_suite (new NoFileTests (bin_dir, test_files_dir).get_suite ());
	TestSuite.get_root ().add_suite (new OutputFileTests (bin_dir, test_files_dir).get_suite ());
	TestSuite.get_root ().add_suite (new EncodingTests (bin_dir, test_files_dir).get_suite ());
	TestSuite.get_root ().add_suite (new LoremTests (bin_dir, test_files_dir).get_suite ());
	TestSuite.get_root ().add_suite (new LoremUtf8Tests (bin_dir, test_files_dir).get_suite ());
	TestSuite.get_root ().add_suite (new Utf8SigTests (bin_dir, test_files_dir).get_suite ());
	TestSuite.get_root ().add_suite (new MixedCaseTests (bin_dir, test_files_dir).get_suite ());
	TestSuite.get_root ().add_suite (new BackreferenceTests (bin_dir, test_files_dir).get_suite ());
	TestSuite.get_root ().add_suite (new EmptyMatchesTests (bin_dir, test_files_dir).get_suite ());
	TestSuite.get_root ().add_suite (new DirTests (bin_dir, test_files_dir).get_suite ());
	TestSuite.get_root ().add_suite (new GlobTests (bin_dir, test_files_dir).get_suite ());

	return Test.run ();
}
