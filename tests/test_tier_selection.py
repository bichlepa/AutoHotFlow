"""The tier selection of tests/conftest.py (F-0143): a run that asks for stress tests does not open a window."""
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GUI_STRESS = "test_the_window_fills_its_tree_with_200_big_flows"


def _collected(*args):
    env = dict(os.environ, AHF_NO_ADMISSION="1")
    out = subprocess.run([sys.executable, "-m", "pytest", "tests/stress/test_manager_big_flows.py", "--collect-only",
                          "-q", "-n", "0", *args], cwd=ROOT, env=env, capture_output=True, text=True, timeout=100)
    return out.stdout


def test_a_stress_run_leaves_out_the_stress_test_that_opens_a_window():
    assert GUI_STRESS not in _collected("-m", "stress")
    assert GUI_STRESS not in _collected("--all", "-m", "stress")


def test_a_stress_run_that_names_gui_includes_it():
    assert GUI_STRESS in _collected("-m", "stress or gui")
