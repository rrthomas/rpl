# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3, or (at your option)
# any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, see <https://www.gnu.org/licenses/>.

import argparse
import importlib.metadata
import io
import locale
import os
import shutil
import sys
import tempfile
import warnings
from enum import Enum, auto
from pathlib import Path
from stat import S_ISDIR, S_ISREG
from typing import BinaryIO, NoReturn, Optional, TextIO, Union, cast
from warnings import warn

import regex
from chainstream import ChainStream
from chardet.universaldetector import UniversalDetector
from regex import RegexFlag


VERSION = importlib.metadata.version("rpl")

PROG: str


def simple_warning(
    message: Union[Warning, str],
    category: type[Warning],
    filename: str,
    lineno: int,
    file: Optional[TextIO] = sys.stderr,
    line: Optional[str] = None,
) -> None:
    print(f"\n{PROG}: {message}", file=file or sys.stderr)


warnings.showwarning = simple_warning


def die(code: int, msg: str) -> NoReturn:
    warn(Warning(msg))
    sys.exit(code)


def slurp(filename: str) -> str:
    """Read a file into a string, aborting on error."""
    try:
        return Path(filename).read_text("utf-8")
    except OSError:
        die(os.EX_DATAERR, f"Could not read file {filename}")


def unescape(s: str) -> str:
    r = regex.compile(r"\\([0-7]{1,3}|x[0-9a-fA-F]{2}|[nrtvafb\\])")
    return r.sub(
        lambda match: cast(str, eval(f'"{match.group()}"')),
        s,
    )


class Case(Enum):
    LOWER = auto()
    UPPER = auto()
    CAPITALIZED = auto()
    MIXED = auto()


def casetype(string: str) -> Case:
    if string.upper() == string:
        return Case.UPPER
    if string.lower() == string:
        return Case.LOWER

    if string[0].isupper():
        # Could be capitalized
        all_lower = True

        for c in string[1:]:
            if not c.islower():
                all_lower = False
        if all_lower:
            return Case.CAPITALIZED
    return Case.MIXED


def caselike(model: str, string: str) -> str:
    if len(string) > 0:
        case_type = casetype(model)
        if case_type == Case.LOWER:
            string = string.lower()
        elif case_type == Case.UPPER:
            string = string.upper()
        elif case_type == Case.CAPITALIZED:
            string = string[0].upper() + string[1:].lower()
    return string


categ_pattern = regex.compile(r"\\p{[A-Za-z_]+}")


def replace(
    instream: BinaryIO,
    outstream: BinaryIO,
    regex_str: str,
    regex_opts: int,
    new_pattern: str,
    encoding: str,
    ignore_case: Union[str, bool],
) -> int:
    try:
        old_regex = regex.compile(regex_str, regex_opts)
    except regex.error as e:
        die(1, f"Bad regex {regex_str} ({e})")

    num_matches = 0
    buflen = io.DEFAULT_BUFFER_SIZE

    tonext = ""
    retry_prefix = b""
    while True:
        block = retry_prefix + instream.read(buflen)

        try:
            block_str = block.decode(encoding=encoding)
            retry_prefix = b""
        except UnicodeDecodeError as e:
            # Try carrying invalid input over to next iteration in case it's
            # just incomplete
            if e.start > 0:
                retry_prefix = block[e.start :]
                block_str = block[: e.start].decode(encoding=encoding)
            else:
                raise e

        search_str = tonext + block_str
        if len(search_str) == 0:
            break
        results = []
        matches = list(old_regex.finditer(search_str, partial=len(block) > 0))
        matching_from = 0
        for i, match in enumerate(matches):
            results.append(search_str[matching_from : match.start()])
            if not match.partial and (match.end() < len(search_str) or len(block_str) == 0):
                num_matches += 1
                replacement = match.expand(new_pattern)
                if ignore_case == "match":
                    replacement = caselike(match.group(), replacement)
                results.append(replacement)
                matching_from = match.end()
            elif matches[i].start() < len(search_str):
                tonext = search_str[matches[i].start() :]
                buflen *= 2
                break
        else:
            tonext = ""
            if len(matches) >= 1:
                results.append(search_str[matches[-1].end(): ])
            else:
                results.append(search_str)

        joined_parts = "".join(results)
        outstream.write(joined_parts.encode(encoding=encoding))

    outstream.write(tonext.encode(encoding=encoding))

    return num_matches


def get_parser() -> argparse.ArgumentParser:
    # Create command line argument parser.
    parser = argparse.ArgumentParser(
        description="Search and replace text in files.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    global PROG
    PROG = parser.prog
    parser.add_argument(
        "--version",
        action="version",
        version="%(prog)s "
        + VERSION
        + """
Copyright (C) 2018-2025 Reuben Thomas <rrt@sc3d.org>
Copyright (C) 2017 Jochen Kupperschmidt <homework@nwsnet.de>
Copyright (C) 2016 Kevin Coyner <kcoyner@debian.org>
Copyright (C) 2004-2005 Göran Weinholt <weinholt@debian.org>
Copyright (C) 2004 Christian Häggström <chm@c00.info>

Licence GPLv3+: GNU GPL version 3 or later <https://gnu.org/licenses/gpl.html>.
This is free software: you are free to change and redistribute it.
There is NO WARRANTY, to the extent permitted by law.""",
    )

    parser.add_argument("--encoding", help="specify character set encoding")

    parser.add_argument(
        "-E", "--extended-regex", action="store_true", help=argparse.SUPPRESS
    )

    parser.add_argument(
        "-i", "--ignore-case", action="store_true", help="search case-insensitively"
    )

    parser.add_argument(
        "-m",
        "--match-case",
        action="store_const",
        dest="ignore_case",
        const="match",
        help="ignore case when searching, but try to match case of replacement to "
        + "case of original, either capitalized, all upper-case, or mixed",
    )

    parser.add_argument(
        "-w",
        "--whole-words",
        action="store_true",
        help="whole words (OLD-TEXT matches on word boundaries only)",
    )

    parser.add_argument(
        "-b",
        "--backup",
        action="store_true",
        help="rename original FILE to FILE~ before replacing",
    )

    parser.add_argument("-q", "--quiet", action="store_true", help="quiet mode")

    parser.add_argument("-v", "--verbose", action="store_true", help="verbose mode")

    parser.add_argument("-s", "--dry-run", action="store_true", help="simulation mode")

    parser.add_argument(
        "-e",
        "--escape",
        action="store_true",
        help="expand escapes in OLD-TEXT and NEW-TEXT [deprecated]",
    )

    parser.add_argument(
        "-F",
        "--fixed-strings",
        action="store_true",
        help="treat OLD-TEXT and NEW-TEXT as fixed strings, not regular expressions",
    )

    parser.add_argument(
        "--files",
        action="store_true",
        help="OLD-TEXT and NEW-TEXT are file names to read patterns from",
    )

    parser.add_argument(
        "-x",
        "--glob",
        action="append",
        help="modify only files matching the given glob (may be given more than once)",
    )

    parser.add_argument(
        "-R", "--recursive", action="store_true", help="search recursively"
    )

    parser.add_argument(
        "-p", "--prompt", action="store_true", help="prompt before modifying each file"
    )

    parser.add_argument(
        "-f",
        "--force",
        action="store_true",
        help="ignore errors when trying to preserve attributes",
    )

    parser.add_argument(
        "-d",
        "--keep-times",
        action="store_true",
        help="keep the modification times on modified files",
    )

    parser.add_argument("old_str", metavar="OLD-TEXT")
    parser.add_argument("new_str", metavar="NEW-TEXT")
    parser.add_argument(
        "file",
        metavar="FILE",
        nargs="*",
        help="`-' or no FILE argument means standard input",
    )

    return parser


def main(argv: list[str] = sys.argv[1:]) -> None:
    args = get_parser().parse_args(argv)

    files = args.file

    # If no --glob arguments given, use a match-all glob
    if args.glob is None:
        args.glob = ["*"]

    # If no files given, assume stdin
    if len(files) == 0:
        if args.recursive:
            die(1, "Cannot use --recursive with no file arguments!")
        files = ["-"]
    else:
        expanded_files: list[Path] = []
        for file in files:
            for glob in args.glob:
                if args.recursive and os.path.isdir(file):
                    expanded_files += Path(file).rglob(glob)
                elif Path(file) in Path(os.path.dirname(file)).glob(glob):
                    expanded_files.append(file)
        files = expanded_files
        if len(files) == 0:
            die(1, "The given filename patterns did not match any files!")

    # Get old and new text patterns
    if args.files:
        old_str = slurp(args.old_str)
        new_str = slurp(args.new_str)
    else:
        old_str = args.old_str
        new_str = args.new_str

    # Tell the user what is going to happen
    if not args.quiet:
        warn(
            '{} "{}" with "{}" ({}; {})'.format(
                "Simulating replacement of" if args.dry_run else "Replacing",
                old_str,
                new_str,
                (
                    "ignoring case"
                    if args.ignore_case is True
                    else (
                        "matching case"
                        if args.ignore_case == "match"
                        else "case sensitive"
                    )
                ),
                "whole words only" if args.whole_words else "partial words matched",
            )
        )

    if args.dry_run and not args.quiet:
        warn("The files listed below would be modified in a replace operation")

    encoding = None
    if args.encoding:
        encoding = args.encoding

    if args.escape:
        old_str = unescape(old_str)
        new_str = unescape(new_str)

    if args.fixed_strings:
        old_str = regex.escape(old_str)
        new_str = new_str.replace("\\", r"\\")

    regex_str = old_str
    if args.whole_words:
        regex_str = r"\b" + regex_str + r"\b"
    # Call regex.compile so we get an error if the regex is invalid, & count groups.
    opts = RegexFlag.VERSION1 + RegexFlag.MULTILINE
    if args.ignore_case:
        opts += RegexFlag.IGNORECASE

    total_files = 0
    matched_files = 0
    total_matches = 0
    for filename in files:
        perms = None
        if filename == "-":
            filename = "standard input"
            # Access stdin and stdout as binary.
            f = sys.stdin.buffer
            o = sys.stdout.buffer
            tmp_path = None
        else:
            # Check `filename` is a regular file, and get its permissions
            try:
                perms = os.lstat(filename)
            except OSError as e:
                warn(f"Skipping {filename}: unable to read permissions; error: {e}")
                continue
            if S_ISDIR(perms.st_mode):
                if args.verbose:
                    warn(f"Skipping directory {filename}")
                continue
            if not S_ISREG(perms.st_mode):
                warn(f"Skipping: {filename} (not a regular file)")
                continue

            # Open the input file
            try:
                f = open(filename, "rb")
            except OSError as e:
                warn(f"Skipping {filename}: cannot open for reading; error: {e}")
                continue

            # Create the output file
            try:
                tmp_o, tmp_path = tempfile.mkstemp("", ".tmp.")
                o = os.fdopen(tmp_o, "wb")
            except OSError as e:
                warn(f"Skipping {filename}: cannot create temp file; error: {e}")
                continue

            # Set permissions and owner
            if perms is not None:
                try:
                    os.chown(tmp_path, perms.st_uid, perms.st_gid)
                    os.chmod(tmp_path, perms.st_mode)
                except OSError as e:
                    warn(f"Unable to set attributes of {filename}; error: {e}")
                    if args.force:
                        warn("New file attributes may not match!")
                    else:
                        warn(f"Skipping {filename}!")
                        os.unlink(tmp_path)
                        continue

        total_files += 1

        # If no encoding specified, reset guess for each file
        if not args.encoding:
            encoding = None

        if args.verbose and not args.dry_run:
            warn(f"Processing: {filename}")

        # If we don't have an explicit encoding, guess
        block = b""
        if encoding is None:
            detector = UniversalDetector()
            scanned_bytes = 0
            # Scan at most 1MB, so we don't give up too soon, but don't slurp a
            # large file.
            while scanned_bytes < 1024 * 1024:
                next_block = f.read(io.DEFAULT_BUFFER_SIZE)
                if len(next_block) == 0:
                    break
                scanned_bytes += len(next_block)
                block += next_block
                detector.feed(next_block)
                if detector.done:
                    break
            f = io.BufferedReader(ChainStream([io.BytesIO(block), f]))

            detector.close()
            if detector.done:
                encoding = detector.result["encoding"]
                if args.verbose:
                    if encoding is not None:
                        warn(f"Guessed encoding '{encoding}'")
                    else:
                        warn("Unable to guess encoding")
            if encoding is None:
                encoding = locale.getpreferredencoding(False)
                if args.verbose:
                    warn(f"Could not guess encoding; using locale default '{encoding}'")

            # Disable special handling of BOM in UTF-8 files, otherwise it would be
            # inserted after each replacement
            if encoding.upper() == "UTF-8-SIG":
                encoding = "UTF-8"

        # Do the actual work now
        try:
            num_matches = replace(
                f, o, regex_str, opts, new_str, encoding, args.ignore_case
            )
        except UnicodeDecodeError as e:
            warn(f"{filename}: decoding error ({e.reason})")
            warn("You can specify the encoding with --encoding")
            num_matches = 0

        f.close()
        o.close()

        if num_matches == 0:
            if tmp_path is not None:
                os.unlink(tmp_path)
            continue
        matched_files += 1

        if args.dry_run:
            if tmp_path is None:
                fn = filename
            else:
                try:
                    fn = os.path.realpath(filename)
                except OSError:
                    fn = filename
                os.unlink(tmp_path)

            if not args.quiet:
                print(f"  {fn}", file=sys.stderr)

            total_matches += num_matches
            continue

        if args.prompt:
            print(f'\nSave "{filename}"? ([Y]/N) ', file=sys.stderr, end="")

            line = ""
            while line == "" or line[0] not in "Yy\nnN":
                line = input()

            if line[0] in "nN":
                print("Not saved", file=sys.stderr)
                if tmp_path is not None:
                    os.unlink(tmp_path)
                continue

            print("Saved", file=sys.stderr)

        if tmp_path is not None:
            if args.backup:
                backup_name = f"{filename}~"
                try:
                    shutil.move(filename, backup_name)
                except OSError as e:
                    warn(f"Error renaming {filename} to {backup_name}; error: {e}")
                    continue

            # Rename the file
            try:
                shutil.move(tmp_path, filename)
            except OSError as e:
                warn(f"Could not replace {tmp_path} with {filename}; error: {e}")
                os.unlink(tmp_path)
                continue

            # Restore the times
            if args.keep_times and perms is not None:
                try:
                    os.utime(filename, (perms.st_atime, perms.st_mtime))
                except OSError as e:
                    warn(f"Error setting timestamps of {filename}: {e}")

        total_matches += num_matches

    # We're about to exit, give a summary
    if not args.quiet:
        warn(
            "{} matches {} in {} out of {} file{}".format(
                total_matches,
                "found" if args.dry_run else "replaced",
                matched_files,
                total_files,
                "s" if total_files != 1 else "",
            )
        )
