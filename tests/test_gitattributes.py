"""Guard of the line-ending setting of the repository.

The repository stores text files with LF because `.gitattributes` says `* text=auto eol=lf`: git converts CRLF to LF
when a file is staged. No test looks at the line endings themselves; this one only makes sure that the setting stays.
"""

from pathlib import Path

REPO = Path(__file__).resolve().parents[1]


def test_gitattributes_forces_lf_checkout():
    text = (REPO / ".gitattributes").read_text(encoding="utf-8")
    assert "* text=auto eol=lf" in text.splitlines(), "`.gitattributes` must set `* text=auto eol=lf`"
