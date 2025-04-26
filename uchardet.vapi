/* uchardet.vapi
 *
 * Copyright (C) 2025 Reuben Thomas
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

[Compact]
[CCode (cprefix = "uchardet_", cheader_filename = "uchardet.h", cname = "uchardet_t", free_function = "uchardet_delete")]
public class UCharDet {
	[CCode (cname = "uchardet_new")]
	public UCharDet ();

	public int handle_data ([CCode (array_length_type = "size_t")] uint8[] data);

	public void data_end ();

	public void data_reset ();

	public unowned string get_charset ();
}