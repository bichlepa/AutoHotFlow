"""One-time conversion of the v1 help pages to Markdown (WI-0112, E0100).

Reads the 149 element pages of v1 (`v1/Source_Elements/Default/help/en/<Kind>/*.html`) and the general pages of the
v1 help (`Welcome`, `Variables`, `Key list`, `Color chart`), and writes the Markdown sources:

  element pages  ->  src/elements/Default/help/en/<Kind>/<Name>.md
                     <Name> is the name of the v1 element file (`v1/Source_Elements/Default/<Kind>/<Name>.ahk`), which
                     is the class name without its kind prefix; the v1 help file name is only a case variant of it.
  general pages  ->  assets/help/en/<Name>.md  (`Key list` becomes `Key_list`)

The general pages are not in the repository: the v1 help folder `v1/Help/en/` is ignored by git. Pass the folder of a
working copy that has them (the main checkout of the project owner):

  python tools/convert_v1_help.py --general "C:/.../AutoHotFlow/v1/Help/en"

The tool is meant for one run (the conversion of v1 to v2 sources). It overwrites its output. The result is reviewed
by hand afterwards: the 29 core pages are corrected for v2 (E0097), the others stay as converted until their element
is ported (S0008). Known limits: `<iframe>` (the key list) becomes a link, `<br/>` a new paragraph, the layout tables
(`settings`, `variables`, `examples`) become headings and paragraphs, and the examples become pipe tables.
"""

import argparse
import html.parser
import os
import re
import sys
import textwrap
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
V1_HELP = ROOT / "v1" / "Source_Elements" / "Default" / "help" / "en"
V1_ELEMENTS = ROOT / "v1" / "Source_Elements" / "Default"
ELEMENT_OUT = ROOT / "src" / "elements" / "Default" / "help" / "en"
GENERAL_OUT = ROOT / "assets" / "help" / "en"
KINDS = ("Actions", "Conditions", "Loops", "Triggers")

# v1 help file name (lower case) -> v1 element file name (lower case) where they differ in more than the case.
ALIASES = {"number is": "numberis"}

# v1 general page -> name of the Markdown file.
GENERAL_PAGES = {"Welcome": "Welcome", "Variables": "Variables", "Key list": "Key_list", "Color chart": "Color_chart"}

VOID = {"br", "meta", "link", "img", "hr", "input"}
BLOCK_TAGS = {"p", "table", "ul", "ol", "div", "h1", "h2", "h3", "h4", "h5", "h6", "iframe"}


class Node:
    def __init__(self, tag, attrs, parent=None):
        self.tag = tag
        self.attrs = dict(attrs)
        self.children = []
        self.parent = parent

    @property
    def classes(self):
        return (self.attrs.get("class") or "").split()


class DomBuilder(html.parser.HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.root = Node("root", [])
        self.stack = [self.root]

    @staticmethod
    def name(tag):
        # malformed tags like `<p"` carry junk after the name
        return re.sub(r"[^a-z0-9].*$", "", tag.lower())

    def handle_starttag(self, tag, attrs):
        node = Node(self.name(tag), attrs, self.stack[-1])
        self.stack[-1].children.append(node)
        if node.tag not in VOID:
            self.stack.append(node)

    def handle_startendtag(self, tag, attrs):
        self.stack[-1].children.append(Node(self.name(tag), attrs, self.stack[-1]))

    def handle_endtag(self, tag):
        tag = self.name(tag)
        for i in range(len(self.stack) - 1, 0, -1):
            if self.stack[i].tag == tag:
                del self.stack[i:]
                return

    def handle_data(self, data):
        self.stack[-1].children.append(data)


def parse(text):
    builder = DomBuilder()
    builder.feed(text)
    builder.close()
    return builder.root


class Converter:
    """Renders a DOM of a v1 page to Markdown. `links` maps a v1 help path (lower case, relative to the help root)
    to the Markdown target path (relative to the output folder of the page)."""

    def __init__(self, links_for, unresolved):
        self.links_for = links_for  # function(href, page_v1_dir) -> target path or None
        self.unresolved = unresolved
        self.page_dir = ""

    # ----- inline -----

    @staticmethod
    def escape(text):
        text = text.replace("\\", "\\\\").replace("*", "\\*").replace("`", "\\`")
        text = text.replace("[", "\\[").replace("]", "\\]")
        text = re.sub(r"<(?=[A-Za-z/!?])", "&lt;", text)
        return text

    def inline(self, node):
        out = []
        for child in node.children:
            if isinstance(child, str):
                out.append(self.escape(re.sub(r"\s+", " ", child)))
            elif child.tag == "br":
                out.append("\n\n")
            elif child.tag in ("b", "strong"):
                out.append("**" + self.inline(child).strip() + "**")
            elif child.tag in ("i", "em"):
                out.append("*" + self.inline(child).strip() + "*")
            elif child.tag == "code":
                text = "".join(self.text_of(child)).strip()
                out.append("`" + text + "`")
            elif child.tag == "a":
                text = self.inline(child).strip()
                href = child.attrs.get("href")
                # an anchor without a link (v1 uses it as a bold caption) is plain text
                out.append(text if href is None else "[" + text + "](" + self.target(href) + ")")
            elif child.tag in ("span", "font"):
                out.append(self.inline(child))
            else:
                out.append(self.inline(child))
        return "".join(out)

    def text_of(self, node):
        for child in node.children:
            if isinstance(child, str):
                yield child
            else:
                yield from self.text_of(child)

    def target(self, href):
        if href.startswith(("http://", "https://", "mailto:")):
            return href
        if href.startswith("#"):
            return href
        resolved = self.links_for(href, self.page_dir)
        if resolved is None:
            self.unresolved.append(href)
            return href
        return resolved

    # ----- blocks -----

    def blocks(self, node):
        """Markdown blocks of the children of `node` (a list of strings)."""
        result = []
        buffer = []

        def flush():
            text = "".join(buffer)
            buffer.clear()
            for part in re.split(r"\n\n", text):
                part = part.strip()
                if part:
                    result.append(part)

        for child in node.children:
            if isinstance(child, str):
                buffer.append(self.escape(re.sub(r"\s+", " ", child)))
                continue
            tag = child.tag
            if tag in ("b", "strong", "i", "em", "code", "a", "br", "span", "font"):
                buffer.append(self.inline(child))
                continue
            flush()
            result.extend(self.block(child))
        flush()
        return result

    def block(self, node):
        tag = node.tag
        if tag in ("h1", "h2", "h3", "h4", "h5", "h6"):
            level = int(tag[1])
            if "VariableName" in node.classes:
                text = "`" + "".join(self.text_of(node)).strip() + "`"
            else:
                text = self.inline(node).strip()
            hashes = "#" * (level if tag != "h4" else 3)
            return [hashes + " " + text]
        if tag == "p":
            # v1 often leaves a `<p>` open around a table (the code block of the ini remarks)
            if any(not isinstance(c, str) and c.tag in BLOCK_TAGS for c in node.children):
                return self.blocks(node)
            text = self.inline(node).strip()
            if not text:
                return []
            if "warning" in node.classes:
                return ["> **Warning:** " + text.replace("\n\n", "\n>\n> ")]
            if "info" in node.classes:
                return ["> **Note:** " + text.replace("\n\n", "\n>\n> ")]
            return [text]
        if tag == "iframe":
            # the key list is embedded in v1; v2 links to its page
            src = node.attrs.get("src", "")
            link = self.target(src)
            return ["The available keys are listed in the [key list](" + link + ")."]
        if tag in ("ul", "ol"):
            return [self.list_block(node)]
        if tag == "table":
            return self.table(node)
        if tag in ("tr", "td", "div", "body", "html", "head", "tbody", "thead", "center"):
            return self.blocks(node)
        if tag in ("title", "meta", "link", "style", "script"):
            return []
        return self.blocks(node)

    def list_block(self, node):
        """A list. v1 writes `<ul class="examples"><p><i>Examples:</i></p><li/><p>...</p>`: the `<p>` children are
        the items, the `<li/>` are empty, and the first paragraph is the caption of the list."""
        caption, items = [], []
        for child in node.children:
            if isinstance(child, str) or child.tag == "li" and not child.children:
                continue
            text = self.inline(child).strip()
            if not text:
                continue
            if re.fullmatch(r"\*?Examples:?\*?", text):
                caption.append("*Examples:*")
            else:
                items.append("- " + text)
        # Markdown needs an empty line before a list
        return "\n\n".join(caption + (["\n".join(items)] if items else []))

    def table(self, node):
        classes = node.classes
        if "settings" in classes or "variables" in classes or "examples" in classes:
            result = []
            for row in node.children:
                if isinstance(row, str) or row.tag != "tr":
                    continue
                for cell in row.children:
                    if isinstance(cell, str) or cell.tag != "td":
                        continue
                    result.extend(self.blocks(cell))
            return result
        if "example" in classes:
            return [self.example_table(node)]
        if "codeblock" in classes:
            text = textwrap.dedent("".join(self.text_of(node))).strip("\n")
            return ["```\n" + text + "\n```"]
        return [self.generic_table(node)]

    def example_table(self, node):
        rows = []
        for row in node.children:
            if isinstance(row, str) or row.tag != "tr":
                continue
            cells = [c for c in row.children if not isinstance(c, str) and c.tag == "td"]
            if len(cells) != 2:
                continue
            name = "".join(self.text_of(cells[0])).strip()
            value = "".join(self.text_of(cells[1])).strip()
            value = " ".join(value.split())
            value = value.replace("|", "\\|")
            rows.append("| " + self.escape(name) + " | `" + value.replace("`", "'") + "` |")
        if not rows:
            return ""
        return "| Parameter | Value |\n| --- | --- |\n" + "\n".join(rows)

    def generic_table(self, node):
        """A table without a v1 class: the first row is the header."""
        rows = []
        for row in node.children:
            if isinstance(row, str) or row.tag != "tr":
                continue
            cells = [" ".join(self.inline(c).split()).replace("|", "\\|")
                     for c in row.children if not isinstance(c, str) and c.tag in ("td", "th")]
            if cells:
                rows.append(cells)
        if not rows:
            return ""
        width = len(rows[0])
        lines = ["| " + " | ".join(rows[0]) + " |", "| " + " | ".join(["---"] * width) + " |"]
        lines += ["| " + " | ".join(r + [""] * (width - len(r))) + " |" for r in rows[1:]]
        return "\n".join(lines)

    def page(self, root, title_fallback):
        """The Markdown of a page. The title is the h1 of the body; a page without one gets the file name."""
        body = next((n for n in self.walk(root) if n.tag == "body"), root)
        blocks = [b for b in self.blocks(body) if b]
        if not blocks or not blocks[0].startswith("# "):
            blocks.insert(0, "# " + title_fallback)
        md = "\n\n".join(blocks) + "\n"
        md = "\n".join(line.rstrip() for line in md.split("\n"))
        return re.sub(r"\n{3,}", "\n\n", md)

    def walk(self, node):
        for child in node.children:
            if isinstance(child, str):
                continue
            yield child
            yield from self.walk(child)


def relpath(target: Path, start: Path) -> str:
    return Path(os.path.relpath(target, start)).as_posix()


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--general", required=True, help="folder with the general v1 pages (v1/Help/en of a working copy)")
    parser.add_argument("--dry-run", action="store_true", help="convert, print the summary, write nothing")
    args = parser.parse_args(argv)

    general_dir = Path(args.general)
    # 1. the targets of all pages (needed for the links)
    element_targets = {}  # (kind folder, lower name of the v1 html) -> Path of the Markdown file
    plan = []  # (source html, target md, kind)
    for kind in KINDS:
        folder = V1_HELP / kind
        ahk_names = {}
        for ahk in (V1_ELEMENTS / kind).glob("*.ahk"):
            ahk_names[ahk.stem.lower()] = ahk.stem
        for html_file in sorted(folder.glob("*.html")):
            stem = html_file.stem.lower()
            lookup = ALIASES.get(stem, stem)
            name = ahk_names.get(lookup)
            if name is None:
                print("no element file for", html_file, file=sys.stderr)
                name = html_file.stem
            target = ELEMENT_OUT / kind / (name + ".md")
            element_targets[(kind.lower(), html_file.stem.lower())] = target
            plan.append((html_file, target, kind))
    general_plan = []
    for v1_name, md_name in GENERAL_PAGES.items():
        src = general_dir / (v1_name + ".html")
        general_plan.append((src, GENERAL_OUT / (md_name + ".md")))
        element_targets[("general", v1_name.lower().replace(" ", ""))] = GENERAL_OUT / (md_name + ".md")

    def links_for(href, page_dir):
        """Target path for a link of a page. `page_dir` is the output folder of the page."""
        base, _, anchor = href.partition("#")
        if base.startswith(("http:", "https:")):
            return href
        name = Path(base).name
        if not name.lower().endswith(".html"):
            return None
        stem = name[:-5].lower()
        kind = Path(base).parent.name.lower()
        target = None
        if stem.replace(" ", "") in ("variables", "welcome", "keylist", "colorchart"):
            target = element_targets.get(("general", stem.replace(" ", "")))
        if target is None:
            for k in KINDS:
                if k.lower() == kind and (k.lower(), stem) in element_targets:
                    target = element_targets[(k.lower(), stem)]
                    break
        if target is None:
            return None
        rel = relpath(target, page_dir)
        return rel + ("#" + anchor if anchor else "")

    # 2. convert
    unresolved = []
    converted = []
    for src, target, kind in plan:
        text = src.read_text(encoding="utf-8")
        conv = Converter(lambda href, _d, out=target: links_for(href, out.parent.as_posix()), unresolved)
        conv.page_dir = target.parent.as_posix()
        md = conv.page(parse(text), src.stem)
        converted.append((target, md))
    for src, target in general_plan:
        text = src.read_text(encoding="utf-8")
        conv = Converter(lambda href, _d, out=target: links_for(href, out.parent.as_posix()), unresolved)
        conv.page_dir = target.parent.as_posix()
        md = conv.page(parse(text), src.stem)
        converted.append((target, md))

    for target, md in converted:
        print(target.relative_to(ROOT).as_posix() if target.is_relative_to(ROOT) else target)
        if not args.dry_run:
            target.parent.mkdir(parents=True, exist_ok=True)
            with open(target, "w", encoding="utf-8", newline="\n") as f:
                f.write(md)
    print(f"{len(converted)} pages", "(dry run)" if args.dry_run else "written")
    if unresolved:
        print("unresolved links:", sorted(set(unresolved)), file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
