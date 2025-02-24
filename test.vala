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

class TestRpl : GeeTestCase {
	private string rpl;
	protected string test_files_dir;
	protected File tmp_file;
	protected IOStream tmp_ios;

	public TestRpl(string bin_dir, string test_files_dir) {
		base("TestRpl");
		this.rpl = Path.build_filename(bin_dir, "rpl");
		this.test_files_dir = test_files_dir;
	}

	public Output run(string[] args) {
		string[] cmd = { rpl };
		foreach (var arg in args) {
			cmd += arg;
		}
		string stdout;
		string stderr;
		try {
			assert_true(Process.spawn_sync(null, cmd, null, 0, null, out stdout, out stderr));
		} catch (SpawnError e) {
			Test.fail_printf("error running rpl\n");
		}
		return Output() { stdout = stdout, stderr = stderr };
	}

	public override void set_up() {
		try {
			tmp_file = File.new_tmp("rpl.test.XXXXXX", out tmp_ios);
		} catch (GLib.Error e) {
			Test.fail_printf("error creating temporary file\n");
		}
	}

	public override void tear_down() {
		try {
			tmp_file.@delete();
		} catch (Error e) {
			Test.fail_printf("error deleting test file\n");
		}
	}

	public StringBuilder test_result() {
		var result = slurp(tmp_file);
		if (result == null) {
			Test.fail_printf("error reading test result");
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

	public void test_version() {
		var output = run({ "--version" });
		assert_true(output.stdout.contains("NO WARRANTY, to the extent"));
	}

	public void multi_buffer_matches() {
		try {
			tmp_ios.output_stream.write(string.nfill(1024 * 1024, 'a').data);
			tmp_ios.close();
		} catch (GLib.Error e) {
			Test.fail_printf("error writing to temporary file");
		}
		run({ "a+", "b", tmp_file.get_path() });
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
			assert_true(src.copy(tmp_file, FileCopyFlags.OVERWRITE, null));
		} catch (Error e) {
			Test.fail_printf("error copying test file");
		}
	}

	private bool matches_result(string pattern, Pcre2.CompileFlags options = 0) {
		int error_code;
		size_t error_offset;
		var regex = Pcre2.Regex.compile(pattern.data, options, out error_code, out error_offset);
		if (error_code < 0) {
			Test.fail_printf(@"bad regex in test: $(Pcre2.get_error_message(error_code))");
		}
		int rc;
		regex.match(test_result(), 0, 0, out rc);
		return rc > 0;
	}

	public void assert_match(string pattern, Pcre2.CompileFlags options = 0) {
		assert_true(matches_result(pattern, options));
	}

	public void assert_no_match(string pattern, Pcre2.CompileFlags options = 0) {
		assert_false(matches_result(pattern, options));
	}
}

class TestRplLorem8859_1 : TestRplFile {
	public TestRplLorem8859_1(string bin_dir, string test_files_dir) {
		base(bin_dir, test_files_dir, "lorem-iso-8859-1.txt");
		add_test("test_bad_encoding", test_bad_encoding);
		add_test("test_explicit_encoding", test_explicit_encoding);
	}

	public void test_bad_encoding() {
		var output = run({ "--encoding=utf-8", "Lorem", "L-O-R-E-M", test_file });
		assert_true(output.stderr.contains("error decoding"));
	}

	public void test_explicit_encoding() {
		run({ "--encoding=iso-8859-1", "Lorem", "L-O-R-E-M", tmp_file.get_path() });
		assert_match("L-O-R-E-M");
	}
}

class TestRplLorem : TestRplFile {
	public TestRplLorem(string bin_dir, string test_files_dir) {
		base(bin_dir, test_files_dir, "lorem.txt");
		add_test("test_ignore_case", test_ignore_case);
		add_test("test_match_case", test_match_case);
		add_test("test_no_flags", test_no_flags);
		add_test("test_use_regexp", test_use_regexp);
	}

	public void test_ignore_case() {
		run({ "-iv", "Lorem", "L-O-R-E-M", tmp_file.get_path() });
		assert_match("L-O-R-E-M");
	}

	public void test_match_case() {
		run({ "lorem", "loReM", tmp_file.get_path() });
		assert_match("lorem", Pcre2.CompileFlags.CASELESS);
	}

	public void test_no_flags() {
		run({ "Lorem", "L-O-R-E-M", tmp_file.get_path() });
		assert_match("L-O-R-E-M");
	}

	public void test_use_regexp() {
		run({ "a[a-z]+", "coffee", tmp_file.get_path() });
		assert_match("coffee elit", Pcre2.CompileFlags.CASELESS);
	}
}

class TestRplLoremUtf8 : TestRplFile {
	public TestRplLoremUtf8(string bin_dir, string test_files_dir) {
		base(bin_dir, test_files_dir, "lorem-utf-8.txt");
		add_test("test_utf_8", test_utf_8);
	}

	public void test_utf_8() {
		run({ "amét", "amèt", tmp_file.get_path() });
		assert_match("amèt");
	}
}

class TestRplUtf8Sig : TestRplFile {
	public TestRplUtf8Sig(string bin_dir, string test_files_dir) {
		base(bin_dir, test_files_dir, "utf-8-sig.txt");
		add_test("test_utf_8_sig", test_utf_8_sig);
	}

	public void test_utf_8_sig() {
		run({ "BOM mark", "BOM", tmp_file.get_path() });
		assert_no_match("\ufeff at");
	}
}

class TestRplMixedCase : TestRplFile {
	public TestRplMixedCase(string bin_dir, string test_files_dir) {
		base(bin_dir, test_files_dir, "mixed-case.txt");
		add_test("test_mixed_replace_lower", test_mixed_replace_lower);
	}

	public void test_mixed_replace_lower() {
		run({ "-m", "MixedInput", "MixedOutput", tmp_file.get_path() });
		assert_match("^mixedoutput MIXEDOUTPUT Mixedoutput MixedOutput$");
	}
}

class TestRplLoremBackreference : TestRplFile {
	public TestRplLoremBackreference(string bin_dir, string test_files_dir) {
		base(bin_dir, test_files_dir, "aba.txt");
		add_test("test_backreference_numbering", test_backreference_numbering);
	}

	public void test_backreference_numbering() {
		run({ "a(b)a", "$1", tmp_file.get_path() });
		assert_true(test_result().str == "b\n");
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

	return Test.run();
}