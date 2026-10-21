"""Generates the HTML help pages from their Markdown sources (WI-0112, E0100, REQ-LNG-040).

The help is written in Markdown. The viewers of the program (WI-0111, WI-0115) show HTML, so every source has a
generated page next to it, with the same name and the extension `.html`:

  src/elements/<package>/help/<lang>/<Kind>/<Name>.md   the page of an element (`<Kind>` Actions, Conditions, Loops,
                                                        Triggers; `<Name>` the class name without its kind prefix)
  assets/help/<lang>/<Name>.md                           a general page (welcome, variables, key list, color chart)

A page is complete on its own: the shared stylesheet `assets/help/help.css` is copied into every page, so the pages
work in the classic viewer, in WebView2 and in a browser, from any folder. Links between the pages are written as
relative links to the `.md` source (`[Sleep](Sleep.md)`, `[Variables](../../../../../../assets/help/en/Variables.md)`);
the tool rewrites them to `.html` and fails when a target does not exist. The first `# ` line of a page is its title.

  python tools/gen_help.py            write the pages (and delete the pages whose source is gone)
  python tools/gen_help.py --check    write nothing, exit 1 when a page is missing, stale or superfluous, or a link
                                      or a title is broken (tests/test_help.py runs this)

The HTML files are committed. Never edit them by hand: edit the Markdown and run the tool. The Markdown library
(`markdown`, `tests/requirements.txt`) is a development dependency: the program itself shows the committed HTML.
"""

import argparse
import html
import re
import sys
from pathlib import Path

import markdown

ROOT = Path(__file__).resolve().parents[1]

# The help roots: one folder per language. A package may ship its own help (src/elements/<package>/help/<lang>).
ELEMENT_HELP_GLOB = "src/elements/*/help/*"
GENERAL_HELP_GLOB = "assets/help/*"
STYLESHEET = Path("assets/help/help.css")

MARKDOWN_EXTENSIONS = ["tables", "fenced_code", "sane_lists"]

TEMPLATE = """<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta http-equiv="X-UA-Compatible" content="IE=edge">
<meta name="viewport" content="width=device-width, initial-scale=1">
<!-- Generated from {source} by tools/gen_help.py. Do not edit: change the Markdown and run the tool. -->
<title>{title}</title>
<style>
{css}</style>
</head>
<body>
<main>
{body}
</main>
</body>
</html>
"""

EXTERNAL = ("http://", "https://", "mailto:")
LINK = re.compile(r"(!?)\[([^\]]*)\]\(([^)\s]+)((?:\s+\"[^\"]*\")?)\)")


class HelpError(Exception):
    pass


def help_roots(root: Path):
    """The language folders of all help roots below `root`, sorted (deterministic output)."""
    roots = [p for p in root.glob(ELEMENT_HELP_GLOB) if p.is_dir()]
    roots += [p for p in root.glob(GENERAL_HELP_GLOB) if p.is_dir()]
    return sorted(roots)


def rewrite_links(text: str, source: Path, errors: list) -> str:
    """Links to `.md` pages become `.html`; every relative target must exist (a broken link is an error)."""
    def replace(match):
        image, label, href, title = match.group(1), match.group(2), match.group(3), match.group(4)
        if href.startswith(EXTERNAL) or href.startswith("#"):
            return match.group(0)
        path, sep, anchor = href.partition("#")
        target = (source.parent / path)
        if not target.exists():
            errors.append("%s: broken link to %s" % (_rel(source), href))
            return match.group(0)
        if image:
            return match.group(0)
        if not path.endswith(".md"):
            errors.append("%s: link to %s, a link between pages points to a .md source" % (_rel(source), href))
            return match.group(0)
        return "%s[%s](%s%s%s)%s" % (image, label, path[:-3] + ".html", sep, anchor, title)
    return LINK.sub(replace, text)


def render(source: Path, errors: list, css: str) -> str:
    """The complete HTML page of one Markdown source."""
    text = source.read_text(encoding="utf-8")
    title = None
    for line in text.splitlines():
        if line.startswith("# "):
            title = line[2:].strip()
            break
    if not title:
        errors.append("%s: no title (a line that starts with '# ')" % _rel(source))
        title = source.stem
    body = markdown.markdown(rewrite_links(text, source, errors), extensions=MARKDOWN_EXTENSIONS,
                             output_format="html")
    return TEMPLATE.format(title=html.escape(title), source=_rel(source), css=css, body=body)


def build(root: Path):
    """(expected pages, errors): the expected HTML text of every Markdown source below `root`, keyed by the path of
    the HTML file. Errors are collected, not raised, so one run reports them all."""
    errors = []
    css_path = root / STYLESHEET
    if not css_path.exists():
        raise HelpError("missing stylesheet %s" % STYLESHEET.as_posix())
    css = css_path.read_text(encoding="utf-8")
    if not css.endswith("\n"):
        css += "\n"
    expected = {}
    for folder in help_roots(root):
        for source in sorted(folder.rglob("*.md")):
            expected[source.with_suffix(".html")] = render(source, errors, css)
    return expected, errors


def superfluous(root: Path):
    """HTML files of the help roots without a Markdown source."""
    result = []
    for folder in help_roots(root):
        for page in sorted(folder.rglob("*.html")):
            if not page.with_suffix(".md").exists():
                result.append(page)
    return result


def _rel(path: Path) -> str:
    try:
        return path.relative_to(ROOT).as_posix()
    except ValueError:
        return path.as_posix()


def main(argv=None, root: Path = ROOT) -> int:
    parser = argparse.ArgumentParser(description="Generate the HTML help pages from their Markdown sources.")
    parser.add_argument("--check", action="store_true", help="write nothing; exit 1 when a page is out of date")
    args = parser.parse_args(argv)

    expected, errors = build(root)
    problems = []
    for page, text in expected.items():
        current = page.read_text(encoding="utf-8") if page.exists() else None
        if current is None:
            problems.append("missing: " + _rel(page))
        elif current != text:
            problems.append("stale: " + _rel(page))
    extra = superfluous(root)
    problems += ["superfluous: " + _rel(p) for p in extra]
    problems += errors

    if args.check:
        for line in problems:
            print(line, file=sys.stderr)
        if problems:
            print("help pages are not current: run python tools/gen_help.py", file=sys.stderr)
            return 1
        print("%d help pages are current" % len(expected))
        return 0

    if errors:
        for line in errors:
            print(line, file=sys.stderr)
        return 1
    for page, text in expected.items():
        if page.exists() and page.read_text(encoding="utf-8") == text:
            continue
        with open(page, "w", encoding="utf-8", newline="\n") as f:
            f.write(text)
        print("written: " + _rel(page))
    for page in extra:
        page.unlink()
        print("deleted: " + _rel(page))
    print("%d help pages" % len(expected))
    return 0


if __name__ == "__main__":
    sys.exit(main())
