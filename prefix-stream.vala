#! /usr/bin/env -S vala --vapidir=. --pkg gio-2.0

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
