import os
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import alp  # noqa: E402


@pytest.mark.skipif(hasattr(os, "geteuid") and os.geteuid() == 0, reason="root ignores directory modes")
def test_lock_without_write_permission_gives_turkish_message(tmp_path):
    state = tmp_path / "state"
    state.mkdir()
    state.chmod(0o555)
    try:
        with pytest.raises(alp.AlpError) as info:
            with alp.DbLock(state / "alp.lock"):
                pass
    finally:
        state.chmod(0o755)
    text = str(info.value)
    assert "sudo" in text and "yönetici yetkisi" in text
    assert "Errno" not in text
