from pathlib import Path
import re

import pytest

from rpl import main

FIXTURE_DIR = Path(__file__).parent.resolve() / 'test_files'

@pytest.mark.datafiles(
    FIXTURE_DIR / 'lorem-utf-8.txt'
)
def test_utf_8(datafiles: Path) -> None:
    test_file = str(datafiles / 'lorem-utf-8.txt')
    main(['amét', 'amèt', test_file])
    assert re.search('amèt', open(test_file, encoding='utf-8').read())
