"""Fixtures of the fault injection tests (WI-15). Imported by the test modules (a conftest.py here would shadow tests/conftest.py for `from conftest import ...`).

chains(...) is the factory every test uses. Each chain it creates is closed at teardown, and the teardown
fails the test if a process of its session is still alive after that (psutil check, WI-15 acceptance).
"""

import pytest

from faultkit import Chain, session_processes, wait_until


@pytest.fixture
def chains(procs, datadir, session_id):
    made = []

    def make(start, extra=(), label="sup", session=None):
        chain = Chain(procs, datadir, session or session_id, start, extra, label=label)
        made.append(chain)
        return chain

    yield make
    for chain in made:
        chain.close()
    problems = []
    for chain in made:
        # kill() is asynchronous on Windows: give the processes a short moment before the verdict
        if not wait_until(lambda: not session_processes(chain.session), 5.0):
            problems.append((chain.session, session_processes(chain.session)))
    assert not problems, "processes left behind: %s" % problems
