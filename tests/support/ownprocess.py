"""WI-0132: own processes for the tests of the process triggers. A copy of cmd.exe under a unique name (its base name is
the filter of the trigger, so no other process of the user has it), started with `pause` (waits for a key on its stdin).
Killed at the end of the test if it still runs. No process of the user is started, watched or ended by these tests.
"""

import os
import shutil
import subprocess
import uuid
from pathlib import Path

from support.timing import scaled

CREATE_NO_WINDOW = 0x08000000


class OwnProcess:
    """A process of a test: its base name (unique) and its Popen."""

    def __init__(self, name, proc):
        self.name = name
        self.proc = proc

    @property
    def pid(self):
        return self.proc.pid

    def alive(self):
        return self.proc.poll() is None

    def end(self):
        if self.proc.poll() is None:
            self.proc.kill()
        self.proc.wait(timeout=scaled(20))


def new_name():
    """A base name that no process of the user has (the name is used before the process starts, as a filter)."""
    return "ahf_wi0132_" + uuid.uuid4().hex[:12] + ".exe"


def start_named_copy(folder, name=None):
    """A copy of cmd.exe named `name` (a new one when None) in folder, started with `pause`."""
    name = name or new_name()
    copy = Path(folder) / name
    shutil.copyfile(Path(os.environ["SystemRoot"]) / "System32" / "cmd.exe", copy)
    proc = subprocess.Popen([str(copy), "/c", "pause"], creationflags=CREATE_NO_WINDOW,
                            stdin=subprocess.PIPE, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return OwnProcess(name, proc)
