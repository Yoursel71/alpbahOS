"""`alp search` folds Turkish dotted/dotless I so upper- and lower-case spellings match.

Found in the 29 Sep 2026 audit (handoff 020): _fold("IŞIK") gave "işik" (Python maps
"I" to "i") while _fold("ışık") stayed "ışık", so searching "ışık" missed a catalog
description written "IŞIK" (and the reverse). _fold already handled "İ".
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import alp  # noqa: E402


def test_dotless_and_dotted_i_fold_together():
    assert alp._fold("IŞIK") == alp._fold("ışık") == alp._fold("işik") == alp._fold("Işık")
    assert alp._fold("ISI") == alp._fold("ısı") == alp._fold("isi")
    assert alp._fold("İstanbul") == alp._fold("istanbul") == alp._fold("ıstanbul")


def test_english_search_is_unaffected():
    assert alp._fold("INFO Tool") == "info tool"
    assert alp._fold("Café") == "café"


def test_search_matches_across_turkish_i_spellings(capsys):
    index = {"entries": {
        "isik-araci": {"method": "core", "description": "IŞIK ve ekran parlaklığı aracı"},
        "ornek": {"method": "core", "description": "ilgisiz açıklama"},
    }}
    for term in ("ışık", "IŞIK", "işik", "Işık"):
        assert alp.cmd_search(index, term, as_json=True) == 0, term
        rows = json.loads(capsys.readouterr().out)
        assert [row["name"] for row in rows] == ["isik-araci"], term
    # ... and the other way round: lower-case description, upper-case query
    index["entries"]["isik-araci"]["description"] = "ışık ve ekran parlaklığı aracı"
    assert alp.cmd_search(index, "IŞIK", as_json=True) == 0
    assert [row["name"] for row in json.loads(capsys.readouterr().out)] == ["isik-araci"]
