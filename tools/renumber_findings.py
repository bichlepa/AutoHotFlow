"""Gives the provisional finding IDs of a branch their final numbers (doc/ORCHESTRATOR.md section 2, "Finding IDs").

Usage (in a workspace whose branch is already rebased onto the current v2-port):
    python tools/renumber_findings.py --dry-run     # show the mapping and the files, change nothing
    python tools/renumber_findings.py               # change the files
    python tools/renumber_findings.py --commit      # change the files and commit them

What it does:
  * a provisional ID is F-9 followed by three digits, with or without a trailing star (written here as F-9nnn and
    F-9nnn*, so that this file does not contain one). It is defined by its entry heading in doc/OPEN-ITEMS.md or
    doc/CLOSED-ITEMS.md ("### F-9nnn*: Title").
  * the final number of a provisional ID is the highest final number (F-0001 to F-8999) in the headings of both files
    plus one, counting up in the order of the first heading (OPEN-ITEMS first, then CLOSED-ITEMS).
  * every reference to the provisional ID in the tracked text files (git ls-files, except v1/) becomes the final ID
    without the star. Bytes other than the ID are not touched: line endings and encoding stay as they are. Binary
    files (NUL bytes) are skipped.
  * before anything is written it checks: the working tree has no changes to tracked files; every provisional ID that
    is referenced has a heading; each new number is not used anywhere in the tracked files (git grep, v1 included);
    the resulting headings pass the rules of tests/test_open_items_ids.py (no provisional heading left, no gap or
    duplicate from F-0086 on). A failed check changes nothing.
  * with no provisional heading it prints "nothing to renumber" and exits 0. References to provisional IDs that have
    no heading are then not looked at (old text in the history keeps them).

Exit code: 0 done or nothing to renumber, 1 refused by a check (references without heading, used number, no room,
rules of the ID test), 2 usage error, dirty working tree or git error.
Not covered: the tool does not check which branch it runs on, and it does not run the ID test itself; the test runs in
the main checkout (in a workspace it is skipped). Replacements in code comments and in prose are plain text
replacements; a reference that means a different thing and happens to read F-9xxx would be changed too.
"""

import argparse
import re
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]

OPEN_ITEMS = "doc/OPEN-ITEMS.md"
CLOSED_ITEMS = "doc/CLOSED-ITEMS.md"
DENSE_FROM = 86            # same as tests/test_open_items_ids.py
MAX_FINAL = 8999
REFERENCE_FOLDER = "v1"          # the v1 reference tree, removed after the port
EXCLUDED_PREFIX = (REFERENCE_FOLDER + "/").encode()

HEADING = re.compile(rb"^### (F-(\d{4}))\*?:", re.MULTILINE)
PROVISIONAL_REF = re.compile(rb"F-(9\d{3})(?!\d)\*?")
MAX_SHOWN = 10

EXIT_OK = 0
EXIT_REFUSED = 1
EXIT_USAGE = 2


class Refused(Exception):
    """A check failed; the message says why. Nothing has been written."""


def git(repo, *args, check=True, input_bytes=None):
    proc = subprocess.run(["git", *args], cwd=str(repo), capture_output=True, input=input_bytes)
    if check and proc.returncode != 0:
        raise RuntimeError("git %s failed: %s" % (" ".join(args), proc.stderr.decode("utf-8", "replace").strip()))
    return proc


def tracked_files(repo):
    out = git(repo, "ls-files", "-z").stdout
    return [raw for raw in out.split(b"\0") if raw]


def is_binary(data):
    return b"\0" in data


def headings_of(data):
    """(digits, is_provisional) of every entry heading in one file, in document order."""
    return [(m.group(2).decode(), m.group(2).startswith(b"9")) for m in HEADING.finditer(data)]


def check_dense(numbers):
    """The rule of tests/test_open_items_ids.py: no duplicate and no gap from DENSE_FROM on."""
    duplicates = sorted({n for n in numbers if numbers.count(n) > 1})
    if duplicates:
        raise Refused("finding IDs used twice after the renumbering: %s" % ", ".join("F-%s" % d for d in duplicates))
    above = sorted({int(n) for n in numbers if int(n) >= DENSE_FROM})
    expected = list(range(DENSE_FROM, DENSE_FROM + len(above)))
    if above != expected:
        raise Refused("finding IDs from F-%04d on have a gap after the renumbering: %s" % (DENSE_FROM, above))


def plan(repo):
    """Returns None when there is nothing to renumber, else (mapping, changes) where mapping is {b"9090": "F-0101"}
    and changes is {relative path bytes: (new bytes, replacement count)} for the files that change.
    Raises Refused when a check fails."""
    open_data = (repo / OPEN_ITEMS).read_bytes()
    closed_path = repo / CLOSED_ITEMS
    closed_data = closed_path.read_bytes() if closed_path.exists() else b""
    headings = headings_of(open_data) + headings_of(closed_data)

    provisional = []
    for digits, is_prov in headings:
        if is_prov and digits not in provisional:
            provisional.append(digits)
    if not provisional:
        return None
    for digits in provisional:
        if sum(1 for d, _ in headings if d == digits) > 1:
            raise Refused("F-%s has more than one heading; the renumbering needs one entry per provisional ID"
                          % digits)

    finals = [int(d) for d, is_prov in headings if not is_prov]
    first = max(finals) + 1 if finals else 1
    if first + len(provisional) - 1 > MAX_FINAL:
        raise Refused("no free final numbers left (F-%04d is the last)" % MAX_FINAL)
    mapping = {d.encode(): "F-%04d" % (first + i) for i, d in enumerate(provisional)}

    files = [raw for raw in tracked_files(repo) if not raw.startswith(EXCLUDED_PREFIX)]
    orphans = []
    texts = {}
    for raw in files:
        path = repo / raw.decode("utf-8", "surrogateescape")
        if not path.is_file():
            continue
        data = path.read_bytes()
        if is_binary(data):
            continue
        texts[raw] = data
        for m in PROVISIONAL_REF.finditer(data):
            if m.group(1) not in mapping:
                line = data.count(b"\n", 0, m.start()) + 1
                orphans.append("%s:%d: F-%s" % (raw.decode("utf-8", "replace"), line, m.group(1).decode()))
    if orphans:
        raise Refused("provisional IDs referenced without a heading (%d): %s"
                      % (len(orphans), "; ".join(orphans[:MAX_SHOWN])))

    for new in mapping.values():
        number = new[2:]
        proc = git(repo, "grep", "-n", "-E", "F-%s([^0-9]|$)" % number, check=False)
        if proc.returncode == 0:
            hits = proc.stdout.decode("utf-8", "replace").splitlines()
            raise Refused("%s is already used (%d places, first: %s)" % (new, len(hits), hits[0]))
        if proc.returncode != 1:
            raise RuntimeError("git grep failed: %s" % proc.stderr.decode("utf-8", "replace").strip())

    changes = {}
    for raw, data in texts.items():
        count = [0]

        def replace(m):
            count[0] += 1
            return mapping[m.group(1)].encode()

        new_data = PROVISIONAL_REF.sub(replace, data)
        if count[0]:
            changes[raw] = (new_data, count[0])

    new_open = changes[OPEN_ITEMS.encode()][0] if OPEN_ITEMS.encode() in changes else open_data
    new_closed = changes[CLOSED_ITEMS.encode()][0] if CLOSED_ITEMS.encode() in changes else closed_data
    after = headings_of(new_open) + headings_of(new_closed)
    if any(is_prov for _, is_prov in after):
        raise Refused("provisional headings are left after the renumbering")
    check_dense([d for d, _ in after])
    return mapping, changes


def working_tree_clean(repo):
    return not git(repo, "status", "--porcelain", "--untracked-files=no").stdout.strip()


def run(repo, dry_run=False, commit=False, out=print):
    if not working_tree_clean(repo):
        out("refused: the working tree has changes to tracked files (commit or stash them first)")
        return EXIT_USAGE
    try:
        result = plan(repo)
    except Refused as e:
        out("refused: %s" % e)
        return EXIT_REFUSED
    if result is None:
        out("nothing to renumber")
        return EXIT_OK
    mapping, changes = result
    pairs = ["F-%s* -> %s" % (old.decode(), new) for old, new in sorted(mapping.items(), key=lambda kv: kv[1])]
    out("mapping: " + ", ".join(pairs))
    for raw, (_, count) in sorted(changes.items()):
        out("  %s  (%d reference%s)" % (raw.decode("utf-8", "replace"), count, "" if count == 1 else "s"))
    if dry_run:
        out("dry run: nothing written")
        return EXIT_OK
    for raw, (data, _) in changes.items():
        (repo / raw.decode("utf-8", "surrogateescape")).write_bytes(data)
    out("written: %d file%s" % (len(changes), "" if len(changes) == 1 else "s"))
    if commit:
        paths = [raw.decode("utf-8", "surrogateescape") for raw in changes]
        git(repo, "add", "--", *paths)
        message = "Renumber provisional findings: " + ", ".join(pairs) + "\n\n" + (
            "Provisional IDs of the branch get the next free final numbers (doc/ORCHESTRATOR.md section 2).\n")
        git(repo, "commit", "-q", "-F", "-", input_bytes=message.encode("utf-8"))
        out("committed: " + git(repo, "log", "-1", "--format=%h %s").stdout.decode("utf-8", "replace").strip())
    return EXIT_OK


def main(argv=None, repo=REPO):
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--dry-run", action="store_true", help="show the mapping and the files, change nothing")
    parser.add_argument("--commit", action="store_true", help="commit the change (message: the mapping)")
    args = parser.parse_args(argv)
    if args.dry_run and args.commit:
        print("--dry-run and --commit exclude each other", file=sys.stderr)
        return EXIT_USAGE
    try:
        return run(repo, dry_run=args.dry_run, commit=args.commit)
    except RuntimeError as e:
        print("tool error: %s" % e, file=sys.stderr)
        return EXIT_USAGE


if __name__ == "__main__":
    sys.exit(main())
