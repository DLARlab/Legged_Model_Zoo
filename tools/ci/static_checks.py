#!/usr/bin/env python3
"""MATLAB-free release checks used locally and by GitHub Actions."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
PROMPT_PATTERN = re.compile(r"(?:Prompt|pasted-text)", re.IGNORECASE)
IGNORED_PARTS = {".git", ".idea", ".vscode", "__pycache__", "release-output"}
MANIFEST_IGNORED_PARTS = {".git", ".svn", "slprj", "codegen", ".matlab"}


class CheckFailure(RuntimeError):
    pass


def relative(path: Path) -> str:
    return path.relative_to(ROOT).as_posix()


def public_files(suffix: str | None = None):
    for path in sorted(ROOT.rglob("*")):
        if not path.is_file():
            continue
        rel = path.relative_to(ROOT)
        if any(part in IGNORED_PARTS for part in rel.parts):
            continue
        if PROMPT_PATTERN.search(path.name):
            continue
        if suffix is None or path.suffix.lower() == suffix:
            yield path


def manifest_inventory_files():
    """Mirror the MATLAB release collector for completeness checks."""
    for path in sorted(ROOT.rglob("*")):
        if not path.is_file():
            continue
        rel = path.relative_to(ROOT)
        if any(part in MANIFEST_IGNORED_PARTS for part in rel.parts):
            continue
        if len(rel.parts) >= 2 and rel.parts[0] == "release" and rel.parts[1] in {
            "out",
            "staging",
        }:
            continue
        if path.name == ".DS_Store" or path.stem.lower() == "thumbs":
            continue
        if PROMPT_PATTERN.search(path.name):
            continue
        if path.suffix.lower() in {".asv", ".autosave", ".mltbx", ".zip", ".sha256"}:
            continue
        if rel.as_posix() == "release/redistribution_manifest.json":
            continue
        yield path


def check_json() -> list[str]:
    failures: list[str] = []
    for path in public_files(".json"):
        try:
            json.loads(path.read_text(encoding="utf-8"))
        except (UnicodeDecodeError, json.JSONDecodeError) as exc:
            failures.append(f"{relative(path)}: invalid JSON ({exc})")
    return failures


def check_readme() -> list[str]:
    path = ROOT / "README.md"
    text = path.read_text(encoding="utf-8")
    headings = [
        "Project overview",
        "Features",
        "Requirements",
        "Standalone installation",
        "Launch the GUI",
        "GUI walkthrough",
        "SLIP Quadruped RoadMap Tutorial",
        "SLIP Biped GaitMap Tutorial",
        "SLIP Quadruped-with-Load Fitting Tutorial",
        "Available models",
        "Built-in examples",
        "Command-line quick start",
        "Simulating each model",
        "Loading and saving data",
        "Solving periodic solutions",
        "Numerical continuation",
        "Parameter homotopy and branch-family scans",
        "Optimization and data fitting",
        "Visualization, animation, and recording",
        "Artifact format",
        "Legacy MAT import/export",
        "Adding a new model",
        "Testing",
        "Troubleshooting",
        "Project structure",
        "License and provenance",
        "Current verified status",
    ]
    positions = [text.find(f"## {heading}") for heading in headings]
    failures: list[str] = []
    if any(position < 0 for position in positions) or positions != sorted(positions):
        failures.append("README.md: required sections are missing or out of order")
    required = [
        "legged_model_zoo",
        "registry = lmz.registry.ModelRegistry.discover()",
        "slip_biped",
        "slip_quad_load",
        "slip_quadruped",
        "<!-- LMZ:MODEL_TABLE:BEGIN -->",
        "<!-- LMZ:MODEL_TABLE:END -->",
        "<!-- LMZ:PROBLEM_TABLE:BEGIN -->",
        "<!-- LMZ:PROBLEM_TABLE:END -->",
        "REDISTRIBUTION_STATUS.md",
    ]
    for token in required:
        if token not in text:
            failures.append(f"README.md: missing required token {token!r}")
    return failures


def strip_matlab_comments(text: str) -> str:
    return "\n".join(line.split("%", 1)[0] for line in text.splitlines())


def check_architecture() -> list[str]:
    failures: list[str] = []
    generic_patterns = {
        r"\bglobal\b": "global state",
        r"\brestoredefaultpath\b": "restoredefaultpath",
        r"addpath\s*\(\s*genpath": "recursive path mutation",
        r"\beval(?:in)?\s*\(": "eval/evalin",
        r"\bassignin\s*\(": "assignin",
    }
    restricted_patterns = {
        r"\bfsolve\s*\(": "direct fsolve call",
        r"\bfmincon\s*\(": "direct fmincon call",
        r"Quadrupedal_ZeroFun|ZeroFunc_Biped|Quad_Load_ZeroFun": "legacy evaluator",
    }
    for base in (ROOT / "src", ROOT / "models"):
        if not base.exists():
            continue
        for path in sorted(base.rglob("*.m")):
            code = strip_matlab_comments(path.read_text(encoding="utf-8"))
            for pattern, label in generic_patterns.items():
                if re.search(pattern, code, re.IGNORECASE):
                    failures.append(f"{relative(path)}: forbidden {label}")
            if "+gui" in path.parts or "+services" in path.parts:
                for pattern, label in restricted_patterns.items():
                    if re.search(pattern, code, re.IGNORECASE):
                        failures.append(f"{relative(path)}: forbidden {label}")
            if (ROOT / "src") in path.parents:
                if re.search(r"PK_20_2|BD1_20_2", code):
                    failures.append(f"{relative(path)}: scientific filename in generic code")
                if re.search(r"(?:addpath|genpath)[^\n]*SLIP_Model_Zoo", code):
                    failures.append(f"{relative(path)}: source-repository path dependency")
    return failures


def check_compatibility() -> list[str]:
    failures: list[str] = []
    post_target = ("exportapp", "copygraphics", "orderedcolors", "clim", "turbo")
    routed = {
        "exportgraphics": "+compat/Graphics.m",
        "VideoWriter": "+compat/Video.m",
        "optimoptions": "+compat/Optimization.m",
    }
    for base in (ROOT / "src", ROOT / "models"):
        if not base.exists():
            continue
        for path in sorted(base.rglob("*.m")):
            rel = relative(path)
            code = strip_matlab_comments(path.read_text(encoding="utf-8"))
            for api in post_target:
                if re.search(rf"\b{api}\s*\(", code):
                    failures.append(f"{rel}: {api} is newer than the R2019b target")
            if "/+legacy/" in f"/{rel}/":
                continue
            for api, owner in routed.items():
                if re.search(rf"\b{api}\s*\(", code) and owner not in rel:
                    failures.append(f"{rel}: {api} must route through lmz.compat")
            if re.search(r"\bjson(?:en|de)code\s*\(", code) and not (
                rel.endswith("/+compat/Json.m") or rel.endswith("/+io/SafeJson.m")
            ):
                failures.append(f"{rel}: JSON operations must use a guarded helper")
            if re.search(r"\bdir\s*\([^\n\)]*['\"]\*\*", code) and not rel.endswith(
                "/+compat/Files.m"
            ):
                failures.append(f"{rel}: recursive discovery must use lmz.compat.Files")
            if re.search(r"\bmovefile\s*\(", code) and not rel.endswith(
                "/+compat/Files.m"
            ):
                failures.append(f"{rel}: final file moves must use lmz.compat.Files")
    return failures


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def check_manifest() -> list[str]:
    path = ROOT / "release" / "redistribution_manifest.json"
    if not path.exists():
        return ["release/redistribution_manifest.json: missing"]
    try:
        document = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        return [f"release/redistribution_manifest.json: invalid JSON ({exc})"]
    entries = document.get("entries", document.get("files"))
    if not isinstance(entries, list):
        return ["release/redistribution_manifest.json: entries/files must be an array"]
    required = {
        "relativePath",
        "sha256",
        "category",
        "sourceRepository",
        "sourceCommit",
        "licenseId",
        "decisionStatus",
        "redistributable",
        "requiredNotice",
        "generatedFrom",
        "profiles",
        "releaseRoles",
    }
    failures: list[str] = []
    seen: set[str] = set()
    for index, entry in enumerate(entries):
        if not isinstance(entry, dict):
            failures.append(f"manifest entry {index}: expected object")
            continue
        missing = sorted(required - entry.keys())
        if missing:
            failures.append(f"manifest entry {index}: missing {', '.join(missing)}")
            continue
        rel = entry["relativePath"]
        if not isinstance(rel, str) or Path(rel).is_absolute() or ".." in Path(rel).parts:
            failures.append(f"manifest entry {index}: unsafe relativePath")
            continue
        if rel in seen:
            failures.append(f"manifest: duplicate path {rel}")
            continue
        seen.add(rel)
        target = ROOT / rel
        if not target.is_file():
            failures.append(f"manifest: missing listed file {rel}")
        elif sha256(target).lower() != str(entry["sha256"]).lower():
            failures.append(f"manifest: stale SHA-256 for {rel}")
    current = {relative(candidate) for candidate in manifest_inventory_files()}
    for rel in sorted(current - seen):
        failures.append(f"manifest: unlisted file {rel}")
    return failures


def check_whitespace() -> list[str]:
    failures: list[str] = []
    text_suffixes = {".m", ".md", ".json", ".yml", ".yaml", ".py", ".txt", ".in"}
    for path in public_files():
        if "+legacy" in path.parts:
            # Imported oracles retain source formatting; patch whitespace is
            # still checked by Git for any newly edited lines.
            continue
        if path.suffix.lower() not in text_suffixes and path.name not in {"VERSION", ".gitattributes", ".gitignore"}:
            continue
        try:
            lines = path.read_text(encoding="utf-8").splitlines()
        except UnicodeDecodeError:
            continue
        for number, line in enumerate(lines, 1):
            if line.rstrip(" \t") != line:
                failures.append(f"{relative(path)}:{number}: trailing whitespace")
    return failures


CHECKS = {
    "json": check_json,
    "readme": check_readme,
    "architecture": check_architecture,
    "compatibility": check_compatibility,
    "manifest": check_manifest,
    "whitespace": check_whitespace,
}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("checks", nargs="*", choices=sorted(CHECKS))
    parser.add_argument("--all", action="store_true", help="run every check")
    args = parser.parse_args()
    selected = list(CHECKS) if args.all or not args.checks else args.checks
    failures: list[str] = []
    for name in selected:
        current = CHECKS[name]()
        status = "PASS" if not current else "FAIL"
        print(f"LMZ_STATIC_{status} check={name} findings={len(current)}")
        failures.extend(current)
    if failures:
        print("\n".join(failures), file=sys.stderr)
        return 1
    print(f"LMZ_STATIC_CHECKS_OK checks={len(selected)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
