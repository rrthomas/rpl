#! /usr/bin/env -S vala --vapidir=. --pkg gio-2.0 --pkg posix
// Slurp a file.
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

public StringBuilder ? slurp (File filename) {
    StringBuilder contents = null;
    int fd = open(filename.get_path (), O_RDONLY);
    var len = lseek (fd, 0, Posix.SEEK_END);
    lseek (fd, 0, Posix.SEEK_SET);
    contents = new StringBuilder.sized((size_t) (len + 1));
    ssize_t bytes_read = read(fd, contents.data, len);
    if (bytes_read < 0) {
        return null;
    }
    contents.data[bytes_read] = '\0';
    contents.len = bytes_read;
    return contents;
}