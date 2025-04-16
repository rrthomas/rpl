#! /usr/bin/env -S vala --vapidir=. --pkg gio-2.0 --pkg gio-unix-2.0 --pkg posix testcase.vala
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

struct Output {
	public string stdout;
	public string stderr;
}

Output run_prog(string prog, string[] args) {
	string[] cmd = { prog };
	foreach (var arg in args) {
		cmd += arg;
	}
	var cmd_string = string.joinv(" ", cmd);
	string stdout;
	string stderr;
	int status;
	try {
		assert_true(Process.spawn_sync(null, cmd, null, SpawnFlags.SEARCH_PATH, null, out stdout, out stderr, out status));
	} catch (SpawnError e) {
		print(@"error running $cmd_string\n");
		assert_no_error(e);
	}
	try {
		Process.check_wait_status(status);
	} catch (GLib.Error e) {
		print(@"$cmd_string: $(e.message)\n");
		assert_no_error(e);
	}
	return Output() {
			   stdout = stdout, stderr = stderr
	};
}

// Base class for rpl tests
class TestRpl : GeeTestCase {
	private string rpl;
	protected string test_files_dir;
	public string test_result_dir;

	public TestRpl(string bin_dir, string test_files_dir) {
		base("TestRpl");
		this.rpl = Path.build_filename(bin_dir, "rpl");
		this.test_files_dir = test_files_dir;
	}

	public Output run(string[] args) {
		return run_prog(rpl, args);
	}

	public override void set_up() {
		try {
			test_result_dir = DirUtils.make_tmp("rpl.test.XXXXXX");
		} catch (FileError e) {
			print("error creating temporary directory\n");
			assert_no_error(e);
		}
	}

	public override void tear_down() {
		run_prog("rm", { "-rf", test_result_dir });
	}
}

class TestRplOutputFile : TestRpl {
	public string test_result_root;

	public TestRplOutputFile(string bin_dir, string test_files_dir) {
		base(bin_dir, test_files_dir);
	}

	public override void set_up() {
		base.set_up();
		this.test_result_root = Path.build_filename(test_result_dir, "test.txt");
	}

	public bool result_matches(string file) {
		var result_file = Path.build_filename(test_files_dir, file);
		run_prog("diff", { "-r", result_file, test_result_root });
		return true;
	}
}

// Each set of tests that uses a particular input test file or directory is
// a class inheriting from this one.
abstract class TestRplFile : TestRplOutputFile {
	public string test_data_root;
	public string test_data;

	private TestRplFile(string bin_dir, string test_files_dir, string test_data) {
		base(bin_dir, test_files_dir);
		this.test_data = test_data;
		this.test_data_root = Path.build_filename(test_files_dir, test_data);
	}

	public override void set_up() {
		base.set_up();
		this.test_result_root = Path.build_filename(test_result_dir, test_data);
		run_prog("cp", { "-frp", test_data_root, test_result_dir });
	}
}

class TestRplLorem8859_1 : TestRplFile {
	public TestRplLorem8859_1(string bin_dir, string test_files_dir) {
		base(bin_dir, test_files_dir, "lorem-iso-8859-1.txt");
		add_test("test_bad_encoding", test_bad_encoding);
		add_test("test_explicit_encoding", test_explicit_encoding);
	}

	void test_bad_encoding() {
		var output = run({ "--encoding=utf-8", "Lorem", "L-O-R-E-M", test_result_root });
		print(@"bad_encoding: $(output.stderr)\n");
		assert_true(output.stderr.contains("error decoding"));
	}

	void test_explicit_encoding() {
		run({ "--encoding=iso-8859-1", "Lorem", "L-O-R-E-M", test_result_root });
		assert_true(result_matches("lorem-iso-8859-1_explicit-encoding_expected.txt"));
	}
}

// This class contains all the tests that don't actually use a file.
class NoFileTests : TestRpl {
	public NoFileTests(string bin_dir, string test_files_dir) {
		base(bin_dir, test_files_dir);

		add_test("test_help", test_help);
		add_test("test_full_help", test_full_help);
		add_test("test_version", test_version);
	}

	void test_help() {
		var output = run({ "--help" });
		assert_true(output.stdout.contains("Search and replace text in files."));
	}

	void test_full_help() {
		var output = run({ "--full-help" });
		assert_true(output.stdout.contains("use extended regex syntax [IGNORED]"));
	}

	void test_version() {
		var output = run({ "--version" });
		assert_true(output.stdout.contains("NO WARRANTY, to the extent"));
	}
}

// This class contains all the tests that don't use an input file.
class OutputFileTests : TestRplOutputFile {
	public OutputFileTests(string bin_dir, string test_files_dir) {
		base(bin_dir, test_files_dir);

		add_test("multi_buffer_matches", multi_buffer_matches);
	}

	void multi_buffer_matches() {
		try {
			var file = File.new_for_path(test_result_root);
			FileOutputStream os = file.create(FileCreateFlags.NONE);
			os.write(string.nfill(1024 * 1024, 'a').data);
			os.close();
		} catch (GLib.Error e) {
			print("error writing to temporary file\n");
			assert_no_error(e);
		}
		run({ "a+", "b", test_result_root });
		assert_true(result_matches("one-b.txt"));
	}
}

class LoremTests : TestRplFile {
	public LoremTests(string bin_dir, string test_files_dir) {
		base(bin_dir, test_files_dir, "lorem.txt");
		add_test("test_ignore_case", test_ignore_case_verbose);
		add_test("test_match_case", test_match_case);
		add_test("test_no_flags", test_no_flags);
		add_test("test_use_regexp", test_use_regexp);
		add_test("test_dry_run", test_dry_run);
		add_test("test_quiet", test_quiet);
		add_test("test_ignores_dash_E", test_ignores_dash_E);
		add_test("test_bad_replacement", test_bad_replacement);
	}

	void test_ignore_case_verbose() {
		var output = run({ "-iv", "Lorem", "L-O-R-E-M", test_result_root });
		assert_true(output.stderr.contains("processing: "));
		assert_true(result_matches("lorem_ignore-case_expected.txt"));
	}

	void test_match_case() {
		run({ "lorem", "loReM", test_result_root });
		assert_true(result_matches("lorem_match-case_expected.txt"));
	}

	void test_no_flags() {
		run({ "Lorem", "L-O-R-E-M", test_result_root });
		assert_true(result_matches("lorem_no-flags_expected.txt"));
	}

	void test_use_regexp() {
		run({ "a[a-z]+", "coffee", test_result_root });
		assert_true(result_matches("lorem_use-regexp_expected.txt"));
	}

	void test_dry_run() {
		run({ "--dry-run", "Lorem", "L-O-R-E-M", test_result_root });
		assert_true(result_matches("lorem.txt"));
	}

	void test_quiet() {
		var output = run({ "--quiet", "Lorem", "L-O-R-E-M", test_result_root });
		assert_true(output.stderr.length == 0);
		assert_true(result_matches("lorem_no-flags_expected.txt"));
	}

	void test_ignores_dash_E() {
		run({ "-E", "Lorem", "L-O-R-E-M", test_result_root });
		assert_true(result_matches("lorem_no-flags_expected.txt"));
	}

	void test_bad_replacement() {
		var output = run({ "Lorem", "$input", test_result_root });
		assert_true(output.stderr.contains("error in replacement"));
	}
}

class LoremUtf8Tests : TestRplFile {
	public LoremUtf8Tests(string bin_dir, string test_files_dir) {
		base(bin_dir, test_files_dir, "lorem-utf-8.txt");
		add_test("test_utf_8", test_utf_8);
		add_test("test_whole_words", test_whole_words);
		add_test("test_patterns_in_files", test_patterns_in_files);
		add_test("test_fixed_strings", test_fixed_strings);
		add_test("test_keep_times", test_keep_times);
		add_test("test_without_keep_times", test_without_keep_times);
	}

	void test_utf_8() {
		run({ "amét", "amèt", test_result_root });
		assert_true(result_matches("lorem-utf-8_utf-8_expected.txt"));
	}

	void test_whole_words() {
		run({ "--whole-words", "in", "out", test_result_root });
		assert_true(result_matches("lorem-utf-8_whole-words_expected.txt"));
	}

	void test_patterns_in_files() {
		var in_file = Path.build_filename(test_files_dir, "in.txt");
		var out_file = Path.build_filename(test_files_dir, "out.txt");
		run({ "--files", "--whole-words", in_file, out_file, test_result_root });
		assert_true(result_matches("lorem-utf-8_whole-words_expected.txt"));
	}

	void test_fixed_strings() {
		run({ "--fixed-strings", "t.", "t$$", test_result_root });
		assert_true(result_matches("lorem-utf-8_fixed-strings_expected.txt"));
	}

	void test_keep_times() {
		run({ "--keep-times", "in", "out", test_result_root });
		Posix.Stat perms = Posix.Stat () {};
		assert_true(Posix.lstat(test_data_root, out perms) == 0);
		var orig_mtim = perms.st_mtim;
		assert_true(Posix.lstat(test_result_root, out perms) == 0);
		assert_true(perms.st_mtim.tv_sec == orig_mtim.tv_sec &&
					perms.st_mtim.tv_nsec == orig_mtim.tv_nsec);
	}

	void test_without_keep_times() {
		run({ "in", "out", test_result_root });
		Posix.Stat perms = Posix.Stat () {};
		assert_true(Posix.lstat(test_data_root, out perms) == 0);
		var orig_mtim = perms.st_mtim;
		assert_true(Posix.lstat(test_result_root, out perms) == 0);
		assert_true(!(perms.st_mtim.tv_sec == orig_mtim.tv_sec &&
					  perms.st_mtim.tv_nsec == orig_mtim.tv_nsec));
	}
}

class Utf8SigTests : TestRplFile {
	public Utf8SigTests(string bin_dir, string test_files_dir) {
		base(bin_dir, test_files_dir, "utf-8-sig.txt");
		add_test("test_utf_8_sig", test_utf_8_sig);
	}

	void test_utf_8_sig() {
		run({ "BOM mark", "BOM", test_result_root });
		assert_true(result_matches("utf-8-sig_utf-8-sig_expected.txt"));
	}
}

class MixedCaseTests : TestRplFile {
	public MixedCaseTests(string bin_dir, string test_files_dir) {
		base(bin_dir, test_files_dir, "mixed-case.txt");
		add_test("test_mixed_replace_lower", test_mixed_replace_lower);
	}

	void test_mixed_replace_lower() {
		run({ "-m", "MixedInput", "MixedOutput", test_result_root });
		assert_true(result_matches("mixed-case_mixed-replace-lower_expected.txt"));
	}
}

class BackreferenceTests : TestRplFile {
	public BackreferenceTests(string bin_dir, string test_files_dir) {
		base(bin_dir, test_files_dir, "aba.txt");
		add_test("test_backreference_numbering", test_backreference_numbering);
	}

	void test_backreference_numbering() {
		run({ "a(b)a", "$1", test_result_root });
		assert_true(result_matches("aba_backreference-numbering_expected.txt"));
	}
}

class EmptyMatchesTests : TestRplFile {
	public EmptyMatchesTests(string bin_dir, string test_files_dir) {
		base(bin_dir, test_files_dir, "abc-123.txt");
		add_test("test_empty_matches", test_empty_matches);
	}

	void test_empty_matches() {
		run({ "^", "#", test_result_root });
		assert_true(result_matches("abc-123_empty-matches_expected.txt"));
	}
}

class DirTests : TestRplFile {
	public DirTests(string bin_dir, string test_files_dir) {
		base(bin_dir, test_files_dir, "test-dir");
		add_test("test_recursive", test_recursive);
		add_test("test_backup", test_backup);
	}

	void test_recursive() {
		run({ "--recursive", "foo", "bar", test_result_root });
		assert_true(result_matches("test-dir-expected"));
	}

	void test_backup() {
		run({ "--backup", "--recursive", "foo", "bar", test_result_root });
		assert_true(result_matches("test-dir-backup-expected"));
	}
}

class GlobTests : TestRplFile {
	public GlobTests(string bin_dir, string test_files_dir) {
		base(bin_dir, test_files_dir, "test-tree");
		add_test("test_globs", test_globs);
	}

	void test_globs() {
		run({ "--recursive", "--glob=*.txt", "foo", "bar", test_result_root });
		assert_true(result_matches("test-tree-expected"));
	}
}

public int main(string[] args) {
	var test_files_dir = Environment.get_variable("TEST_FILES_DIR");
	var bin_dir = Path.get_dirname(args[0]);
	Test.init(ref args);
	TestSuite.get_root().add_suite(new NoFileTests(bin_dir, test_files_dir).get_suite());
	TestSuite.get_root().add_suite(new OutputFileTests(bin_dir, test_files_dir).get_suite());
	TestSuite.get_root().add_suite(new TestRplLorem8859_1(bin_dir, test_files_dir).get_suite());
	TestSuite.get_root().add_suite(new LoremTests(bin_dir, test_files_dir).get_suite());
	TestSuite.get_root().add_suite(new LoremUtf8Tests(bin_dir, test_files_dir).get_suite());
	TestSuite.get_root().add_suite(new Utf8SigTests(bin_dir, test_files_dir).get_suite());
	TestSuite.get_root().add_suite(new MixedCaseTests(bin_dir, test_files_dir).get_suite());
	TestSuite.get_root().add_suite(new BackreferenceTests(bin_dir, test_files_dir).get_suite());
	TestSuite.get_root().add_suite(new EmptyMatchesTests(bin_dir, test_files_dir).get_suite());
	TestSuite.get_root().add_suite(new DirTests(bin_dir, test_files_dir).get_suite());
	TestSuite.get_root().add_suite(new GlobTests(bin_dir, test_files_dir).get_suite());

	return Test.run();
}
