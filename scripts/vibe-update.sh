#!/bin/bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

TARGET_ARG="."
EXPLICIT_SOURCE=""
INSTALL_EXTRA_ARGS=()
POSITIONAL_COUNT=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --changed-only|--dev-link)
            INSTALL_EXTRA_ARGS+=("$1")
            shift
            ;;
        *)
            if [[ "$POSITIONAL_COUNT" -eq 0 ]]; then
                TARGET_ARG="$1"
            elif [[ "$POSITIONAL_COUNT" -eq 1 ]]; then
                EXPLICIT_SOURCE="$1"
            else
                echo "ERROR: 不支持的额外参数: $1" >&2
                exit 1
            fi
            POSITIONAL_COUNT=$((POSITIONAL_COUNT + 1))
            shift
            ;;
    esac
done

TARGET_DIR="$(cd "$TARGET_ARG" && pwd)"
VIBE_DIR="$TARGET_DIR/.vibe"
CLAUDE_COMMANDS_DIR="$TARGET_DIR/.claude/commands/vibe"
CLAUDE_AGENTS_DIR="$TARGET_DIR/.claude/agents"
INSTALL_MODE_FILE="$VIBE_DIR/.install-mode"

IS_AUTHORING_REPO=0
if [[ -f "$REPO_ROOT/install.sh" && -d "$REPO_ROOT/commands/vibe" && -d "$REPO_ROOT/agents" && -d "$REPO_ROOT/config" ]]; then
    IS_AUTHORING_REPO=1
fi

DEFAULT_SOURCE=""
if [[ "$IS_AUTHORING_REPO" -eq 1 ]]; then
    DEFAULT_SOURCE="$(git -C "$REPO_ROOT" remote get-url origin 2>/dev/null || true)"
fi

BACKUP_ITEMS=(
    "STATE.md"
    "manifest.json"
    "project-profile.md"
    "init-report.md"
    ".source"
    "context"
    "history"
    "memory"
    "design"
    "needs"
)

RESTORE_FILES=(
    "STATE.md"
    "manifest.json"
    "project-profile.md"
)

RESTORE_DIRS=(
    "context"
    "history"
    "memory"
    "design"
    "needs"
)

BACKUP_DIR=""
KEPT_BACKUP=""
INSTALL_LOG=""
REPORT_FILE=""
TEMP_SOURCE_DIR=""
SOURCE_DIR=""
SOURCE_KIND=""
RESOLVED_SOURCE=""
SOURCE_RELEASE=""
SOURCE_CHANNEL=""
INSTALL_CLAUDE_UPDATED="no"
INSTALL_CODEX_UPDATED="no"
PATHS_NORMALIZED=()
PRESERVED_ITEMS=()
RESTORED_ITEMS=()
REMOVED_BACKUPS=()
REPAIRED_ITEMS=()
LOCAL_BACKUP_FILES=()
MISSING_TEMPLATES=()
CHANGELOG_LINES=()
POST_BACKUP_STARTED=0
INSTALL_MODE="--both"
VERIFY_OUTPUT=""
VERIFY_EXIT_CODE=0
VERIFY_OK="unknown"
VERIFY_INSTALL_MODE=""
VERIFY_INIT_STATUS=""
VERIFY_CURRENT_RELEASE=""
VERIFY_LATEST_RELEASE=""
VERIFY_CURRENT_CHANNEL=""
VERIFY_LATEST_CHANNEL=""
VERIFY_LOCAL_BACKUPS=""
VERIFY_MIGRATION_CONFLICTS=""
VERIFY_WARNINGS=""
VERIFY_NEXT_ACTION=""
LOG_MODE="${VIBE_LOG_MODE:-human}"

init_report_is_complete() {
    local report_file="$1"
    [[ -f "$report_file" ]] && grep -q '^<!-- vibe-init-report: complete -->' "$report_file"
}

render_init_report_skeleton() {
    local template_file="$1"
    local report_file="$2"
    local prepared_by="$3"
    local timestamp platform vibe_version install_mode_value release_value channel_value

    timestamp="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    if [[ "$INSTALL_MODE" == "--codex-only" ]]; then
        platform="codex"
    elif [[ "$INSTALL_MODE" == "--claude-only" ]]; then
        platform="claude-code"
    else
        platform="shared-runtime"
    fi
    vibe_version="${SOURCE_RELEASE:-$EXPECTED_RELEASE}"
    install_mode_value="$(cat "$VIBE_DIR/.install-mode" 2>/dev/null || printf '%s' "$INSTALL_MODE")"
    release_value="$(cat "$VIBE_DIR/.release" 2>/dev/null || printf '%s' "${SOURCE_RELEASE:-unknown}")"
    channel_value="$(cat "$VIBE_DIR/.channel" 2>/dev/null || printf '%s' "${SOURCE_CHANNEL:-unknown}")"

    python3 - "$template_file" "$report_file" "$prepared_by" "$timestamp" "$platform" "$vibe_version" "$install_mode_value" "$release_value" "$channel_value" <<'PY'
from pathlib import Path
import sys

template_path = Path(sys.argv[1])
report_path = Path(sys.argv[2])
prepared_by, timestamp, platform, vibe_version, install_mode, release_value, channel_value = sys.argv[3:10]
if template_path.exists():
    text = template_path.read_text(encoding='utf-8')
else:
    text = """<!-- vibe-init-report: __STATUS__ -->\n# Vibe Init Report\n\n- Status: `__STATUS__`\n- Prepared by: `__PREPARED_BY__`\n- Prepared at: `__TIMESTAMP__`\n- Platform: `__PLATFORM__`\n- Vibe version: `__VIBE_VERSION__`\n- Install mode: `__INSTALL_MODE__`\n- Release / channel: `__RELEASE__` / `__CHANNEL__`\n\n## Current State\n\n- This is a prewritten runtime skeleton from install/update.\n- `manifest.json` and `project-profile.md` are still created by `/vibe:init`.\n- Run `/vibe:init` to replace this placeholder with a complete initialization report.\n\n## Pending Dynamic Sections\n\n> Waiting for `/vibe:init` to fill scan summary, generated/refreshed artifacts, hooks status, memory/state notes, and next-step details.\n\n## Next Step\n\n- Run `/vibe:init`\n"""
for key, value in {
    "__STATUS__": "pending",
    "__PREPARED_BY__": prepared_by,
    "__TIMESTAMP__": timestamp,
    "__PLATFORM__": platform,
    "__VIBE_VERSION__": vibe_version,
    "__INSTALL_MODE__": install_mode,
    "__RELEASE__": release_value,
    "__CHANNEL__": channel_value,
}.items():
    text = text.replace(key, value)
report_path.write_text(text, encoding='utf-8')
PY
}

ensure_init_report_skeleton() {
    local report_file="$VIBE_DIR/init-report.md"
    local template_file="$VIBE_DIR/config/init-report-template.md"

    if init_report_is_complete "$report_file"; then
        return 0
    fi

    render_init_report_skeleton "$template_file" "$report_file" "update"
    REPAIRED_ITEMS+=("init-report.md")
}

is_machine_mode() {
    [[ "$LOG_MODE" == "machine" ]]
}

is_verbose_mode() {
    [[ "$LOG_MODE" == "verbose" ]]
}

log_info() {
    if ! is_machine_mode; then
        printf '%s\n' "$*"
    fi
}

count_semicolon_items() {
    local raw="$1"
    if [[ -z "$raw" || "$raw" == "-" ]]; then
        printf '0\n'
        return 0
    fi
    printf '%s\n' "$raw" | awk -F';' '{print NF}'
}

print_semicolon_preview() {
    local raw="$1"
    local label="$2"
    local limit="${3:-5}"

    if [[ -z "$raw" || "$raw" == "-" ]]; then
        return 0
    fi

    log_info "  - ${label}:"
    printf '%s\n' "$raw" | tr ';' '\n' | sed '/^$/d' | head -n "$limit" | while IFS= read -r line; do
        log_info "    - $line"
    done

    local total
    total="$(count_semicolon_items "$raw")"
    if [[ "$total" -gt "$limit" ]]; then
        log_info "    - ... 以及其余 $((total - limit)) 项"
    fi
}

extract_review_dirs() {
    local raw="$1"
    if [[ -z "$raw" || "$raw" == "-" ]]; then
        return 0
    fi

    printf '%s\n' "$raw" | tr ';' '\n' | sed '/^$/d' | while IFS= read -r line; do
        dirname "$line"
    done | sed 's#$#/#' | sort -u | awk '
        NR == 1 { print; prev = $0; next }
        index($0, prev) == 1 { next }
        { print; prev = $0 }
    '
}

print_review_dirs_and_cleanup() {
    local raw="$1"
    local label="$2"
    local mode="$3"
    local limit="${4:-5}"
    local dirs=()
    local dir

    while IFS= read -r dir; do
        [[ -n "$dir" ]] && dirs+=("$dir")
    done < <(extract_review_dirs "$raw")

    if (( ${#dirs[@]} == 0 )); then
        return 0
    fi

    log_info "  - ${label}:"
    local shown=0
    for dir in "${dirs[@]}"; do
        log_info "    - $dir"
        shown=$((shown + 1))
        if (( shown >= limit )); then
            break
        fi
    done
    if (( ${#dirs[@]} > limit )); then
        log_info "    - ... 以及其余 $(( ${#dirs[@]} - limit )) 项"
    fi

    if [[ "$mode" == "backups" ]]; then
        log_info "  - 清理命令:"
        log_info "    find $(printf '%s ' "${dirs[@]}")-type f \\( -name '*.local' -o -name '*.local.local' \\) -delete"
    else
        log_info "  - 清理命令:"
        log_info "    rm -rf $(printf '%s ' "${dirs[@]}")"
    fi
}

cleanup() {
    if [[ -n "$TEMP_SOURCE_DIR" && -d "$TEMP_SOURCE_DIR" ]]; then
        rm -rf "$TEMP_SOURCE_DIR"
    fi
}

restore_runtime_backup() {
    [[ -n "$BACKUP_DIR" && -d "$BACKUP_DIR" ]] || return 0

    mkdir -p "$VIBE_DIR"

    local file
    for file in "${RESTORE_FILES[@]}"; do
        if [[ -f "$BACKUP_DIR/$file" ]]; then
            cp -a "$BACKUP_DIR/$file" "$VIBE_DIR/$file"
        fi
    done

    local dir
    for dir in "${RESTORE_DIRS[@]}"; do
        if [[ -d "$BACKUP_DIR/$dir" ]]; then
            rm -rf "$VIBE_DIR/$dir"
            cp -a "$BACKUP_DIR/$dir" "$VIBE_DIR/$dir"
        fi
    done
}

handle_error() {
    local exit_code="$1"
    local line_no="$2"

    set +e
    if [[ "$POST_BACKUP_STARTED" -eq 1 ]]; then
        restore_runtime_backup || true
    fi

    echo "ERROR: vibe update failed at line $line_no (exit $exit_code)" >&2
    if [[ -n "$BACKUP_DIR" ]]; then
        echo "BACKUP_DIR=$BACKUP_DIR" >&2
    fi
    if [[ -n "$INSTALL_LOG" && -f "$INSTALL_LOG" ]]; then
        echo "--- install log tail ---" >&2
        tail -n 80 "$INSTALL_LOG" >&2 || true
    fi
    exit "$exit_code"
}

trap cleanup EXIT
trap 'handle_error $? $LINENO' ERR

join_by() {
    local sep="$1"
    shift || true
    local first=1
    local item
    for item in "$@"; do
        if [[ "$first" -eq 1 ]]; then
            printf '%s' "$item"
            first=0
        else
            printf '%s%s' "$sep" "$item"
        fi
    done
}

sort_paths_by_mtime_desc() {
    python3 - "$@" <<'PY'
import os
import sys

paths = [p for p in sys.argv[1:] if os.path.exists(p)]
for path in sorted(paths, key=lambda p: os.path.getmtime(p), reverse=True):
    print(path)
PY
}

require_base_install() {
    if [[ -d "$VIBE_DIR" ]]; then
        return 0
    fi

    echo "ERROR: 缺少基础安装目录：.vibe/" >&2
    echo "请先在目标项目里运行 ./install.sh . --both" >&2
    exit 1
}

resolve_install_mode() {
    local candidate=""

    if [[ -f "$INSTALL_MODE_FILE" ]]; then
        candidate="$(head -n 1 "$INSTALL_MODE_FILE" 2>/dev/null || true)"
    elif [[ -d "$CLAUDE_COMMANDS_DIR" && -d "$CLAUDE_AGENTS_DIR" ]]; then
        candidate="--both"
    elif [[ -d "$CLAUDE_COMMANDS_DIR" || -d "$CLAUDE_AGENTS_DIR" ]]; then
        candidate="--claude-only"
    else
        candidate="--codex-only"
    fi

    case "$candidate" in
        --claude-only|--codex-only|--both)
            INSTALL_MODE="$candidate"
            ;;
        *)
            INSTALL_MODE="--both"
            ;;
    esac
}

resolve_source() {
    local candidate=""
    if [[ -n "$EXPLICIT_SOURCE" ]]; then
        candidate="$EXPLICIT_SOURCE"
    elif [[ -s "$VIBE_DIR/.source" ]]; then
        candidate="$(head -n 1 "$VIBE_DIR/.source")"
    elif [[ -n "$DEFAULT_SOURCE" ]]; then
        candidate="$DEFAULT_SOURCE"
    fi

    if [[ -z "$candidate" ]]; then
        echo "ERROR: 无法确定更新源；请显式传入 source，或先写入 .vibe/.source" >&2
        exit 1
    fi

    if [[ -d "$candidate" ]]; then
        SOURCE_KIND="local"
        SOURCE_DIR="$(cd "$candidate" && pwd)"
        RESOLVED_SOURCE="$SOURCE_DIR"
    else
        SOURCE_KIND="git"
        RESOLVED_SOURCE="$candidate"
        TEMP_SOURCE_DIR="$(mktemp -d "${TMPDIR:-/tmp}/vibe-update-source.XXXXXX")"
        git clone --quiet --depth 1 "$candidate" "$TEMP_SOURCE_DIR" >/dev/null 2>&1
        SOURCE_DIR="$TEMP_SOURCE_DIR"
    fi

    if [[ ! -f "$SOURCE_DIR/install.sh" ]]; then
        echo "ERROR: 更新源缺少 install.sh：$SOURCE_DIR" >&2
        exit 1
    fi
}

resolve_source_metadata() {
    if [[ -f "$SOURCE_DIR/VERSION" ]]; then
        SOURCE_RELEASE="$(head -n 1 "$SOURCE_DIR/VERSION" 2>/dev/null || true)"
    fi

    if [[ -f "$SOURCE_DIR/releases/latest.json" ]]; then
        local metadata
        metadata="$(python3 - "$SOURCE_DIR/releases/latest.json" <<'PY'
from pathlib import Path
import json
import sys

path = Path(sys.argv[1])
try:
    data = json.loads(path.read_text())
except Exception:
    data = {}

print(data.get("version", ""))
print(data.get("channel", "stable"))
PY
)"
        local parsed_release parsed_channel
        parsed_release="$(printf '%s\n' "$metadata" | sed -n '1p')"
        parsed_channel="$(printf '%s\n' "$metadata" | sed -n '2p')"
        [[ -n "$parsed_release" ]] && SOURCE_RELEASE="$parsed_release"
        [[ -n "$parsed_channel" ]] && SOURCE_CHANNEL="$parsed_channel"
    fi

    if [[ -z "$SOURCE_RELEASE" && -f "$SOURCE_DIR/README.md" ]]; then
        SOURCE_RELEASE="$(python3 - "$SOURCE_DIR/README.md" <<'PY'
from pathlib import Path
import re
import sys

text = Path(sys.argv[1]).read_text(encoding="utf-8")
tick = chr(96)
for line in text.splitlines():
    if "当前版本：" not in line:
        continue
    parts = line.split(tick)
    if len(parts) >= 3:
        print(parts[1])
        raise SystemExit(0)
match = re.search(r"^# .* (v[0-9][^\s]*)$", text, re.MULTILINE)
if match:
    print(match.group(1))
PY
)"
    fi

    if [[ -z "$SOURCE_CHANNEL" ]]; then
        SOURCE_CHANNEL="stable"
    fi
}

verify_backup_item() {
    local item="$1"
    local src="$VIBE_DIR/$item"
    local dst="$BACKUP_DIR/$item"

    if [[ -f "$src" ]]; then
        [[ -f "$dst" ]] || {
            echo "ERROR: 备份校验失败，缺少文件 $item" >&2
            exit 1
        }
        return 0
    fi

    if [[ -d "$src" ]]; then
        [[ -d "$dst" ]] || {
            echo "ERROR: 备份校验失败，缺少目录 $item" >&2
            exit 1
        }
    fi
}

backup_runtime() {
    local timestamp
    timestamp="$(date +%Y%m%d_%H%M%S)"
    BACKUP_DIR="$VIBE_DIR/.backup_$timestamp"
    mkdir -p "$BACKUP_DIR"

    local item
    for item in "${BACKUP_ITEMS[@]}"; do
        if [[ -e "$VIBE_DIR/$item" ]]; then
            cp -a "$VIBE_DIR/$item" "$BACKUP_DIR/"
            PRESERVED_ITEMS+=("$item")
        fi
    done

    for item in "${BACKUP_ITEMS[@]}"; do
        if [[ -e "$VIBE_DIR/$item" ]]; then
            verify_backup_item "$item"
        fi
    done

    local backups=()
    local sorted=()
    shopt -s nullglob
    backups=( "$VIBE_DIR"/.backup_* )
    if (( ${#backups[@]} > 0 )); then
        while IFS= read -r line; do
            [[ -n "$line" ]] && sorted+=( "$line" )
        done < <(sort_paths_by_mtime_desc "${backups[@]}")
        KEPT_BACKUP="${sorted[0]}"
        if (( ${#sorted[@]} > 1 )); then
            local old
            for old in "${sorted[@]:1}"; do
                rm -rf "$old"
                REMOVED_BACKUPS+=("$old")
            done
        fi
    fi
    shopt -u nullglob

    POST_BACKUP_STARTED=1
}

run_install() {
    INSTALL_LOG="$(mktemp -t vibe-update-install)"
    log_info "📦 应用新版本安装产物..."
    local cmd=(bash "$SOURCE_DIR/install.sh" "$TARGET_DIR" "$INSTALL_MODE")
    if (( ${#INSTALL_EXTRA_ARGS[@]} > 0 )); then
        cmd+=("${INSTALL_EXTRA_ARGS[@]}")
    fi
    cmd+=(--record-source "$RESOLVED_SOURCE")
    if [[ -n "$SOURCE_RELEASE" ]]; then
        cmd+=(--record-release "$SOURCE_RELEASE")
    fi
    if [[ -n "$SOURCE_CHANNEL" ]]; then
        cmd+=(--record-channel "$SOURCE_CHANNEL")
    fi

    "${cmd[@]}" >"$INSTALL_LOG" 2>&1

    if grep -q "Claude Code 组件安装完成" "$INSTALL_LOG"; then
        INSTALL_CLAUDE_UPDATED="yes"
    fi
    if grep -q "Codex Skills 组件安装完成" "$INSTALL_LOG"; then
        INSTALL_CODEX_UPDATED="yes"
    fi
}

restore_runtime() {
    log_info "♻️  恢复项目级运行时数据..."
    restore_runtime_backup
    printf '%s\n' "$RESOLVED_SOURCE" > "$VIBE_DIR/.source"
    if [[ -n "$SOURCE_RELEASE" ]]; then
        printf '%s\n' "$SOURCE_RELEASE" > "$VIBE_DIR/.release"
    fi
    if [[ -n "$SOURCE_CHANNEL" ]]; then
        printf '%s\n' "$SOURCE_CHANNEL" > "$VIBE_DIR/.channel"
    fi

    local file
    for file in "${RESTORE_FILES[@]}"; do
        [[ -f "$BACKUP_DIR/$file" ]] && RESTORED_ITEMS+=("$file")
    done

    local dir
    for dir in "${RESTORE_DIRS[@]}"; do
        [[ -d "$BACKUP_DIR/$dir" ]] && RESTORED_ITEMS+=("$dir/")
    done
}

normalize_runtime_paths() {
    PATHS_NORMALIZED=()
    while IFS= read -r line; do
        [[ -n "$line" ]] && PATHS_NORMALIZED+=( "$line" )
    done < <(python3 - "$VIBE_DIR" <<'PY'
from pathlib import Path
import sys

root = Path(sys.argv[1])
patterns = [
    "STATE.md",
    "manifest.json",
    "project-profile.md",
    "init-report.md",
    "context/**/*.md",
    "memory/**/*.md",
    "design/**/*.md",
    "design/**/*.json",
]

seen = set()
for pattern in patterns:
    for path in root.glob(pattern):
        if not path.is_file():
            continue
        if path in seen:
            continue
        seen.add(path)
        text = path.read_text()
        updated = text.replace(".claude/vibe/", ".vibe/").replace(".agents/vibe/", ".vibe/")
        updated = updated.replace("`.claude/vibe`", "`.vibe`").replace("`.agents/vibe`", "`.vibe`")
        if updated != text:
            path.write_text(updated)
            print(path.relative_to(root))
PY
)
}

validate_templates() {
    local config_dir="$VIBE_DIR/config"
    local src_design_index="$SOURCE_DIR/templates/design/INDEX.md"
    local src_anti_patterns="$SOURCE_DIR/templates/design/ui-anti-patterns.md"
    local runtime_design_index="$config_dir/design-index-template.md"
    local runtime_anti_patterns="$config_dir/ui-anti-patterns-template.md"

    mkdir -p "$config_dir"

    if [[ ! -f "$runtime_design_index" && -f "$src_design_index" ]]; then
        cp "$src_design_index" "$runtime_design_index"
        REPAIRED_ITEMS+=("config/design-index-template.md")
    fi

    if [[ ! -f "$runtime_anti_patterns" && -f "$src_anti_patterns" ]]; then
        cp "$src_anti_patterns" "$runtime_anti_patterns"
        REPAIRED_ITEMS+=("config/ui-anti-patterns-template.md")
    fi

    [[ -f "$runtime_design_index" ]] || MISSING_TEMPLATES+=("config/design-index-template.md")
    [[ -f "$runtime_anti_patterns" ]] || MISSING_TEMPLATES+=("config/ui-anti-patterns-template.md")

    if [[ -f "$runtime_design_index" && ! -f "$VIBE_DIR/design/INDEX.md" ]]; then
        mkdir -p "$VIBE_DIR/design"
        cp "$runtime_design_index" "$VIBE_DIR/design/INDEX.md"
        REPAIRED_ITEMS+=("design/INDEX.md")
    fi

    if [[ -f "$runtime_anti_patterns" && ! -f "$VIBE_DIR/memory/patterns/ui-anti-patterns.md" ]]; then
        mkdir -p "$VIBE_DIR/memory/patterns"
        cp "$runtime_anti_patterns" "$VIBE_DIR/memory/patterns/ui-anti-patterns.md"
        REPAIRED_ITEMS+=("memory/patterns/ui-anti-patterns.md")
    fi

    ensure_init_report_skeleton
}

collect_local_backup_files() {
    LOCAL_BACKUP_FILES=()

    while IFS= read -r line; do
        [[ -n "$line" ]] && LOCAL_BACKUP_FILES+=( "$line" )
    done < <(find "$TARGET_DIR" \( -path "$VIBE_DIR/.backup_*" -o -path "$VIBE_DIR/.migration-backups" -o -path "$VIBE_DIR/.migration-backups/*" \) -prune -o -type f -name '*.local' -print | sort)
}

run_verify() {
    local verify_script="$SOURCE_DIR/scripts/vibe-verify-install.py"
    if [[ ! -f "$verify_script" ]]; then
        VERIFY_OK="skipped"
        VERIFY_NEXT_ACTION="verify script missing"
        return 0
    fi

    log_info "🔎 校验升级结果..."
    if VERIFY_OUTPUT="$(python3 "$verify_script" "$TARGET_DIR" --source-dir "$SOURCE_DIR" --latest-release "$SOURCE_RELEASE" --latest-channel "$SOURCE_CHANNEL" 2>&1)"; then
        VERIFY_EXIT_CODE=0
    else
        VERIFY_EXIT_CODE=$?
    fi

    VERIFY_OK="$(printf '%s\n' "$VERIFY_OUTPUT" | sed -n 's/^VERIFY_OK=//p' | head -n 1)"
    VERIFY_INSTALL_MODE="$(printf '%s\n' "$VERIFY_OUTPUT" | sed -n 's/^INSTALL_MODE=//p' | head -n 1)"
    VERIFY_INIT_STATUS="$(printf '%s\n' "$VERIFY_OUTPUT" | sed -n 's/^INIT_STATUS=//p' | head -n 1)"
    VERIFY_CURRENT_RELEASE="$(printf '%s\n' "$VERIFY_OUTPUT" | sed -n 's/^CURRENT_RELEASE=//p' | head -n 1)"
    VERIFY_LATEST_RELEASE="$(printf '%s\n' "$VERIFY_OUTPUT" | sed -n 's/^LATEST_RELEASE=//p' | head -n 1)"
    VERIFY_CURRENT_CHANNEL="$(printf '%s\n' "$VERIFY_OUTPUT" | sed -n 's/^CURRENT_CHANNEL=//p' | head -n 1)"
    VERIFY_LATEST_CHANNEL="$(printf '%s\n' "$VERIFY_OUTPUT" | sed -n 's/^LATEST_CHANNEL=//p' | head -n 1)"
    VERIFY_LOCAL_BACKUPS="$(printf '%s\n' "$VERIFY_OUTPUT" | sed -n 's/^LOCAL_BACKUPS=//p' | head -n 1)"
    VERIFY_MIGRATION_CONFLICTS="$(printf '%s\n' "$VERIFY_OUTPUT" | sed -n 's/^MIGRATION_CONFLICTS=//p' | head -n 1)"
    VERIFY_WARNINGS="$(printf '%s\n' "$VERIFY_OUTPUT" | sed -n 's/^WARNINGS=//p' | head -n 1)"
    VERIFY_NEXT_ACTION="$(printf '%s\n' "$VERIFY_OUTPUT" | sed -n 's/^NEXT_ACTION=//p' | head -n 1)"
}

extract_changelog() {
    local readme="$SOURCE_DIR/README.md"
    [[ -f "$readme" ]] || return 0

    CHANGELOG_LINES=()
    while IFS= read -r line; do
        CHANGELOG_LINES+=( "$line" )
    done < <(python3 - "$readme" <<'PY'
from pathlib import Path
import re
import sys

text = Path(sys.argv[1]).read_text()
marker = "## 更新日志"
if marker not in text:
    print("未找到更新日志章节")
    raise SystemExit(0)

section = text.split(marker, 1)[1]
entries = re.split(r"(?m)^###\s+", section)
count = 0
for chunk in entries[1:]:
    if count >= 3:
        break
    lines = [line.rstrip() for line in chunk.splitlines()]
    if not lines:
        continue
    header = "### " + lines[0].strip()
    body = []
    for line in lines[1:]:
        stripped = line.strip()
        if stripped.startswith("## "):
            break
        if stripped.startswith("- "):
            body.append(stripped)
        if len(body) >= 5:
            break
    print(header)
    if body:
        for item in body:
            print(item)
    else:
        print("- （该版本无摘要条目）")
    print("")
    count += 1
PY
)
}

write_report() {
    REPORT_FILE="$VIBE_DIR/update-last-report.md"
    mkdir -p "$VIBE_DIR"

    {
        echo "# Vibe Update Report"
        echo ""
        echo "- 时间：$(date '+%Y-%m-%d %H:%M:%S %Z')"
        echo "- 目标目录：\`$TARGET_DIR\`"
        echo "- 更新源：\`$RESOLVED_SOURCE\`"
        echo "- 更新源类型：$SOURCE_KIND"
        echo "- 当前 release：${VERIFY_CURRENT_RELEASE:-${SOURCE_RELEASE:-unknown}}"
        echo "- 目标 release：${VERIFY_LATEST_RELEASE:-${SOURCE_RELEASE:-unknown}}"
        echo "- channel：${SOURCE_CHANNEL:-unknown}"
        if (( ${#INSTALL_EXTRA_ARGS[@]} > 0 )); then
            echo "- 维护者 install flags：$(join_by ', ' "${INSTALL_EXTRA_ARGS[@]}")"
        else
            echo "- 维护者 install flags：无"
        fi
        echo "- Claude 安装产物：$INSTALL_CLAUDE_UPDATED"
        echo "- Codex 安装产物：$INSTALL_CODEX_UPDATED"
        echo "- 备份目录：\`$BACKUP_DIR\`"
        echo "- 最终保留备份：\`$KEPT_BACKUP\`"
        echo ""
        echo "## 备份保留策略"
        if (( ${#REMOVED_BACKUPS[@]} > 0 )); then
            echo "- 已清理旧备份："
            local old
            for old in "${REMOVED_BACKUPS[@]}"; do
                echo "  - \`$old\`"
            done
        else
            echo "- 没有额外旧备份需要清理"
        fi
        echo ""
        echo "## 保留并恢复的共享运行时数据"
        if (( ${#PRESERVED_ITEMS[@]} > 0 )); then
            echo "- 备份项：$(join_by ', ' "${PRESERVED_ITEMS[@]}")"
        else
            echo "- 备份项：无"
        fi
        if (( ${#RESTORED_ITEMS[@]} > 0 )); then
            echo "- 恢复项：$(join_by ', ' "${RESTORED_ITEMS[@]}")"
        else
            echo "- 恢复项：无"
        fi
        echo ""
        echo "## 运行时校验"
        if (( ${#PATHS_NORMALIZED[@]} > 0 )); then
            echo "- 已修正旧路径引用："
            local normalized
            for normalized in "${PATHS_NORMALIZED[@]}"; do
                echo "  - \`$normalized\`"
            done
        else
            echo "- 未发现需要修正的旧路径引用"
        fi
        if (( ${#REPAIRED_ITEMS[@]} > 0 )); then
            echo "- 已补写/修复："
            local repaired
            for repaired in "${REPAIRED_ITEMS[@]}"; do
                echo "  - \`$repaired\`"
            done
        else
            echo "- 未发生模板补写"
        fi
        if (( ${#MISSING_TEMPLATES[@]} > 0 )); then
            echo "- 模板校验：失败"
            local missing
            for missing in "${MISSING_TEMPLATES[@]}"; do
                echo "  - 缺失：\`$missing\`"
            done
            echo "- 建议：重新运行 \`./install.sh . --both\`"
        else
            echo "- 模板校验：通过"
        fi
        echo "- verify 结果：${VERIFY_OK:-unknown}"
        if [[ -n "$VERIFY_NEXT_ACTION" ]]; then
            echo "- verify 下一步：$VERIFY_NEXT_ACTION"
        fi
        if [[ -n "$VERIFY_OUTPUT" ]]; then
            echo ""
            echo "### 机器可读 verify 输出"
            printf '%s\n' "$VERIFY_OUTPUT"
        fi
        echo ""
        echo "## 目标目录下现存 *.local 文件"
        if (( ${#LOCAL_BACKUP_FILES[@]} > 0 )); then
            local local_file
            for local_file in "${LOCAL_BACKUP_FILES[@]}"; do
                echo "- \`$local_file\`"
            done
        else
            echo "- 无"
        fi
        echo ""
        echo "## 最近更新日志"
        if (( ${#CHANGELOG_LINES[@]} > 0 )); then
            local line
            for line in "${CHANGELOG_LINES[@]}"; do
                if [[ -n "$line" ]]; then
                    echo "$line"
                else
                    echo ""
                fi
            done
        else
            echo "- 未找到更新日志章节"
        fi
        echo ""
        echo "## 安装日志"
        echo "- install.sh 日志：\`$INSTALL_LOG\`"
    } > "$REPORT_FILE"
}

print_summary() {
    if is_machine_mode; then
        echo "VIBE_UPDATE_OK=1"
        echo "TARGET_DIR=$TARGET_DIR"
        echo "SOURCE_KIND=$SOURCE_KIND"
        echo "SOURCE=$RESOLVED_SOURCE"
        echo "CURRENT_RELEASE=${VERIFY_CURRENT_RELEASE:-$SOURCE_RELEASE}"
        echo "LATEST_RELEASE=${VERIFY_LATEST_RELEASE:-$SOURCE_RELEASE}"
        echo "VERIFY_OK=${VERIFY_OK:-unknown}"
        echo "INSTALL_EXTRA_ARGS_COUNT=${#INSTALL_EXTRA_ARGS[@]}"
        echo "BACKUP_DIR=$BACKUP_DIR"
        echo "KEPT_BACKUP=$KEPT_BACKUP"
        echo "REMOVED_BACKUPS_COUNT=${#REMOVED_BACKUPS[@]}"
        echo "CLAUDE_UPDATED=$INSTALL_CLAUDE_UPDATED"
        echo "CODEX_UPDATED=$INSTALL_CODEX_UPDATED"
        echo "REPORT_FILE=$REPORT_FILE"
        echo ""
        cat "$REPORT_FILE"
        return 0
    fi

    log_info ""
    if [[ "${VERIFY_OK:-0}" == "1" ]]; then
        log_info "✅ Vibe 升级完成"
    else
        log_info "⚠️  Vibe 升级已完成，但校验发现需要关注的项目"
    fi
    log_info "  - 目标目录: $TARGET_DIR"
    log_info "  - 更新源: $RESOLVED_SOURCE"
    log_info "  - install mode: ${VERIFY_INSTALL_MODE:-$INSTALL_MODE}"
    log_info "  - 当前 / 目标版本: ${VERIFY_CURRENT_RELEASE:-$SOURCE_RELEASE} / ${VERIFY_LATEST_RELEASE:-$SOURCE_RELEASE}"
    log_info "  - 当前 / 目标 channel: ${VERIFY_CURRENT_CHANNEL:-$SOURCE_CHANNEL} / ${VERIFY_LATEST_CHANNEL:-$SOURCE_CHANNEL}"
    log_info "  - Claude 安装产物: $INSTALL_CLAUDE_UPDATED"
    log_info "  - Codex 安装产物: $INSTALL_CODEX_UPDATED"
    log_info "  - 备份目录: $BACKUP_DIR"
    log_info "  - 更新报告: $REPORT_FILE"
    if [[ "${VERIFY_INIT_STATUS:-unknown}" == "not_initialized" ]]; then
        log_info "  - 项目级初始化: 未完成（后续运行 vibe:init 即可）"
    fi
    if [[ "$(count_semicolon_items "$VERIFY_LOCAL_BACKUPS")" -gt 0 ]]; then
        log_info "  - 发现目标目录下现存 *.local 文件: $(count_semicolon_items "$VERIFY_LOCAL_BACKUPS") 个"
        print_review_dirs_and_cleanup "$VERIFY_LOCAL_BACKUPS" "建议 review 的现存 *.local 文件目录" "backups" 5
    fi
    if [[ "$(count_semicolon_items "$VERIFY_MIGRATION_CONFLICTS")" -gt 0 ]]; then
        log_info "  - 发现迁移冲突记录: $(count_semicolon_items "$VERIFY_MIGRATION_CONFLICTS") 个"
        print_review_dirs_and_cleanup "$VERIFY_MIGRATION_CONFLICTS" "建议 review 的迁移冲突目录" "conflicts" 5
    fi
    if [[ -n "$VERIFY_WARNINGS" && "$VERIFY_WARNINGS" != "-" ]]; then
        log_info "  - 提示: $VERIFY_WARNINGS"
    fi
    if [[ -n "$VERIFY_NEXT_ACTION" && "$VERIFY_NEXT_ACTION" != "none" ]]; then
        log_info "  - 下一步: $VERIFY_NEXT_ACTION"
    fi
    if is_verbose_mode; then
        log_info ""
        cat "$REPORT_FILE"
    fi
}

main() {
    log_info "🔍 检查当前安装状态..."
    require_base_install
    log_info "🧭 解析安装模式与更新源..."
    resolve_install_mode
    resolve_source
    resolve_source_metadata
    log_info "💾 备份当前运行时数据..."
    backup_runtime
    run_install
    restore_runtime
    log_info "🛠️  修复路径与模板校验..."
    normalize_runtime_paths
    validate_templates
    collect_local_backup_files
    run_verify
    extract_changelog
    write_report
    print_summary
    if [[ "$VERIFY_EXIT_CODE" -ne 0 ]]; then
        return "$VERIFY_EXIT_CODE"
    fi
}

main "$@"
