from pathlib import Path
import re

import pytest

from rpl import main

FIXTURE_DIR = Path(__file__).parent.resolve() / 'test_files'

@pytest.mark.datafiles(
    FIXTURE_DIR / 'lorem.txt'
)
def test_use_regexp(datafiles: Path) -> None:
    test_file = str(datafiles / 'lorem.txt')
    main(['a[a-z]+', 'coffee', test_file])
    with open(test_file, encoding='ascii') as f:
        assert re.search('coffee elit', f.read(), re.IGNORECASE)
