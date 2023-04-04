from pathlib import Path

import pytest

from rpl import main

FIXTURE_DIR = Path(__file__).parent.resolve() / 'test_files'

@pytest.mark.datafiles(
    FIXTURE_DIR / 'lorem-iso-8859-1.txt'
)
def test_bad_encoding(datafiles: Path) -> None:
    test_file = str(datafiles / 'lorem-iso-8859-1.txt')
    with pytest.warns(UserWarning, match='decoding error'):
        main(['--encoding=utf-8', 'Lorem', 'L-O-R-E-M', test_file])
