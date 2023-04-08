# rpl

A search/replace utility.

rpl replaces strings with new strings in multiple text files. See the man
page rpl(1) for more information. Install rpl using `pip install rpl`.

rpl is distributed under the terms of the GNU General Public License; either
version 3 of the License, or (at your option), any later version. See the
file COPYING for more details.

```
usage: rpl [-h] [--version] [--encoding ENCODING] [-i] [-m] [-w] [-b] [-q]
           [-v] [-s] [-e] [-F] [--files] [-x GLOB] [-R] [-p] [-f] [-d]
           OLD-TEXT NEW-TEXT [FILE ...]

Search and replace text in files.

positional arguments:
  OLD-TEXT
  NEW-TEXT
  FILE                  `-' or no FILE argument means standard input

options:
  -h, --help            show this help message and exit
  --version             show program's version number and exit
  --encoding ENCODING   specify character set encoding
  -i, --ignore-case     search case-insensitively
  -m, --match-case      ignore case when searching, but try to match case of
                        replacement to case of original, either capitalized,
                        all upper-case, or mixed
  -w, --whole-words     whole words (OLD-TEXT matches on word boundaries only)
  -b, --backup          rename original FILE to FILE~ before replacing
  -q, --quiet           quiet mode
  -v, --verbose         verbose mode
  -s, --dry-run         simulation mode
  -e, --escape          expand escapes in OLD-TEXT and NEW-TEXT [deprecated]
  -F, --fixed-strings   treat OLD-TEXT and NEW-TEXT as fixed strings, not
                        regular expressions
  --files               OLD-TEXT and NEW-TEXT are file names to read patterns
                        from
  -x GLOB, --glob GLOB  modify only files matching the given glob (may be
                        given more than once)
  -R, --recursive       search recursively
  -p, --prompt          prompt before modifying each file
  -f, --force           ignore errors when trying to preserve attributes
  -d, --keep-times      keep the modification times on modified files
```
