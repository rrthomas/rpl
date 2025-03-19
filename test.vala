#! /usr/bin/env -S vala --vapidir=. --pkg gio-2.0 --pkg gio-unix-2.0 --pkg config --pkg pcre2 testcase.vala slurp.vala
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

using GLib;

struct Output {
	public string stdout;
	public string stderr;
}

Output run_prog(string prog, string[] args) {
	string[] cmd = { prog };
	foreach (var arg in args) {
		cmd += arg;
	}
	string stdout;
	string stderr;
	int status;
	try {
		assert_true(Process.spawn_sync(null, cmd, null, SpawnFlags.SEARCH_PATH, null, out stdout, out stderr, out status));
	} catch (SpawnError e) {
		print(@"error running $prog\n");
		assert_no_error(e);
	}
	try {
		Process.check_wait_status(status);
	} catch (GLib.Error e) {
		print(@"$prog: $(e.message)\n");
		assert_no_error(e);
	}
	return Output() {
		stdout = stdout, stderr = stderr
	};
}

class TestRpl : GeeTestCase {
	private string rpl;
	protected string test_files_dir;
	public File test_result_file;
	protected IOStream tmp_ios;

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
			test_result_file = File.new_tmp("rpl.test.XXXXXX", out tmp_ios);
		} catch (GLib.Error e) {
			print("error creating temporary file\n");
			assert_no_error(e);
		}
	}

	public override void tear_down() {
		try {
			test_result_file.@delete();
		} catch (Error e) {
			print("error deleting test file\n");
			assert_no_error(e);
		}
	}

	public StringBuilder test_result() {
		var result = slurp(test_result_file);
		if (result == null) {
			print("error reading test result");
			assert_nonnull(result);
		}
		return result;
	}
}

// This class contains all the tests that don't use an input file.
class TestRplNoFile : TestRpl {
	public TestRplNoFile(string bin_dir, string test_files_dir) {
		base(bin_dir, test_files_dir);
		add_test("test_version", test_version);
		add_test("multi_buffer_matches", multi_buffer_matches);
	}

	void test_version() {
		var output = run({ "--version" });
		assert_true(output.stdout.contains("NO WARRANTY, to the extent"));
	}

	public void multi_buffer_matches() {
		try {
			tmp_ios.output_stream.write(string.nfill(1024 * 1024, 'a').data);
			tmp_ios.close();
		} catch (GLib.Error e) {
			print("error writing to temporary file");
			assert_no_error(e);
		}
		run({ "a+", "b", test_result_file.get_path() });
		assert_true(test_result().str == "b");
	}
}

// Each set of tests that uses a particular test file is a class inheriting
// from this one.
abstract class TestRplFile : TestRpl {
	public string test_file;

	private TestRplFile(string bin_dir, string test_files_dir, string test_file) {
		base(bin_dir, test_files_dir);
		this.test_file = Path.build_filename(test_files_dir, test_file);
	}

	public override void set_up() {
		base.set_up();
		try {
			var src = File.new_for_path(test_file);
			tmp_ios.close();
			assert_true(src.copy(test_result_file, FileCopyFlags.OVERWRITE, null));
		} catch (Error e) {
			print("error copying test file");
			assert_no_error(e);
		}
	}

	public bool result_matches(string file) {
		var result_file = Path.build_filename(test_files_dir, file);
		run_prog("diff", { result_file, test_result_file.get_path() });
		return true;
	}
}

class TestRplLorem8859_1 : TestRplFile {
	public TestRplLorem8859_1(string bin_dir, string test_files_dir) {
		base(bin_dir, test_files_dir, "lorem-iso-8859-1.txt");
		add_test("test_bad_encoding", test_bad_encoding);
		add_test("test_explicit_encoding", test_explicit_encoding);
	}

	void test_bad_encoding() {
		var output = run({ "--encoding=utf-8", "Lorem", "L-O-R-E-M", test_file });
		assert_true(output.stderr.contains("error decoding"));
	}

	void test_explicit_encoding() {
		run({ "--encoding=iso-8859-1", "Lorem", "L-O-R-E-M", test_result_file.get_path() });
		assert_true(result_matches("lorem-iso-8859-1_explicit-encoding_expected.txt"));
	}
}

class TestRplLorem : TestRplFile {
	public TestRplLorem(string bin_dir, string test_files_dir) {
		base(bin_dir, test_files_dir, "lorem.txt");
		add_test("test_ignore_case", test_ignore_case_verbose);
		add_test("test_match_case", test_match_case);
		add_test("test_no_flags", test_no_flags);
		add_test("test_use_regexp", test_use_regexp);
		add_test("test_dry_run", test_dry_run);
		add_test("test_quiet", test_quiet);
		add_test("test_ignores_dash_E", test_ignores_dash_E);
	}

	void test_ignore_case_verbose() {
		var output = run({ "-iv", "Lorem", "L-O-R-E-M", test_result_file.get_path() });
		assert_true(output.stderr.contains("processing: "));
		assert_true(result_matches("lorem_ignore-case_expected.txt"));
	}

	void test_match_case() {
		run({ "lorem", "loReM", test_result_file.get_path() });
		assert_true(result_matches("lorem_match-case_expected.txt"));
	}

	void test_no_flags() {
		run({ "Lorem", "L-O-R-E-M", test_result_file.get_path() });
		assert_true(result_matches("lorem_no-flags_expected.txt"));
	}

	void test_use_regexp() {
		run({ "a[a-z]+", "coffee", test_result_file.get_path() });
		assert_true(result_matches("lorem_use-regexp_expected.txt"));
	}

	void test_dry_run() {
		run({ "--dry-run", "Lorem", "L-O-R-E-M", test_result_file.get_path() });
		assert_true(result_matches("lorem.txt"));
	}

	void test_quiet() {
		var output = run({ "--quiet", "Lorem", "L-O-R-E-M", test_result_file.get_path() });
		assert_true(output.stderr.length == 0);
		assert_true(result_matches("lorem_no-flags_expected.txt"));
	}

	void test_ignores_dash_E() {
		run({ "-E", "Lorem", "L-O-R-E-M", test_result_file.get_path() });
		assert_true(result_matches("lorem_no-flags_expected.txt"));
	}
}

class TestRplLoremUtf8 : TestRplFile {
	public TestRplLoremUtf8(string bin_dir, string test_files_dir) {
		base(bin_dir, test_files_dir, "lorem-utf-8.txt");
		add_test("test_utf_8", test_utf_8);
		add_test("test_whole_words", test_whole_words);
	}

	void test_utf_8() {
		run({ "amét", "amèt", test_result_file.get_path() });
		assert_true(result_matches("lorem-utf-8_utf-8_expected.txt"));
	}

	void test_whole_words() {
		run({ "--whole-words", "in", "out", test_result_file.get_path() });
		assert_true(result_matches("lorem-utf-8_whole-words_expected.txt"));
	}
}

class TestRplUtf8Sig : TestRplFile {
	public TestRplUtf8Sig(string bin_dir, string test_files_dir) {
		base(bin_dir, test_files_dir, "utf-8-sig.txt");
		add_test("test_utf_8_sig", test_utf_8_sig);
	}

	void test_utf_8_sig() {
		run({ "BOM mark", "BOM", test_result_file.get_path() });
		assert_true(result_matches("utf-8-sig_utf-8-sig_expected.txt"));
	}
}

class TestRplMixedCase : TestRplFile {
	public TestRplMixedCase(string bin_dir, string test_files_dir) {
		base(bin_dir, test_files_dir, "mixed-case.txt");
		add_test("test_mixed_replace_lower", test_mixed_replace_lower);
	}

	void test_mixed_replace_lower() {
		run({ "-m", "MixedInput", "MixedOutput", test_result_file.get_path() });
		assert_true(result_matches("mixed-case_mixed-replace-lower_expected.txt"));
	}
}

class TestRplLoremBackreference : TestRplFile {
	public TestRplLoremBackreference(string bin_dir, string test_files_dir) {
		base(bin_dir, test_files_dir, "aba.txt");
		add_test("test_backreference_numbering", test_backreference_numbering);
	}

	void test_backreference_numbering() {
		run({ "a(b)a", "$1", test_result_file.get_path() });
		assert_true(result_matches("aba_backreference-numbering_expected.txt"));
	}
}

class TestRplEmptyMatches : TestRplFile {
	public TestRplEmptyMatches(string bin_dir, string test_files_dir) {
		base(bin_dir, test_files_dir, "abc-123.txt");
		add_test("test_empty_matches", test_empty_matches);
	}

	void test_empty_matches() {
		run({ "^", "#", test_result_file.get_path() });
		assert_true(result_matches("abc-123_empty-matches_expected.txt"));
	}
}

public int main(string[] args) {
	var test_files_dir = Environment.get_variable("TEST_FILES_DIR");
	var bin_dir = Path.get_dirname(args[0]);
	Test.init(ref args);
	TestSuite.get_root().add_suite(new TestRplNoFile(bin_dir, test_files_dir).get_suite());
	TestSuite.get_root().add_suite(new TestRplLorem8859_1(bin_dir, test_files_dir).get_suite());
	TestSuite.get_root().add_suite(new TestRplLorem(bin_dir, test_files_dir).get_suite());
	TestSuite.get_root().add_suite(new TestRplLoremUtf8(bin_dir, test_files_dir).get_suite());
	TestSuite.get_root().add_suite(new TestRplUtf8Sig(bin_dir, test_files_dir).get_suite());
	TestSuite.get_root().add_suite(new TestRplMixedCase(bin_dir, test_files_dir).get_suite());
	TestSuite.get_root().add_suite(new TestRplLoremBackreference(bin_dir, test_files_dir).get_suite());
	TestSuite.get_root().add_suite(new TestRplEmptyMatches(bin_dir, test_files_dir).get_suite());

	return Test.run();
}