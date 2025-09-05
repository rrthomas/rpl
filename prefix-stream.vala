#! /usr/bin/env -S vala --pkg gio-2.0
// PrefixInputStream: present some bytes followed by an InputStream as an
// InputStream.
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

public class PrefixInputStream : FilterInputStream {
	// Bytes that will be returned first from `read()`.
	private uint8[] prefix;
	private size_t read_ptr;

	public PrefixInputStream(uint8[] prefix, owned InputStream base_stream) {
		Object (base_stream: base_stream, close_base_stream: true);
		this.prefix = prefix;
		this.read_ptr = 0;
	}

	public override bool close (Cancellable? cancellable = null) throws IOError {
		if (this.close_base_stream) {
			return this.base_stream.close ();
		}
		return true;
	}

	public override ssize_t read (uint8[] buffer, Cancellable? cancellable = null) throws IOError {
		if (this.read_ptr < this.prefix.length) {
			// Satisfy the read from `this.prefix`.
			var ret = size_t.min (this.prefix.length - this.read_ptr, buffer.length);
			Memory.move (buffer, this.prefix[this.read_ptr:], ret);
			this.read_ptr += ret;
			return (ssize_t) ret;
		} else {
			// Satisfy the read from `this.base_stream`.
			return this.base_stream.read (buffer, cancellable);
		}
	}
}
