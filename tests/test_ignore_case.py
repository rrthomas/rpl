from pathlib import Path
import re

import pytest

from rpl import main

FIXTURE_DIR = Path(__file__).parent.resolve() / 'test_files'

@pytest.mark.datafiles(
    FIXTURE_DIR / 'lorem.txt'
)
def test_ignore_case(datafiles: Path) -> None:
    test_file = str(datafiles / 'lorem.txt')
    main(['-iv', 'Lorem', 'L-O-R-E-M', test_file])
    with open(test_file, encoding='utf-8') as f:
        assert re.match('L-O-R-E-M', f.read())
