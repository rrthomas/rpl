/* Alternative binding of GLib's iconv.
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
 * As a special exception, if you use inline functions from this file, this
 * file does not by itself cause the resulting executable to be covered by
 * the GNU Lesser General Public License.
 *
 * Author:
 *  Reuben Thomas <rrt@sc3d.org>
 */

[CCode (cprefix = "G", lower_case_cprefix = "g_", cheader_filename = "glib.h", gir_namespace = "GLib", gir_version = "2.0")]
namespace IConv {
    [SimpleType]
    [CCode (has_type_id = false)]
    public struct IConv {
        public static IConv open (string to_codeset, string from_codeset);

        [CCode (cname = "g_iconv")]
        public size_t iconv (ref char* inbuf, ref size_t inbytes_left, ref char* outbuf, ref size_t outbytes_left);
        public int close ();
    }
}