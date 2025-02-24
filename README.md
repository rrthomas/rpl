# rpl

https://github.com/rrthomas/rpl  
© 2025 Reuben Thomas <rrt@sc3d.org>  

A search/replace utility.

rpl replaces strings with new strings in multiple text files.

rpl is distributed under the terms of the GNU General Public License; either
version 3 of the License, or (at your option), any later version. See the
file COPYING for more details.

`rpl` is written in [Vala](https://vala.dev), based on an earlier Python
program by Christian Häggström, Göran Weinholt, Kevin Coyner, Jochen
Kupperschmidt and Reuben Thomas.


## Installation

If you’re lucky, rpl will be available from your distribution, such as
Ubuntu or Homebrew.


### Building from source

To build `rpl` you will need a C compiler, GNU Make, GLib, PCRE2 and
[uchardet](https://www.freedesktop.org/wiki/Software/uchardet/). These
should already be packaged in most distributions. (Although `rpl` is written
in Vala, a Vala compiler is only needed for development.)

Download the [latest
release](https://github.com/rrthomas/rpl/releases/latest), and unpack it
with `tar`. `cd` into the unpacked sources, and run:

```
./configure
make check
```

Once you’re happy you can run `make install`, possibly with `sudo`.


### Building from git

As well as the dependencies for building from source, you will need Vala,
automake, autoconf, gengetopt and help2man. These should be packaged in most
distributions.

Having cloned the repository, run `autoreconf -fi`, then follow the
instructions above for building from source.


## Usage

See the man page rpl(1) for more information.

```
Usage: rpl [OPTION]... OLD-TEXT NEW-TEXT [FILE ...]
Search and replace text in files.

  -h, --help               Print help and exit
  -V, --version            Print version and exit
      --encoding=ENCODING  specify character set encoding
  -w, --whole-words        whole words (OLD-TEXT matches on word boundaries
                             only)  (default=off)
  -b, --backup             rename original FILE to FILE~ before replacing
                             (default=off)
  -q, --quiet              quiet mode  (default=off)
  -v, --verbose            verbose mode  (default=off)
  -s, --dry-run            simulation mode  (default=off)
  -F, --fixed-strings      treat OLD-TEXT and NEW-TEXT as fixed strings, not
                             regular expressions  (default=off)
      --files              OLD-TEXT and NEW-TEXT are file names to read
                             patterns from  (default=off)
  -x, --glob=GLOB          modify only files matching the given glob (may be
                             given more than once)  (default=`*')
  -R, --recursive          search recursively  (default=off)
  -p, --prompt             prompt before modifying each file  (default=off)
  -f, --force              ignore errors when trying to preserve attributes
                             (default=off)
  -d, --keep-times         keep the modification times on modified files
                             (default=off)

 Group: case
  Treatment of upper and lower case
  -i, --ignore-case        search case-insensitively
  -m, --match-case         ignore case when searching, but try to match case of
                             replacement to case of original, either
                             capitalized, all upper-case, or mixed
```
