from pathlib import Path
import re

import pytest

from rpl import main

FIXTURE_DIR = Path(__file__).parent.resolve() / 'test_files'

@pytest.mark.datafiles(
    FIXTURE_DIR / 'lorem-iso-8859-1.txt'
)
def test_explicit_encoding(datafiles: Path) -> None:
    test_file = str(datafiles / 'lorem-iso-8859-1.txt')
    main(['--encoding=iso-8859-1', 'Lorem', 'L-O-R-E-M', test_file])
    assert re.match('L-O-R-E-M', open(test_file, encoding='iso-8859-1').read())
