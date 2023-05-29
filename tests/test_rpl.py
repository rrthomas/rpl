from pathlib import Path
import re

import pytest
from pytest import CaptureFixture

from rpl import main

FIXTURE_DIR = Path(__file__).parent.resolve()


@pytest.mark.datafiles(FIXTURE_DIR / "lorem-iso-8859-1.txt")
def test_bad_encoding(datafiles: Path) -> None:
    test_file = str(datafiles / "lorem-iso-8859-1.txt")
    with pytest.warns(UserWarning, match="decoding error"):
        main(["--encoding=utf-8", "Lorem", "L-O-R-E-M", test_file])


@pytest.mark.datafiles(FIXTURE_DIR / "lorem-iso-8859-1.txt")
def test_explicit_encoding(datafiles: Path) -> None:
    test_file = str(datafiles / "lorem-iso-8859-1.txt")
    main(["--encoding=iso-8859-1", "Lorem", "L-O-R-E-M", test_file])
    with open(test_file, encoding="iso-8859-1") as f:
        assert re.match("L-O-R-E-M", f.read())


@pytest.mark.datafiles(FIXTURE_DIR / "lorem.txt")
def test_ignore_case(datafiles: Path) -> None:
    test_file = str(datafiles / "lorem.txt")
    main(["-iv", "Lorem", "L-O-R-E-M", test_file])
    with open(test_file, encoding="utf-8") as f:
        assert re.match("L-O-R-E-M", f.read())


@pytest.mark.datafiles(FIXTURE_DIR / "lorem.txt")
def test_match_case(datafiles: Path) -> None:
    test_file = str(datafiles / "lorem.txt")
    main(["lorem", "loReM", test_file])
    with open(test_file, encoding="ascii") as f:
        assert re.match("lorem", f.read(), re.IGNORECASE)


@pytest.mark.datafiles(FIXTURE_DIR / "lorem.txt")
def test_no_flags(datafiles: Path) -> None:
    test_file = str(datafiles / "lorem.txt")
    main(["Lorem", "L-O-R-E-M", test_file])
    with open(test_file, encoding="ascii") as f:
        assert re.search("L-O-R-E-M", f.read())


@pytest.mark.datafiles(FIXTURE_DIR / "lorem.txt")
def test_use_regexp(datafiles: Path) -> None:
    test_file = str(datafiles / "lorem.txt")
    main(["a[a-z]+", "coffee", test_file])
    with open(test_file, encoding="ascii") as f:
        assert re.search("coffee elit", f.read(), re.IGNORECASE)


@pytest.mark.datafiles(FIXTURE_DIR / "lorem-utf-8.txt")
def test_utf_8(datafiles: Path) -> None:
    test_file = str(datafiles / "lorem-utf-8.txt")
    main(["amét", "amèt", test_file])
    with open(test_file, encoding="utf-8") as f:
        assert re.search("amèt", f.read())


def test_version(capsys: CaptureFixture[str]) -> None:
    with pytest.raises(SystemExit) as e:
        main(["--version"])
    assert e.type == SystemExit
    assert e.value.code == 0
    assert re.search("NO WARRANTY, to the extent", capsys.readouterr().out)
