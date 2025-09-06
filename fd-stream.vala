#! /usr/bin/env -S vala --pkg gio-2.0 --pkg posix
// FdStream: turn file descriptors into InputStreams and OutputStreams.
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

using Posix;

public class FdInputStream : InputStream {
	private int fd;

	public FdInputStream(int fd) {
		this.fd = fd;
	}

	public override bool close (Cancellable? cancellable = null) throws IOError {
		return (Posix.close (fd) == 0);
	}

	public override ssize_t read (uint8[] buffer, Cancellable? cancellable = null) throws IOError {
		return Posix.read (this.fd, buffer, buffer.length);
	}
}

public class FdOutputStream : OutputStream {
	private int fd;

	public FdOutputStream(int fd) {
		this.fd = fd;
	}

	public override bool close (Cancellable? cancellable = null) throws IOError {
		return (Posix.close (fd) == 0);
	}

	public override ssize_t write (uint8[] buffer, Cancellable? cancellable = null) throws IOError {
		return Posix.write (this.fd, buffer, buffer.length);
	}
}
