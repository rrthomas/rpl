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

Some of the tests require `sudo` to run. You will need to use a user or session that can use `sudo` without a password. In many setups, you can run `sudo true` to authenticate, and will then be able to run the tests (with `make check` as usual) for some period of time before the authentication expires. If `sudo` does not work, the tests that require it will be skipped.

The code coverage test target `assert-full-coverage` requires all the tests to have been run.

### Building from git

As well as the dependencies for building from source, you will need Vala,
automake, autoconf, gengetopt and help2man. These should be packaged in most
distributions.

Having cloned the repository, run `autoreconf -fi`, then follow the
instructions above for building from source.


## Usage

`rpl [OPTION...] OLD-TEXT NEW-TEXT [FILE ...]`

See `rpl --help` or the man page rpl(1) for more information.
