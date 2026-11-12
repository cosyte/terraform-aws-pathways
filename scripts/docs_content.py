#!/usr/bin/env python3
"""Writes the generated parts of docs-content/ from the code, and checks the rest is in place.

    python3 scripts/docs_content.py

Run through scripts/docs.sh, which needs terraform-docs on PATH and fails when this changed a file,
so a page that no longer matches the code fails CI. What it writes:

  * docs-content/inputs-and-outputs.md: every input and output of the root module, read by
    terraform-docs from variables.tf and outputs.tf;
  * docs-content/module-<name>.md: the same for each submodule under modules/;
  * the "## Files" section of each docs-content/example-<name>.md: every file of examples/<name>.

What it refuses, with exit 1:

  * a folder under examples/ with no page docs-content/example-<name>.md, a page with no folder, or
    a page without its "## What it deploys", "## What it costs to leave running" and "## Files"
    headings;
  * a generated or example page that docs-content/sidebars.json does not list.

Descriptions are written with the characters MDX reads as code (braces and angle brackets) escaped,
since the docs site compiles every page as MDX; types and defaults go in code, which MDX leaves be.
"""

from __future__ import annotations

import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DOCS = ROOT / "docs-content"
EXAMPLES = ROOT / "examples"
MODULES = ROOT / "modules"

FILES_HEADING = "## Files"
EXAMPLE_HEADINGS = ("## What it deploys", "## What it costs to leave running", FILES_HEADING)
SKIP_NAMES = {".terraform", ".terraform.lock.hcl"}
LANGUAGES = {".tf": "hcl", ".yaml": "yaml", ".yml": "yaml", ".ts": "ts", ".md": "md", ".json": "json"}

# What a submodule page says the submodule is for, in the order the sidebar lists them.
SUBMODULES = {
    "kms": "the customer managed key, rotated yearly",
    "logs": "the engine's and the migrate task's log groups",
    "security_groups": "who may reach the load balancers, the engine and the database",
    "database": "PostgreSQL on RDS and the secret holding its URL",
    "iam": "the task execution role and the task role",
    "load_balancers": "the network load balancer for MLLP and the application load balancer for HTTP",
    "ecs": "the cluster, the engine and migrate task definitions, and the service",
    "bucket": "the optional S3 bucket, its access log bucket and the task role's access",
    "sftp": "the optional Transfer Family SFTP server, its users and its logs",
    "alarms": "the optional alarms on the engine's metrics, the health token and the collector's configuration",
}

problems: list[str] = []


def problem(message: str) -> None:
    problems.append(message)


def terraform_docs(directory: Path) -> dict:
    """The inputs and outputs of one module, as terraform-docs reads them, in file order."""
    result = subprocess.run(
        ["terraform-docs", "json", "--sort=false", "--show", "inputs,outputs", str(directory)],
        check=True,
        capture_output=True,
        text=True,
    )
    return json.loads(result.stdout)


def escape(text: str) -> str:
    """Prose for an MDX page: the characters MDX would read as code, escaped."""
    return re.sub(r"([\\{}<>*])", r"\\\1", text.strip())


def code(value: str) -> str:
    """A value in code: inline when it is one short line, else a fenced block."""
    if "\n" not in value and len(value) <= 80:
        return f" `{value}`"
    return f"\n\n```hcl\n{value}\n```"


def render_default(default: object) -> str:
    text = json.dumps(default, indent=2)
    if "\n" not in text and len(text) <= 80:
        return f" `{text}`"
    return f"\n\n```json\n{text}\n```"


def render_module(directory: Path) -> str:
    """The inputs and outputs of one module as Markdown, under level two and three headings."""
    data = terraform_docs(directory)
    inputs = data.get("inputs") or []
    outputs = data.get("outputs") or []
    lines: list[str] = []
    for title, required in (("Required inputs", True), ("Optional inputs", False)):
        chosen = [i for i in inputs if bool(i.get("required")) is required]
        lines += [f"## {title}", ""]
        if not chosen:
            lines += ["None.", ""]
        for item in chosen:
            lines += [f"### {item['name']}", ""]
            lines += [escape(item.get("description") or "No description."), ""]
            lines += [f"Type:{code(str(item.get('type') or 'any'))}", ""]
            if required:
                lines += ["Required: it has no default.", ""]
            else:
                lines += [f"Default:{render_default(item.get('default'))}", ""]
    lines += ["## Outputs", ""]
    if not outputs:
        lines += ["None.", ""]
    for item in outputs:
        lines += [f"### {item['name']}", ""]
        lines += [escape(item.get("description") or "No description."), ""]
        if item.get("sensitive"):
            lines += ["Sensitive: Terraform hides its value in the plan and the output.", ""]
    return "\n".join(lines).rstrip("\n") + "\n"


def front_matter(page_id: str, title: str, label: str, description: str) -> str:
    if len(description) > 160:
        raise SystemExit(f"docs_content.py: {page_id}: description over 160 characters")
    return (
        f"---\nid: {page_id}\ntitle: {title}\nsidebar_label: {label}\n"
        f'description: "{description}"\n---\n\n'
    )


GENERATED_NOTE = (
    "This page is generated from the code by `scripts/docs.sh`, and CI fails when it no longer "
    "matches, so it lists every input and output there is. Edit the descriptions in the `.tf` files, "
    "never here."
)


def write(path: Path, text: str) -> None:
    if not path.exists() or path.read_text(encoding="utf-8") != text:
        path.write_text(text, encoding="utf-8")
        print(f"docs_content.py: wrote {path.relative_to(ROOT)}")


def root_page() -> None:
    text = front_matter(
        "inputs-and-outputs",
        "Inputs and outputs",
        "Inputs and outputs",
        "Every input and output of the root module, with its type, its default and what it does, "
        "generated from variables.tf and outputs.tf.",
    )
    text += "# Inputs and outputs\n\n"
    text += (
        "The root module's inputs, from `variables.tf`, and its outputs, from `outputs.tf`. Defaults "
        "are shown as JSON. The submodules each have a page of their own, for a caller who uses one "
        "on its own.\n\n"
    )
    text += GENERATED_NOTE + "\n\n"
    text += render_module(ROOT)
    write(DOCS / "inputs-and-outputs.md", text)


def module_pages() -> list[str]:
    ids = []
    found = sorted(p.name for p in MODULES.iterdir() if p.is_dir())
    for name in found:
        if name not in SUBMODULES:
            problem(f"modules/{name} has no summary in SUBMODULES in scripts/docs_content.py")
    for name in SUBMODULES:
        if name not in found:
            problem(f"SUBMODULES in scripts/docs_content.py names modules/{name}, which does not exist")
            continue
        page_id = "module-" + name.replace("_", "-")
        ids.append(page_id)
        text = front_matter(
            page_id,
            f"The {name} submodule",
            name,
            f"Every input and output of modules/{name}, generated from its code.",
        )
        text += f"# The {name} submodule\n\n"
        text += (
            f"`modules/{name}` holds {SUBMODULES[name]}. The root module calls it; to use it on its "
            f'own, set `source = "github.com/cosyte/terraform-aws-pathways//modules/{name}"`.\n\n'
        )
        text += GENERATED_NOTE + "\n\n"
        text += render_module(MODULES / name)
        write(DOCS / f"{page_id}.md", text)
    for stale in DOCS.glob("module-*.md"):
        if stale.stem not in ids:
            stale.unlink()
            print(f"docs_content.py: removed {stale.relative_to(ROOT)}, whose submodule is gone")
    return ids


def example_files(directory: Path) -> list[Path]:
    files = []
    for path in sorted(directory.rglob("*")):
        relative = path.relative_to(directory)
        if any(part in SKIP_NAMES for part in relative.parts):
            continue
        if path.is_file() and not path.name.endswith((".tfstate", ".tfplan")) and ".tfstate." not in path.name:
            files.append(path)
    # The README first, then the rest in path order.
    return sorted(files, key=lambda p: (p.relative_to(directory) != Path("README.md"), str(p.relative_to(directory))))


def fence_for(content: str) -> str:
    longest = max((len(run) for run in re.findall(r"`+", content)), default=0)
    return "`" * max(3, longest + 1)


def files_section(name: str) -> str:
    directory = EXAMPLES / name
    lines = [
        FILES_HEADING,
        "",
        f"Every file of `examples/{name}`, as this release holds it. This section is generated by "
        "`scripts/docs.sh`, and CI fails when it no longer matches the folder.",
        "",
    ]
    for path in example_files(directory):
        relative = path.relative_to(ROOT).as_posix()
        content = path.read_text(encoding="utf-8").rstrip("\n")
        fence = fence_for(content)
        language = LANGUAGES.get(path.suffix, "text")
        lines += [f"### {path.relative_to(directory).as_posix()}", ""]
        lines += [f'{fence}{language} title="{relative}"', content, fence, ""]
    return "\n".join(lines).rstrip("\n") + "\n"


def example_pages() -> list[str]:
    ids = []
    names = sorted(p.name for p in EXAMPLES.iterdir() if p.is_dir())
    for name in names:
        page_id = f"example-{name}"
        page = DOCS / f"{page_id}.md"
        if not page.exists():
            problem(
                f"examples/{name} has no page: write docs-content/{page_id}.md with the headings "
                f"{', '.join(EXAMPLE_HEADINGS)} (the last is generated), and list it in sidebars.json"
            )
            continue
        ids.append(page_id)
        text = page.read_text(encoding="utf-8")
        for heading in EXAMPLE_HEADINGS:
            if not re.search(rf"^{re.escape(heading)}$", text, re.MULTILINE):
                problem(f"docs-content/{page_id}.md has no '{heading}' heading")
        if FILES_HEADING + "\n" not in text:
            continue
        written = text[: text.index(FILES_HEADING + "\n")].rstrip("\n") + "\n\n"
        write(page, written + files_section(name))
    for page in DOCS.glob("example-*.md"):
        if page.stem not in ids and not (EXAMPLES / page.stem[len("example-") :]).is_dir():
            problem(f"docs-content/{page.name} has no folder examples/{page.stem[len('example-'):]}")
    return ids


def sidebar_ids(node: object) -> list[str]:
    if isinstance(node, str):
        return [node]
    if isinstance(node, list):
        return [i for item in node for i in sidebar_ids(item)]
    if isinstance(node, dict):
        return sidebar_ids(node.get("items", []))
    return []


def main() -> int:
    if not DOCS.is_dir():
        print("docs_content.py: no docs-content/ folder", file=sys.stderr)
        return 2
    root_page()
    listed_needed = ["inputs-and-outputs", *module_pages(), *example_pages()]
    sidebars = json.loads((DOCS / "sidebars.json").read_text(encoding="utf-8"))
    listed = set(sidebar_ids(sidebars.get("docs", [])))
    for page_id in listed_needed:
        if page_id not in listed:
            problem(f"docs-content/sidebars.json does not list {page_id}")
    for message in problems:
        print(f"docs_content.py: {message}", file=sys.stderr)
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
