/* chardet.vapi
 *
 * Copyright (C) 2026 Reuben Thomas
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301  USA
 *
 * Author:
 *  Reuben Thomas <rrt@sc3d.org>
 */


[CCode (lower_case_cprefix = "")]
namespace Chardet {
	[CCode (cname = "short", cprefix = "CHARDET_", cheader_filename = "chardet.h", has_type_id = false)]
	public enum Result {
		MEM_ALLOCATED_FAIL,
		OUT_OF_MEMORY,

		SUCCESS,
		NO_RESULT,
		NULL_OBJECT,
	}

	[CCode (cname = "detect")]
	public static Result detect (string dat, ref DetectObj obj);

	// TODO
	// [Compact]
	// [CCode (cprefix = "detect_", cheader_filename = "chardet.h", cname = "Detect_t", free_function = "detect_destroy")]
	// public class Detect {
	//	public static unowned string version ();
	//	public static unowned string uversion ();

	//	[CCode (cname = "chardet_init")]
	//	public Detect ();
	//	public void reset ();
	//	public void dataend ();
	//	public DetectResult handledata (string dat, DetectObj *obj);
	// }

	[Compact]
	[CCode (cname = "DetectObj", cheader_filename = "chardet.h", free_function = "", has_type_id = false)]
	public class DetectObj {
		public unowned string encoding;
		public float confidence;

		[CCode (cname = "detect_obj_init")]
		public DetectObj ();
		[CCode (cname = "detect_obj_free")]
		public static void free (ref DetectObj obj);
	}
}
