"""Writes the parameter schema of the v1 element classes to tests/data/v1_schema.json (work item WI-0116).

FROZEN like the golden data: the file is regenerated on purpose only. The schema of a class is what
`Element_getParametrizationDetails_<class>` returns in v1 (the settings dialog description: fields, ids, defaults,
content types, choices). The v2 classes must keep these ids and values unless a difference is listed with its
MIGRATION ID (tests/schema/test_v1_schema.py, doc/TEST-STRATEGY.md section 8c).

Usage:
    python tools/v1_schema.py            write tests/data/v1_schema.json
    python tools/v1_schema.py --check    generate, do not write; exit 1 when the checked-in file differs

How it works: v1 has no reflection, so the script for the v1 interpreter is generated here, into a temp folder. It
includes the unchanged v1 files (the element files of v1/Source_Elements/Default and its common folder, and the v1 JSON
library), defines the stand-ins for the functions these files call (x_lang returns the key with spaces, as the v2
Lang() does without a language file; every other missing function gets an empty stub), calls every
Element_getParametrizationDetails_<class> and writes one line per class. The script runs through
tools/ahkrun.py --interpreter (dialog guard, timeout). Nothing under v1/ is changed.

Result format: {"description": ..., "classes": {"Default.<class>": [field, ...], ...}}; a field is the object of v1
as Jxon_Dump writes it (numbers stay numbers; v1 has no booleans, true is 1).
"""

import argparse
import json
import os
import re
import shutil
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)

import ahkrun  # noqa: E402

V1_DIR = os.path.join(ROOT, "v1")
V1_EXE = os.path.join(V1_DIR, "AutoHotKey", "AutoHotFlow.exe")
V1_ELEMENTS = os.path.join(V1_DIR, "Source_Elements", "Default")
V1_JSON = os.path.join(V1_DIR, "Lib", "Json", "Jxon.ahk")
KINDS = ("Actions", "Conditions", "Loops", "Triggers")
DATA = os.path.join(ROOT, "tests", "data", "v1_schema.json")
PACKAGE = "Default"
TIMEOUT_S = 120
MAX_STUB_ROUNDS = 300

FUNCTION = re.compile(r"^Element_getParametrizationDetails_(\w+)\(", re.M)
X_CALL = re.compile(r"\bx_\w+(?=\s*\()", re.IGNORECASE)
MISSING_FUNCTION = re.compile(r"nonexistent function\.\s+Specifically: (\w+)\(")

SCRIPT_HEAD = "#NoEnv\n#SingleInstance Off\nSetBatchLines, -1\n#Include %s\n"

# x_lang returns the text of a key. Without texts the key with spaces stands for it, as v2 Lang() does without a
# language file (LangTable: "_" is a space).
SCRIPT_STUB_LANG = r"""
x_lang(key, p1 = "", p2 = "", p3 = "", p4 = "", p5 = "", p6 = "", p7 = "", p8 = "")
{
	StringReplace, key, key, _, %A_Space%, All
	return key
}
"""

SCRIPT_RANDOM_PHRASE = r"""
; The random words of a default ID: the value is volatile, so a marker stands for it (see the test of WI-0116).
x_randomPhrase(p1 = "", p2 = "", p3 = "", p4 = "", p5 = "", p6 = "", p7 = "", p8 = "", p9 = "", p10 = "")
{
	return "<randomPhrase>"
}
"""

SCRIPT_MAIN = r"""
outFile := A_Args[1]
FileDelete, %outFile%
"""


def v1_element_files():
    """Returns {class name: path} of the v1 element classes; one parameter function per file."""
    found = {}
    for kind in KINDS:
        folder = os.path.join(V1_ELEMENTS, kind)
        for name in sorted(os.listdir(folder)):
            if not name.endswith(".ahk"):
                continue
            path = os.path.join(folder, name)
            with open(path, encoding="latin-1") as f:    # the v1 files are not all UTF-8; only names are read
                names = FUNCTION.findall(f.read())
            if len(names) != 1:
                raise ValueError("%s: expected one Element_getParametrizationDetails_ function, found %d"
                                 % (path, len(names)))
            if names[0] in found:
                raise ValueError("class %s is in two files: %s and %s" % (names[0], found[names[0]], path))
            found[names[0]] = path
    return found


def common_files():
    """The v1 files that the element functions share (Source_Elements/Default/common)."""
    folder = os.path.join(V1_ELEMENTS, "common")
    return [os.path.join(folder, name) for name in sorted(os.listdir(folder)) if name.endswith(".ahk")]


def x_names(paths):
    """The x_* names that the files call, without x_lang, each once, spelled as first found."""
    names = {}
    for path in paths:
        with open(path, encoding="latin-1") as f:
            for name in X_CALL.findall(f.read()):
                names.setdefault(name.lower(), name)
    names.pop("x_lang", None)
    names.pop("x_randomphrase", None)
    return [names[key] for key in sorted(names)]


def stub_text(names):
    """Empty functions with ten optional parameters (v1 checks the number of parameters at load time too)."""
    params = ", ".join('p%d = ""' % i for i in range(1, 11))
    return "".join("\n%s(%s)\n{\n\treturn\n}\n" % (name, params) for name in names)


def build_script(folder, paths, classes, stubs):
    """Writes the v1 script into folder and returns its path. paths: the v1 files to include, classes: the parameter
    functions to call, stubs: the names of the functions that get an empty stand-in."""
    lines = [SCRIPT_HEAD % quote_path(V1_JSON)]
    for path in paths:
        lines.append("#Include %s\n" % quote_path(path))
    lines.append(SCRIPT_STUB_LANG)
    lines.append(SCRIPT_RANDOM_PHRASE)
    lines.append(stub_text(stubs))
    lines.append(SCRIPT_MAIN)
    for name in sorted(classes):
        lines.append('res := Element_getParametrizationDetails_%s("")\n' % name)
        lines.append('FileAppend, %% "%s`t" Jxon_Dump(res, "") "`n", %%outFile%%\n' % name)
    lines.append("ExitApp, 0\n")
    path = os.path.join(folder, "v1_schema.ahk")
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write("".join(lines))
    return path


def quote_path(path):
    # v1 #Include takes the rest of the line; the path must be absolute.
    return os.path.abspath(path)


def parse_output(text):
    """Returns {class name: list of fields} from the lines the v1 script wrote (class name, tab, JSON)."""
    result = {}
    for line in text.splitlines():
        if not line.strip():
            continue
        name, sep, body = line.partition("\t")
        if not sep:
            raise ValueError("line without the tab after the class name: %r" % line[:120])
        result[name] = json.loads(body)
    return result


def generate():
    """Runs the v1 script and returns (schema, stubs): the schema of the v1 classes and the names of the stand-ins."""
    classes = v1_element_files()
    paths = common_files() + [classes[name] for name in sorted(classes)]
    stubs = x_names(paths)
    folder = tempfile.mkdtemp(prefix="ahf_v1schema_")
    try:
        # v1 checks at load time that every function a file calls exists and reports the first missing one. The
        # script runs again with a stand-in for it, until the files load; a name is stubbed at most once.
        for _ in range(MAX_STUB_ROUNDS):
            script = build_script(folder, paths, classes, stubs)
            out = os.path.join(folder, "schema.txt")
            code, stdout, stderr, dialogs = ahkrun.run(script, [out], TIMEOUT_S, interpreter=V1_EXE)
            if code == 0 and not dialogs:
                break
            missing = MISSING_FUNCTION.search(stderr)
            if not missing or missing.group(1).lower() in {name.lower() for name in stubs}:
                raise RuntimeError("the v1 schema script failed (exit %s): %s %s %s"
                                   % (code, stderr.strip(), " ".join(d.summary() for d in dialogs),
                                      stdout.strip()))
            stubs.append(missing.group(1))
        else:
            raise RuntimeError("the v1 files still call missing functions after %d rounds" % MAX_STUB_ROUNDS)
        with open(out, encoding="utf-8") as f:
            parsed = parse_output(f.read())
    finally:
        shutil.rmtree(folder, ignore_errors=True)
    if sorted(parsed) != sorted(classes):
        missing = sorted(set(classes) - set(parsed))
        raise RuntimeError("the v1 script wrote no line for: %s" % ", ".join(missing))
    schema = {
        "description": "Parameter schema of the v1 element classes (Element_getParametrizationDetails_<class>), "
                       "written by tools/v1_schema.py from the unchanged v1 code. Regenerate on purpose only.",
        "classes": {PACKAGE + "." + name: parsed[name] for name in sorted(parsed)},
    }
    return schema, sorted(stubs, key=str.lower)


def render(data):
    return json.dumps(data, indent=2, ensure_ascii=False, sort_keys=True) + "\n"


def main(argv):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--check", action="store_true", help="generate, do not write; exit 1 on a difference")
    args = parser.parse_args(argv)
    schema, stubs = generate()
    text = render(schema)
    print("v1 classes: %d; stand-ins for functions the v1 files call: %d" % (len(schema["classes"]), len(stubs)))
    if args.check:
        with open(DATA, encoding="utf-8") as f:
            same = f.read() == text
        print("%s is %s" % (DATA, "up to date" if same else "DIFFERENT from the v1 code"))
        return 0 if same else 1
    os.makedirs(os.path.dirname(DATA), exist_ok=True)
    with open(DATA, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)
    print("wrote %s" % DATA)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
