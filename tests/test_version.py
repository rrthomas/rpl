import re

import pytest
from pytest import CaptureFixture

from rpl import main

def test_version(capsys: CaptureFixture[str]) -> None:
    with pytest.raises(SystemExit) as e:
        main(['--version'])
    assert e.type == SystemExit
    assert e.value.code == 0
    assert re.search('ABSOLUTELY NO WARRANTY', capsys.readouterr().out)
