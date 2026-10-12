"""Sends cmd.test.dump to the test role echo of a running test supervisor, so that Debug.Dump runs in that role.

Manual test of the debug window (WI-28, step 6): start the test entry with the echo role and the debug window,
then run this script. The value appears in the tab "Werte" of the debug window.

    python tools/ahf_dump.py                      (session main, role echo:a, value of the default kind)
    python tools/ahf_dump.py --kind big --title "a long text"

Start the supervisor first, for example with the task "Start: Testeinstieg mit Debug-Fenster (echo)".
The test role exists only with --test-roles (tests/integration/helpers/AutoHotFlowTest.ahk).
"""

import argparse
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "tests"))

from support.ahfclient import AhfClient  # noqa: E402
from support import pipenames  # noqa: E402

DEFAULT_VALUE = {"name": "Skeleton", "list": [1, "two", 3.5], "nested": {"ok": True}}


def main(argv):
    ap = argparse.ArgumentParser(description="Calls Debug.Dump in the test role echo (cmd.test.dump).")
    ap.add_argument("--session", default="main", help="session id of the supervisor (default: main)")
    ap.add_argument("--role", default="echo:a", help="name of the echo role in that supervisor (default: echo:a)")
    ap.add_argument("--title", default="manual test", help="title of the value in the debug window")
    ap.add_argument("--kind", default="value", choices=["value", "cycle", "deep", "objects", "big"],
                    help="value (default), or a case from the tests: cycle, deep, objects, big")
    args = ap.parse_args(argv)
    pipe = pipenames.hub_pipe(args.session)
    try:
        with AhfClient(pipe, "dump-tool", connect_timeout=5.0) as client:
            answer = client.request(args.role, "cmd.test.dump",
                                    {"title": args.title, "value": DEFAULT_VALUE, "kind": args.kind}, timeout=5.0)
    except Exception as e:
        print("no answer from %s on pipe %s: %s: %s" % (args.role, pipe, type(e).__name__, e), file=sys.stderr)
        return 1
    payload = answer["payload"]
    print("answer: %s" % payload)
    return 0 if payload.get("ok") and payload.get("failed", 1) == 0 else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
