"""Upper time limits of the tests under parallel load (WI-32, doc/TEST-STRATEGY.md, section "Zeitgrenzen").

A limit like "the role exits within 1 s" is a promise of the product (ARCHITECTURE 6). It can only be measured
exactly when the machine does nothing else. The standard run is parallel (pytest-xdist, one test process per CPU,
each test starting several AutoHotkey processes), so a process can be descheduled for a few hundred ms and miss
such a limit without any defect (1.158 s against a limit of 1.0 s was seen).

Therefore every upper limit that states a product promise goes through `scaled()`:
  - serial run (-n 0, -m stress, -m soak): factor 1, the limit is exactly the promise. This is the reference.
  - parallel run (pytest-xdist worker): factor PARALLEL_FACTOR. A red test then means "much too slow", not "a bit
    slow on a busy machine".
Only UPPER limits are scaled. Lower limits (a timeout must not fire early), counts and results are never relaxed.

AHF_TIMING_FACTOR overrides the factor (a number, e.g. 1 to be strict in a parallel run, or 5 on a slow machine).
"""

import os

PARALLEL_FACTOR = 3.0


def load_factor():
    given = os.environ.get("AHF_TIMING_FACTOR", "").strip()
    if given:
        return float(given)
    return PARALLEL_FACTOR if os.environ.get("PYTEST_XDIST_WORKER") else 1.0


def scaled(limit):
    """The upper limit (seconds, milliseconds or a count of the same unit) adjusted to the load of the run."""
    return limit * load_factor()
