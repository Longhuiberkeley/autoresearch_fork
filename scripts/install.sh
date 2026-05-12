#!/usr/bin/env bash
# Autoresearch installer — supports Claude Code, OpenCode, and OpenAI Codex, local or global.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

TOOL=""
LOCATION=""
CONFIG_DIR=""
FORCE=0
SUFFIX=""

cancelled() { printf "\nInstallation cancelled\n"; exit 0; }
trap cancelled INT

usage() {
  cat <<'EOF'
Usage: ./scripts/install.sh [options]

Options:
  --claude            Install for Claude Code
  --opencode          Install for OpenCode
  --codex             Install for OpenAI Codex
  -g, --global        Install globally
  -l, --local         Install in the current project
  -c, --config-dir    Override the global config directory
  --suffix <text>     Install with a name suffix (e.g. --suffix fork installs the
                      skill as "autoresearch-fork" so it co-exists with another
                      copy of autoresearch on the same global install. Only
                      meaningful with --global.)
  --force             Replace existing files without prompting
  -h, --help          Show this help message

Examples:
  ./scripts/install.sh                          # interactive
  ./scripts/install.sh --claude --global
  ./scripts/install.sh --claude --global --suffix fork
  ./scripts/install.sh --opencode --local
  ./scripts/install.sh --codex --global
EOF
}

expand_path() {
  local raw="$1"
  if [[ "$raw" == ~* ]]; then
    printf '%s\n' "${raw/#\~/$HOME}"
  else
    printf '%s\n' "$raw"
  fi
}

is_interactive() { [[ -t 0 && -t 1 ]]; }

die() { printf 'Error: %s\n' "$1" >&2; exit 1; }

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --claude)
        if [[ -n "$TOOL" && "$TOOL" != "claude" ]]; then die "choose only one tool"; fi
        TOOL="claude" ;;
      --opencode)
        if [[ -n "$TOOL" && "$TOOL" != "opencode" ]]; then die "choose only one tool"; fi
        TOOL="opencode" ;;
      --codex)
        if [[ -n "$TOOL" && "$TOOL" != "codex" ]]; then die "choose only one tool"; fi
        TOOL="codex" ;;
      -g|--global)
        if [[ -n "$LOCATION" && "$LOCATION" != "global" ]]; then die "choose --global or --local"; fi
        LOCATION="global" ;;
      -l|--local)
        if [[ -n "$LOCATION" && "$LOCATION" != "local" ]]; then die "choose --global or --local"; fi
        LOCATION="local" ;;
      -c|--config-dir)
        shift
        if [[ $# -eq 0 ]]; then die "--config-dir requires a path"; fi
        CONFIG_DIR="$(expand_path "$1")" ;;
      --config-dir=*)
        CONFIG_DIR="$(expand_path "${1#*=}")"
        if [[ -z "$CONFIG_DIR" ]]; then die "--config-dir requires a path"; fi ;;
      --suffix)
        shift
        if [[ $# -eq 0 ]]; then die "--suffix requires a value"; fi
        SUFFIX="$1" ;;
      --suffix=*)
        SUFFIX="${1#*=}"
        if [[ -z "$SUFFIX" ]]; then die "--suffix requires a value"; fi ;;
      --force) FORCE=1 ;;
      -h|--help) usage; exit 0 ;;
      *) die "unknown argument: $1" ;;
    esac
    shift
  done
  if [[ -n "$CONFIG_DIR" && "$LOCATION" == "local" ]]; then
    die "--config-dir can only be used with --global"
  fi
  if [[ -n "$SUFFIX" && ! "$SUFFIX" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
    die "--suffix must be lowercase alphanumerics + hyphens (got: $SUFFIX)"
  fi
}

skill_name() { if [[ -n "$SUFFIX" ]]; then printf 'autoresearch-%s\n' "$SUFFIX"; else printf 'autoresearch\n'; fi; }

# Patch frontmatter `name: autoresearch` → `name: autoresearch-<suffix>` and any
# `/autoresearch:` slash command tokens → `/autoresearch-<suffix>:` inside an
# installed file. No-op when SUFFIX is empty.
patch_suffix() {
  local file="$1" sname
  [[ -z "$SUFFIX" ]] && return 0
  [[ -f "$file" ]] || return 0
  sname="$(skill_name)"
  # Portable BSD/GNU sed in-place edit.
  # Order: do all forms that ANCHOR on a distinguishing suffix character first
  # (`:`, `_`, `.md`, `-worker`), then handle bare `/autoresearch` with an
  # explicit guard that the next char is NOT `-` (which would already mean it
  # is suffixed) and NOT an alnum (which would be a longer identifier).
  sed -i.bak \
    -e "s|^name: autoresearch:|name: ${sname}:|" \
    -e "s|^name: autoresearch_|name: ${sname}_|" \
    -e "s|^name: autoresearch$|name: ${sname}|" \
    -e "s|^name: autoresearch\\.md$|name: ${sname}.md|" \
    -e "s|/autoresearch:|/${sname}:|g" \
    -e "s|/autoresearch_|/${sname}_|g" \
    -e "s|/autoresearch\\.md|/${sname}.md|g" \
    -e "s|autoresearch-worker|${sname}-worker|g" \
    -e "s|/autoresearch\\([^-:_a-zA-Z0-9]\\)|/${sname}\\1|g" \
    -e "s|/autoresearch$|/${sname}|g" \
    -e "s|\\\$autoresearch |\$${sname} |g" \
    -e "s|\\.claude/skills/autoresearch/|.claude/skills/${sname}/|g" \
    -e "s|\\.opencode/skills/autoresearch/|.opencode/skills/${sname}/|g" \
    "$file"
  rm -f "$file.bak"
}

get_global_dir() {
  local tool="$1"
  if [[ -n "$CONFIG_DIR" ]]; then printf '%s\n' "$CONFIG_DIR"; return; fi
  case "$tool" in
    claude)
      if [[ -n "${CLAUDE_CONFIG_DIR:-}" ]]; then
        expand_path "$CLAUDE_CONFIG_DIR"
      else
        printf '%s\n' "$HOME/.claude"
      fi ;;
    opencode)
      if [[ -n "${OPENCODE_CONFIG_DIR:-}" ]]; then expand_path "$OPENCODE_CONFIG_DIR"
      elif [[ -n "${OPENCODE_CONFIG:-}" ]]; then dirname "$(expand_path "$OPENCODE_CONFIG")"
      elif [[ -n "${XDG_CONFIG_HOME:-}" ]]; then printf '%s\n' "$(expand_path "$XDG_CONFIG_HOME")/opencode"
      else printf '%s\n' "$HOME/.config/opencode"; fi ;;
    codex)
      if [[ -n "${CODEX_HOME:-}" ]]; then expand_path "$CODEX_HOME"
      else printf '%s\n' "$HOME/.codex"; fi ;;
  esac
}

get_target_dir() {
  local tool="$1" location="$2"
  if [[ "$location" == "local" ]]; then
    case "$tool" in
      claude) printf '%s\n' "$PWD/.claude" ;;
      opencode) printf '%s\n' "$PWD/.opencode" ;;
      codex) printf '%s\n' "$PWD/.codex" ;;
    esac
    return
  fi
  get_global_dir "$tool"
}

prompt_tool() {
  local answer
  printf 'Select the tool to install:\n  1) Claude Code\n  2) OpenCode\n  3) OpenAI Codex\nChoice [1]: '
  read -r answer || cancelled
  case "${answer:-1}" in
    1) TOOL="claude" ;;
    2) TOOL="opencode" ;;
    3) TOOL="codex" ;;
    *) die "invalid selection: $answer" ;;
  esac
}

prompt_location() {
  local global_dir answer local_dir
  global_dir="$(get_global_dir "$TOOL")"
  case "$TOOL" in claude) local_dir="$PWD/.claude" ;; opencode) local_dir="$PWD/.opencode" ;; codex) local_dir="$PWD/.codex" ;; esac
  printf 'Install location:\n  1) Global (%s)\n  2) Local  (%s)\nChoice [1]: ' "$global_dir" "$local_dir"
  read -r answer || cancelled
  case "${answer:-1}" in
    1) LOCATION="global" ;;
    2) LOCATION="local" ;;
    *) die "invalid selection: $answer" ;;
  esac
}

ensure_context() {
  if [[ -z "$TOOL" ]]; then
    if is_interactive; then prompt_tool; else TOOL="claude"; fi
  fi
  if [[ -z "$LOCATION" ]]; then
    if is_interactive; then prompt_location; else LOCATION="global"; fi
  fi
}

sync_dir() {
  [[ -n "$2" && "$2" =~ ^/.{3,}/.{1,}/.{1,} ]] || die "sync_dir: refusing unsafe destination path: ${2:-<empty>}"
  rm -rf "$2"
  mkdir -p "$(dirname "$2")"
  cp -R "$1" "$2"
}
sync_file() { mkdir -p "$(dirname "$2")"; cp "$1" "$2"; }

confirm_overwrite() {
  local target_root="$1"
  if [[ $FORCE -eq 1 ]]; then return 0; fi
  if [[ ! -d "$target_root/skills/$(skill_name)" ]]; then return 0; fi
  if ! is_interactive; then return 0; fi
  local answer
  printf 'Existing autoresearch files found in %s. Replace? [Y/n]: ' "$target_root"
  read -r answer || cancelled
  case "${answer:-Y}" in
    [yY]|[yY][eE][sS]|'') ;;
    *) printf 'Skipped.\n'; exit 0 ;;
  esac
}

install_claude() {
  local t="$1" sname f
  sname="$(skill_name)"
  mkdir -p "$t/skills" "$t/commands" "$t/agents"

  sync_dir "$REPO_ROOT/.claude/skills/autoresearch" "$t/skills/$sname"
  patch_suffix "$t/skills/$sname/SKILL.md"
  if [[ -d "$t/skills/$sname/references" ]]; then
    for f in "$t/skills/$sname/references"/*.md; do patch_suffix "$f"; done
  fi

  if [[ -d "$REPO_ROOT/.claude/commands/autoresearch" ]]; then
    sync_dir "$REPO_ROOT/.claude/commands/autoresearch" "$t/commands/$sname"
    for f in "$t/commands/$sname"/*.md; do patch_suffix "$f"; done
  fi
  if [[ -f "$REPO_ROOT/.claude/commands/autoresearch.md" ]]; then
    sync_file "$REPO_ROOT/.claude/commands/autoresearch.md" "$t/commands/$sname.md"
    patch_suffix "$t/commands/$sname.md"
  fi
  if [[ -f "$REPO_ROOT/.claude/agents/autoresearch-worker.md" ]]; then
    local agent_name="autoresearch-worker"
    [[ -n "$SUFFIX" ]] && agent_name="autoresearch-${SUFFIX}-worker"
    sync_file "$REPO_ROOT/.claude/agents/autoresearch-worker.md" "$t/agents/${agent_name}.md"
    if [[ -n "$SUFFIX" ]]; then
      sed -i.bak "s|^name: autoresearch-worker$|name: ${agent_name}|" "$t/agents/${agent_name}.md"
      rm -f "$t/agents/${agent_name}.md.bak"
    fi
  fi
}

install_opencode() {
  local t="$1" sname src dst agent_name f
  sname="$(skill_name)"
  mkdir -p "$t/skills" "$t/commands" "$t/agents"

  sync_dir "$REPO_ROOT/.opencode/skills/autoresearch" "$t/skills/$sname"
  patch_suffix "$t/skills/$sname/SKILL.md"
  if [[ -d "$t/skills/$sname/references" ]]; then
    for f in "$t/skills/$sname/references"/*.md; do patch_suffix "$f"; done
  fi

  for src in "$REPO_ROOT"/.opencode/commands/autoresearch*.md; do
    [[ -f "$src" ]] || continue
    # autoresearch.md → <sname>.md ; autoresearch_plan.md → <sname>_plan.md
    dst="$(basename "$src")"
    dst="${dst/autoresearch/$sname}"
    sync_file "$src" "$t/commands/$dst"
    patch_suffix "$t/commands/$dst"
  done

  for src in "$REPO_ROOT"/.opencode/agents/*.md; do
    [[ -f "$src" ]] || continue
    agent_name="$(basename "$src" .md)"
    if [[ -n "$SUFFIX" && "$agent_name" == "autoresearch-worker" ]]; then
      agent_name="autoresearch-${SUFFIX}-worker"
      sync_file "$src" "$t/agents/${agent_name}.md"
      sed -i.bak "s|^name: autoresearch-worker$|name: ${agent_name}|" "$t/agents/${agent_name}.md"
      rm -f "$t/agents/${agent_name}.md.bak"
    else
      sync_file "$src" "$t/agents/$(basename "$src")"
    fi
  done
}

install_codex() {
  local t="$1" sname f worker_path agent_name
  sname="$(skill_name)"
  mkdir -p "$t/skills"
  sync_dir "$REPO_ROOT/.agents/skills/autoresearch" "$t/skills/$sname"
  patch_suffix "$t/skills/$sname/SKILL.md"
  if [[ -d "$t/skills/$sname/references" ]]; then
    for f in "$t/skills/$sname/references"/*.md; do patch_suffix "$f"; done
  fi
  worker_path="$t/skills/$sname/agents/autoresearch-worker.md"
  if [[ -f "$worker_path" && -n "$SUFFIX" ]]; then
    agent_name="autoresearch-${SUFFIX}-worker"
    sed -i.bak "s|^name: autoresearch-worker$|name: ${agent_name}|" "$worker_path"
    rm -f "$worker_path.bak"
  fi
  sync_file "$REPO_ROOT/plugins/autoresearch/resources/autoresearch-command-spec.json" "$t/skills/$sname/resources/autoresearch-command-spec.json"
  sync_file "$REPO_ROOT/plugins/autoresearch/scripts/autoresearch_cli.py" "$t/skills/$sname/scripts/autoresearch_cli.py"
}

main() {
  parse_args "$@"
  ensure_context
  local target_root
  target_root="$(get_target_dir "$TOOL" "$LOCATION")"
  confirm_overwrite "$target_root"

  local label
  case "$TOOL" in claude) label="Claude Code" ;; opencode) label="OpenCode" ;; codex) label="OpenAI Codex" ;; esac
  printf 'Installing Autoresearch for %s (%s)\nTarget: %s\n' "$label" "$LOCATION" "$target_root"

  case "$TOOL" in
    claude) install_claude "$target_root" ;;
    opencode) install_opencode "$target_root" ;;
    codex) install_codex "$target_root" ;;
  esac

  case "$TOOL" in
    codex) printf 'Done. Use $autoresearch in Codex to start.\n' ;;
    *) printf 'Done. Run /autoresearch to start.\n' ;;
  esac
}

main "$@"
