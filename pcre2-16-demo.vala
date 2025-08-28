#! /usr/bin/env -S vala --vapidir=. --pkg pcre2
// pcre2-16-demo: Demo of pcre2.vapi used with 16-bit libpcre2.
//
// © 2025 Reuben Thomas <rrt@sc3d.org>
//
// This program is in the public domain.

using Pcre2;

int main () {
	var hello_world = "helló, wórld!";
	string16 hello_world_utf16 = null;
	var search = "ó";
	string16 search_utf16 = null;
	var search_utf16_arr = new uint16[search.char_count ()];
	try {
		hello_world_utf16 = hello_world.to_utf16 ();
		search_utf16 = search.to_utf16 ();
	} catch (ConvertError e) {}
	Memory.move (search_utf16_arr, search_utf16, search.char_count () * sizeof(uint16));
	var subject = new StringBuilder ();
	subject.append_len ((string) hello_world_utf16, (ssize_t) (hello_world.char_count () * sizeof(uint16)));
	print (@"subject length (characters): $(subject.len / sizeof(uint16))\n");
	print (@"search length (characters): $(search_utf16_arr.length)\n");

	int errorcode;
	size_t erroroffset;
	var re = Pcre2.Regex.compile ((Pcre2.Uchar[]) search_utf16_arr, 0, out errorcode, out erroroffset, null);

	int rc = 0;
	for (size_t offset = 0; offset < hello_world.char_count () * sizeof(uint16); ) {
		print (@"offset: $offset\n");
		Match? match = re.match (subject, offset, 0, out rc);
		if (rc == Pcre2.Error.NOMATCH) {
			print ("no match\n");
			break;
		} else if (rc < 0) {
			GLib.stderr.printf (@"match returned error $rc\n");
			break;
		}
		offset = match.group_end (0);
		print (@"found a match at position $(match.group_start (0))\n");
	}

	return 0;
}
