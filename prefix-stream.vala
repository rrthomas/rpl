#! /usr/bin/env -S vala --vapidir=. --pkg gio-2.0
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


// Tests. TODO: enable these.

//  void debug(string name, uint8[] data) {
//  	stdout.write(name.data);
//  	stdout.write(" holds '".data);
//  	stdout.write(data);
//  	stdout.write("'\n".data);
//  }

//  public static void main(string[] args) {
//      InputStream input = new MemoryInputStream.from_data(
//          "a single man in possession of a good fortune must be in want of a wife.".data
//      );
//      PrefixInputStream prefix_input = new PrefixInputStream((owned) input);
//      debug("prefix_input.prefix", prefix_input.prefix.data);
//      prefix_input.unread(
//          "It is a truth universally acknowledged, that ".data
//      );
//      debug("prefix_input.prefix", prefix_input.prefix.data);
//      var output = new uint8[80];
//      size_t num_bytes;
//      prefix_input.read_all(output, out num_bytes);
//      debug("prefix_input.prefix", prefix_input.prefix.data);
//      debug("output", output);
//  }
