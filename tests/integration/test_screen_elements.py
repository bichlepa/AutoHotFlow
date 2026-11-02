"""WI-0127: end-to-end tests of the screen elements of the package Default: Get pixel color, Search pixel, Search image,
Screenshot, Get screen settings and Set screen settings.

The searches and the screenshot read the real screen. They read an own window (helpers/screen_window.ahk): a red window
with a 20 x 20 picture at 40, 30 of its client area, which the test writes as a BMP file. The window is always on top, so
the tests of this module run one after the other (xdist group "screen"). The monitor settings (DDC/CI) go through the
system provider of the test entries (SystemOps, E0103): the test script answers them and no monitor is changed.
"""

import struct
import subprocess
import sys
import time
import uuid
from pathlib import Path

import pytest

from support.coreflows import run_all
from support.flowbuilder import FlowBuilder
from support.flowrun import flows  # noqa: F401  (fixture)
from support.system import SystemScript, error, value
from support.timing import scaled

pytestmark = pytest.mark.xdist_group("screen")

ROOT = Path(__file__).resolve().parents[2]
HELPERS = ROOT / "tests" / "integration" / "helpers"
AHKRUN = ROOT / "tools" / "ahkrun.py"
CREATE_NO_WINDOW = 0x08000000

PICTURE_X, PICTURE_Y, PICTURE_SIZE = 40, 30, 20   # the picture in the client area of the own window
GREEN, BLACK, RED = 0x00FF00, 0x000000, 0xFF0000  # the left half of the picture, the right half, the background


# --- helpers ----------------------------------------------------------------------------------------------------------
def write_bmp(path, size=PICTURE_SIZE):
    """A 24 bit BMP: the left half of the picture is green, the right half black."""
    row_bytes = (size * 3 + 3) // 4 * 4
    rows = []
    for y in range(size):
        row = bytearray()
        for x in range(size):
            color = GREEN if x < size // 2 else BLACK
            row += bytes([color & 0xFF, (color >> 8) & 0xFF, (color >> 16) & 0xFF])   # BGR
        row += b"\x00" * (row_bytes - size * 3)
        rows.append(bytes(row))
    pixels = b"".join(reversed(rows))                                                  # bottom row first
    header = struct.pack("<2sIHHI", b"BM", 54 + len(pixels), 0, 0, 54)
    info = struct.pack("<IiiHHIIiiII", 40, size, size, 1, 24, 0, len(pixels), 2835, 2835, 0, 0)
    path.write_bytes(header + info + pixels)
    return path


class ScreenWindow:
    """The own window of the test: its client area on the screen (x, y, w, h)."""

    def __init__(self, proc, stop, geometry, title):
        self.proc = proc
        self.stop = stop
        self.title = title
        self.x, self.y, self.w, self.h = geometry

    @property
    def picture_at(self):
        """The screen position of the upper left corner of the picture."""
        return self.x + PICTURE_X, self.y + PICTURE_Y

    def end(self):
        self.stop.write_text("stop", encoding="ascii")
        try:
            self.proc.wait(timeout=scaled(10))
        except subprocess.TimeoutExpired:
            self.proc.kill()
            self.proc.wait(timeout=scaled(10))


@pytest.fixture
def screen_window(tmp_path):
    """Starts the own window with the picture and waits until it is shown; the test ends it."""
    tag = uuid.uuid4().hex
    picture = write_bmp(tmp_path / ("picture-%s.bmp" % tag))
    ready, stop = tmp_path / ("ready-%s.txt" % tag), tmp_path / ("stop-%s.txt" % tag)
    title = "AhfScreenTest-" + tag
    args = [sys.executable, str(AHKRUN), "--timeout", "120", str(HELPERS / "screen_window.ahk"),
            title, str(ready), str(stop), str(picture)]
    proc = subprocess.Popen(args, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
                            creationflags=CREATE_NO_WINDOW)
    deadline = time.monotonic() + scaled(10)
    while not ready.exists() and time.monotonic() < deadline:
        time.sleep(0.05)
    if not ready.exists():
        proc.kill()
        raise AssertionError("the own screen window did not start: %s" % proc.stderr.read())
    geometry = [int(v) for v in ready.read_text(encoding="utf-8-sig").split()]
    window = ScreenWindow(proc, stop, geometry, title)
    yield window
    window.end()


def region_of(window):
    """The client area of the own window as a search region (the right and lower pixel included)."""
    return [window.x, window.y, window.x + window.w - 1, window.y + window.h - 1]


@pytest.fixture
def system(flows):
    """The script of the system provider: no answers, so every call returns the empty value and is only recorded."""
    script = SystemScript(flows.datadir)
    script.script({})
    return script


def element_flow(name, cls, probes=(), **pars):
    """trigger -> the element -> [a probe of variables]."""
    fb = FlowBuilder(name)
    el = fb.action(cls, **pars)
    parts = [fb.trigger(), el]
    if probes:
        parts.append(fb.probe(*probes))
    fb.chain(*parts)
    return fb


def calls(system, function):
    return [c for c in system.requests() if c["function"] == function]


def probed(run, names):
    return {name: run.seen[name].text for name in names}


def read_bmp_pixel(path, x, y):
    """The colour (0xRRGGBB) of the pixel (x, y), counted from the upper left corner, of a 24 or 32 bit BMP file."""
    data = path.read_bytes()
    offset = struct.unpack_from("<I", data, 10)[0]
    width, height = struct.unpack_from("<ii", data, 18)
    bytes_per_pixel = struct.unpack_from("<H", data, 28)[0] // 8
    row_bytes = (width * bytes_per_pixel + 3) // 4 * 4
    row = height - 1 - y if height > 0 else y               # a positive height stores the bottom row first
    start = offset + abs(row) * row_bytes + x * bytes_per_pixel
    blue, green, red = data[start], data[start + 1], data[start + 2]
    return (red << 16) | (green << 8) | blue


def bmp_size(path):
    data = path.read_bytes()
    width, height = struct.unpack_from("<ii", data, 18)
    return abs(width), abs(height)


# --- Get pixel color --------------------------------------------------------------------------------------------------
def test_get_pixel_color_stores_the_colour_of_a_pixel_of_the_picture(flows, screen_window):
    px, py = screen_window.picture_at
    fb = element_flow("pixel", "Action_Get_Pixel_Color", probes=["colorRGB"], OutputRGB=1, OutputSeparate=0,
                      varnameRGB="colorRGB", Xpos=px + 5, Ypos=py + 10, CoordMode="Screen", Method="Default")
    runs = run_all(flows, [fb])
    assert not runs[0].exceptions, runs[0].steps
    assert probed(runs[0], ["colorRGB"]) == {"colorRGB": "0x00FF00"}


def test_get_pixel_color_writes_each_channel_and_the_right_half_is_black(flows, screen_window):
    px, py = screen_window.picture_at
    fb = element_flow("pixel_sep", "Action_Get_Pixel_Color", probes=["r", "g", "b"], OutputRGB=0, OutputSeparate=1,
                      varnameR="r", varnameG="g", varnameB="b", Xpos=px + 15, Ypos=py + 3, CoordMode="Screen",
                      Method="Default")
    runs = run_all(flows, [fb])
    assert not runs[0].exceptions, runs[0].steps
    assert probed(runs[0], ["r", "g", "b"]) == {"r": "0", "g": "0", "b": "0"}


def test_get_pixel_color_of_the_background_is_red(flows, screen_window):
    px, py = screen_window.picture_at
    fb = element_flow("pixel_red", "Action_Get_Pixel_Color", probes=["r", "g", "b"], OutputRGB=0, OutputSeparate=1,
                      varnameR="r", varnameG="g", varnameB="b", Xpos=px + PICTURE_SIZE + 10, Ypos=py + 5,
                      CoordMode="Screen", Method="Default")
    runs = run_all(flows, [fb])
    assert not runs[0].exceptions, runs[0].steps
    assert probed(runs[0], ["r", "g", "b"]) == {"r": "255", "g": "0", "b": "0"}


# --- Search pixel -----------------------------------------------------------------------------------------------------
def test_search_pixel_finds_the_first_black_pixel_of_the_picture(flows, screen_window):
    fb = element_flow("search_pixel", "Action_Search_pixel", probes=["foundX", "foundY"], varnameX="foundX",
                      varnameY="foundY", CoordMode="Screen", WholeScreen=0, AllScreens=0, x1=screen_window.x,
                      y1=screen_window.y, x2=screen_window.x + screen_window.w - 1,
                      y2=screen_window.y + screen_window.h - 1, ColorID="0x000000", variation=0, FastMode=1)
    runs = run_all(flows, [fb])
    assert not runs[0].exceptions, runs[0].steps
    found_x = int(probed(runs[0], ["foundX"])["foundX"])
    found_y = int(probed(runs[0], ["foundY"])["foundY"])
    picture_x, picture_y = screen_window.picture_at
    assert picture_x + PICTURE_SIZE // 2 <= found_x < picture_x + PICTURE_SIZE, "the black half of the picture"
    assert picture_y <= found_y < picture_y + PICTURE_SIZE


def test_search_pixel_of_a_colour_that_is_not_there_is_an_exception(flows, screen_window):
    fb = element_flow("search_none", "Action_Search_pixel", varnameX="foundX", varnameY="foundY", CoordMode="Screen",
                      WholeScreen=0, AllScreens=0, x1=screen_window.x, y1=screen_window.y,
                      x2=screen_window.x + screen_window.w - 1, y2=screen_window.y + screen_window.h - 1,
                      ColorID="0x123456", variation=0, FastMode=1)
    runs = run_all(flows, [fb])
    assert runs[0].exceptions, runs[0].steps


# --- Search image -----------------------------------------------------------------------------------------------------
def test_search_image_finds_the_picture_at_its_position(flows, screen_window, tmp_path):
    picture = write_bmp(tmp_path / "search.bmp")
    fb = element_flow("search_image", "Action_Search_Image", probes=["imageX", "imageY"], varnameX="imageX",
                      varnameY="imageY", CoordMode="Screen", WholeScreen=0, AllScreens=0, x1=screen_window.x,
                      y1=screen_window.y, x2=screen_window.x + screen_window.w - 1,
                      y2=screen_window.y + screen_window.h - 1, file=str(picture), SetIconNumber=0, variation=0,
                      makeTransparent=0, ScaleImage=0)
    runs = run_all(flows, [fb])
    assert not runs[0].exceptions, runs[0].steps
    assert probed(runs[0], ["imageX", "imageY"]) == dict(zip(["imageX", "imageY"],
                                                             [str(v) for v in screen_window.picture_at]))


def test_search_image_of_a_missing_file_is_an_exception(flows, screen_window, tmp_path):
    fb = element_flow("search_missing", "Action_Search_Image", varnameX="imageX", varnameY="imageY", CoordMode="Screen",
                      WholeScreen=1, AllScreens=0, file=str(tmp_path / "no-such.bmp"), SetIconNumber=0, variation=0,
                      makeTransparent=0, ScaleImage=0)
    runs = run_all(flows, [fb])
    assert runs[0].exceptions, runs[0].steps


# --- Screenshot -------------------------------------------------------------------------------------------------------
def test_screenshot_of_a_region_saves_the_picture_in_a_bmp(flows, screen_window, tmp_path):
    px, py = screen_window.picture_at
    out = tmp_path / "region.bmp"
    fb = element_flow("shot_region", "Action_Screenshot", WhichRegion="Region", AllScreens=1, ScreenNumber=1,
                      x1=px, y1=py, x2=px + PICTURE_SIZE, y2=py + PICTURE_SIZE, file=str(out), Method="Gdip_FromScreen",
                      TitleMatchMode=1, Wintitle="", excludeTitle="", winText="", FindHiddenText=0, ExcludeText="",
                      ahk_class="", ahk_exe="", ahk_id="", ahk_pid="", FindHiddenWindow=0)
    runs = run_all(flows, [fb])
    assert not runs[0].exceptions, runs[0].steps
    assert bmp_size(out) == (PICTURE_SIZE, PICTURE_SIZE)
    assert read_bmp_pixel(out, 5, 10) == GREEN, "the left half of the picture is green"
    assert read_bmp_pixel(out, 15, 10) == BLACK, "the right half of the picture is black"


def test_screenshot_of_a_window_with_method_2_has_the_size_of_the_window(flows, screen_window, tmp_path):
    out = tmp_path / "window.bmp"
    fb = element_flow("shot_window", "Action_Screenshot", WhichRegion="Window", file=str(out),
                      Method="Gdip_FromHWND", TitleMatchMode=3, Wintitle=screen_window.title, excludeTitle="",
                      winText="", FindHiddenText=0, ExcludeText="", ahk_class="", ahk_exe="", ahk_id="", ahk_pid="",
                      FindHiddenWindow=0, AllScreens=1, ScreenNumber=1, x1=0, y1=0, x2=1, y2=1)
    runs = run_all(flows, [fb])
    assert not runs[0].exceptions, runs[0].steps
    assert bmp_size(out) == (screen_window.w, screen_window.h)
    assert read_bmp_pixel(out, PICTURE_X + 5, PICTURE_Y + 10) == GREEN


def test_screenshot_into_a_file_without_an_image_extension_is_an_exception(flows, screen_window, tmp_path):
    fb = element_flow("shot_txt", "Action_Screenshot", WhichRegion="Region", file=str(tmp_path / "shot.txt"),
                      x1=0, y1=0, x2=10, y2=10, AllScreens=1, ScreenNumber=1, Method="Gdip_FromScreen",
                      TitleMatchMode=1)
    runs = run_all(flows, [fb])
    assert runs[0].exceptions, runs[0].steps
    assert not (tmp_path / "shot.txt").exists()


def test_screenshot_of_a_window_that_does_not_exist_is_an_exception(flows, tmp_path):
    fb = element_flow("shot_none", "Action_Screenshot", WhichRegion="Window", file=str(tmp_path / "none.bmp"),
                      Method="Gdip_FromScreen", TitleMatchMode=3, Wintitle="AhfNoSuchWindow-" + uuid.uuid4().hex,
                      excludeTitle="", winText="", FindHiddenText=0, ExcludeText="", ahk_class="", ahk_exe="",
                      ahk_id="", ahk_pid="", FindHiddenWindow=0, AllScreens=1, ScreenNumber=1, x1=0, y1=0, x2=1, y2=1)
    runs = run_all(flows, [fb])
    assert runs[0].exceptions, runs[0].steps


# --- Get and Set screen settings (the DDC/CI calls of the system provider) ---------------------------------------------
def monitor_answers(names_and_values):
    """MonitorGetSetting answers in the order of the element: a Map with current, min and max."""
    return [value({"current": current, "min": low, "max": high}) for current, low, high in names_and_values]


def test_get_screen_settings_stores_the_values_of_the_monitor(flows, system):
    answers = monitor_answers([(70, 0, 100), (75, 0, 100), (50, 0, 100), (51, 0, 100), (52, 0, 100), (60, 0, 100),
                               (61, 0, 100), (62, 0, 100), (3, 0, 0)])
    system.script({"MonitorCount": [value(1)], "MonitorGetSetting": answers})
    fb = element_flow("get_screen", "Action_Get_Screen_Settings", probes=["bri", "briMin", "briMax", "red", "colorT"],
                      MonitorNumber=1, VarnameBrightness="bri", VarnameBrightnessMin="briMin",
                      VarnameBrightnessMax="briMax", VarnameRedGain="red", VarnameColorTemperature="colorT")
    runs = run_all(flows, [fb])
    assert not runs[0].exceptions, runs[0].steps
    assert probed(runs[0], ["bri", "briMin", "briMax", "red", "colorT"]) == {
        "bri": "70", "briMin": "0", "briMax": "100", "red": "50", "colorT": "3"}
    assert [c["args"][:2] for c in calls(system, "MonitorGetSetting")] == [
        [1, "brightness"], [1, "contrast"], [1, "gain"], [1, "gain"], [1, "gain"], [1, "drive"], [1, "drive"],
        [1, "drive"], [1, "colorTemperature"]]


def test_get_screen_settings_of_a_monitor_that_does_not_exist_is_an_exception(flows, system):
    system.script({"MonitorCount": [value(1)]})
    fb = element_flow("get_screen_no", "Action_Get_Screen_Settings", MonitorNumber=2)
    runs = run_all(flows, [fb])
    assert runs[0].exceptions, runs[0].steps
    assert not calls(system, "MonitorGetSetting")


def test_get_screen_settings_without_ddc_is_an_exception_that_names_the_setting(flows, system):
    system.script({"MonitorCount": [value(1)], "MonitorGetSetting": [error("no DDC/CI")]})
    fb = element_flow("get_screen_ddc", "Action_Get_Screen_Settings", MonitorNumber=1)
    runs = run_all(flows, [fb])
    assert runs[0].exceptions, runs[0].steps
    assert "Brightness" in str(runs[0].exceptions)


def test_set_screen_settings_changes_brightness_and_red_gain_of_one_monitor(flows, system):
    system.script({"MonitorCount": [value(2)]})
    fb = element_flow("set_screen", "Action_Set_Screen_Settings", AllMonitors=0, MonitorNumber=2,
                      WhetherChangeBrightness=1, brightness=40, WhetherSetRedGain=1, RedGain=60,
                      WhetherChangeContrast=0, WhetherSetGreenGain=0, WhetherSetBlueGain=0, WhetherSetRedDrive=0,
                      WhetherSetGreenDrive=0, WhetherSetBlueDrive=0, WhetherChangeColorTemperature=0)
    runs = run_all(flows, [fb])
    assert not runs[0].exceptions, runs[0].steps
    assert [c["args"] for c in calls(system, "MonitorSetSetting")] == [[2, "brightness", 40, 0], [2, "gain", 60, 0]]


def test_set_screen_settings_of_all_monitors_changes_each_one(flows, system):
    system.script({"MonitorCount": [value(2)]})
    fb = element_flow("set_all", "Action_Set_Screen_Settings", AllMonitors=1, MonitorNumber=1,
                      WhetherChangeBrightness=1, brightness=30, WhetherChangeContrast=0, WhetherSetRedGain=0,
                      WhetherSetGreenGain=0, WhetherSetBlueGain=0, WhetherSetRedDrive=0, WhetherSetGreenDrive=0,
                      WhetherSetBlueDrive=0, WhetherChangeColorTemperature=0)
    runs = run_all(flows, [fb])
    assert not runs[0].exceptions, runs[0].steps
    assert [c["args"] for c in calls(system, "MonitorSetSetting")] == [[1, "brightness", 30, 0], [2, "brightness", 30, 0]]


def test_set_screen_settings_writes_the_colour_temperature_index(flows, system):
    system.script({"MonitorCount": [value(1)]})
    fb = element_flow("set_temp", "Action_Set_Screen_Settings", AllMonitors=0, MonitorNumber=1,
                      WhetherChangeBrightness=0, WhetherChangeContrast=0, WhetherSetRedGain=0, WhetherSetGreenGain=0,
                      WhetherSetBlueGain=0, WhetherSetRedDrive=0, WhetherSetGreenDrive=0, WhetherSetBlueDrive=0,
                      WhetherChangeColorTemperature=1, ColorTemperature=3)
    runs = run_all(flows, [fb])
    assert not runs[0].exceptions, runs[0].steps
    assert [c["args"] for c in calls(system, "MonitorSetSetting")] == [[1, "colorTemperature", 3, 0]]


def test_set_screen_settings_refused_by_the_monitor_is_an_exception(flows, system):
    system.script({"MonitorCount": [value(1)], "MonitorSetSetting": [error("refused")]})
    fb = element_flow("set_refused", "Action_Set_Screen_Settings", AllMonitors=0, MonitorNumber=1,
                      WhetherChangeBrightness=1, brightness=10, WhetherChangeContrast=0, WhetherSetRedGain=0,
                      WhetherSetGreenGain=0, WhetherSetBlueGain=0, WhetherSetRedDrive=0, WhetherSetGreenDrive=0,
                      WhetherSetBlueDrive=0, WhetherChangeColorTemperature=0)
    runs = run_all(flows, [fb])
    assert runs[0].exceptions, runs[0].steps
