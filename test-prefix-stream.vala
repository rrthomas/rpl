#! /usr/bin/env -S vala --pkg gio-2.0 prefix-stream.vala testcase.vala
// Tests for PrefixInputStream.
//
// © 2025 Alistair Turnbull <apt1002@mupsych.org>
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

class PrefixStreamTests : GeeTestCase {

	public PrefixStreamTests() {
		base ("PrefixStreamTests");
		add_test ("basic_test", basic_test);
	}

	void basic_test () {
		InputStream input = new MemoryInputStream.from_data (
			"a single man in possession of a good fortune must be in want of a wife.".data
		);
		PrefixInputStream prefix_input = new PrefixInputStream (
			"It is a truth universally acknowledged, that ".data,
			(owned) input
		);
		var output = new uint8[80];
		size_t num_bytes;
		try {
			prefix_input.read_all (output, out num_bytes);
		} catch (IOError e) {}
		assert_true ((string) output == "It is a truth universally acknowledged, that a single man in possession of a goo");
	}
}

public static int main (string[] args) {
	Test.init (ref args);
	Test.set_nonfatal_assertions ();
	TestSuite.get_root ().add_suite (new PrefixStreamTests ().get_suite ());
	return Test.run ();
}
