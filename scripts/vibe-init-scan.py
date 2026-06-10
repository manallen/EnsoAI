#!/usr/bin/env python3

from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path

EXCLUDE_DIRS = {'.git', 'node_modules', 'dist', 'build', '.next', '.turbo', '.venv'}
SOURCE_CANDIDATES = {'src', 'app', 'packages', 'apps', 'services', 'backend', 'frontend', 'server', 'web', 'scripts'}
INTERESTING_FILES = {
    'package.json', 'pyproject.toml', 'go.mod', 'Cargo.toml', 'Makefile', 'makefile',
    'pnpm-workspace.yaml', 'turbo.json', '.cursorrules', 'AGENTS.md', 'CLAUDE.md'
}
META_FILES = [
    '.vibe/manifest.json',
    '.vibe/STATE.md',
    '.vibe/init-report.md',
    '.vibe/memory/MEMORY-INDEX.md',
    '.vibe/.source',
    '.vibe/.install-mode',
    '.vibe/.release',
    '.vibe/.channel',
    '.claude/settings.json',
]
TEMPLATE_FILES = [
    '.vibe/config/init-report-template.md',
    '.vibe/config/design-index-template.md',
    '.vibe/config/ui-anti-patterns-template.md',
]


def safe_read(path: Path, *, limit: int = 4000) -> str:
    if not path.exists() or not path.is_file():
        return ''
    try:
        text = path.read_text(encoding='utf-8', errors='ignore')
    except Exception:
        return ''
    return text[:limit]


def read_meta(root: Path) -> dict[str, str]:
    result: dict[str, str] = {}
    for rel in META_FILES + TEMPLATE_FILES:
        path = root / rel
        result[rel] = safe_read(path)
    return result


def shallow_tree(root: Path) -> dict[str, list[str]]:
    levels = {'root': [], 'depth1': [], 'depth2': []}
    try:
        entries = sorted(root.iterdir(), key=lambda x: x.name)
    except Exception:
        return levels

    for p in entries:
        if p.name in EXCLUDE_DIRS:
            continue
        levels['root'].append(f"{p.name}/" if p.is_dir() else p.name)
        if not p.is_dir():
            continue
        try:
            children = sorted(p.iterdir(), key=lambda x: x.name)
        except Exception:
            continue
        for c in children:
            if c.name in EXCLUDE_DIRS:
                continue
            rel1 = c.relative_to(root).as_posix()
            levels['depth1'].append(rel1 + ('/' if c.is_dir() else ''))
            if not c.is_dir():
                continue
            try:
                grands = sorted(c.iterdir(), key=lambda x: x.name)
            except Exception:
                continue
            for g in grands:
                if g.name in EXCLUDE_DIRS:
                    continue
                rel2 = g.relative_to(root).as_posix()
                levels['depth2'].append(rel2 + ('/' if g.is_dir() else ''))
    return levels


def project_facts(root: Path) -> dict[str, object]:
    found = []
    for rel in INTERESTING_FILES:
        p = root / rel
        if p.exists():
            found.append(rel)
    github = root / '.github' / 'workflows'
    if github.exists():
        found.append('.github/workflows/')

    ext_counts: dict[str, int] = {}
    source_hits: dict[str, list[str]] = {}
    for name in SOURCE_CANDIDATES:
        p = root / name
        if not p.exists() or not p.is_dir():
            continue
        hits: list[str] = []
        for cur, dirs, files in os.walk(p):
            rel = Path(cur).relative_to(root)
            depth = len(rel.parts)
            dirs[:] = [d for d in dirs if d not in EXCLUDE_DIRS and depth < 3]
            if depth > 3:
                continue
            for f in files:
                rp = (Path(cur) / f).relative_to(root)
                hits.append(rp.as_posix())
                suf = rp.suffix.lower() or '[no_ext]'
                ext_counts[suf] = ext_counts.get(suf, 0) + 1
        source_hits[name] = hits[:30]

    return {
        'interesting_files': sorted(found),
        'source_hits': source_hits,
        'ext_counts': dict(sorted(ext_counts.items(), key=lambda kv: (-kv[1], kv[0]))[:20]),
    }


def git_info(root: Path) -> dict[str, object]:
    info = {'branch': '', 'remote': '', 'recent_commits': []}
    commands = {
        'branch': ['git', '-C', str(root), 'branch', '--show-current'],
        'remote': ['git', '-C', str(root), 'remote', 'get-url', 'origin'],
        'recent_commits': ['git', '-C', str(root), 'log', '-5', '--pretty=format:%h%x09%s'],
    }
    for key, cmd in commands.items():
        try:
            out = subprocess.check_output(cmd, text=True, stderr=subprocess.DEVNULL).strip()
        except Exception:
            out = ''
        if key == 'recent_commits':
            info[key] = out.splitlines() if out else []
        else:
            info[key] = out
    return info


def main() -> int:
    root = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else Path.cwd().resolve()
    payload = {
        'root': str(root),
        'tree': shallow_tree(root),
        'git': git_info(root),
        'meta': read_meta(root),
        'project': project_facts(root),
    }
    print(json.dumps(payload, ensure_ascii=False))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
