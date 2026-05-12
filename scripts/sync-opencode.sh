#!/usr/bin/env bash
# Sync .claude/skills/autoresearch/ → .opencode/skills/autoresearch/
# Applies OpenCode-specific adaptations (tool names, command syntax, paths)
# Run this after any change to the Claude Code source files.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

SRC="$REPO_ROOT/.claude/skills/autoresearch"
DST="$REPO_ROOT/.opencode/skills/autoresearch"

if [[ ! -d "$SRC" ]]; then
  printf 'Error: source directory not found: %s\n' "$SRC" >&2
  exit 1
fi

mkdir -p "$DST/references"

adapt_file() {
  local src_file="$1"
  local dst_file="$2"

  sed \
    -e 's/`AskUserQuestion`/`question`/g' \
    -e 's/AskUserQuestion/question/g' \
    -e 's|/autoresearch:plan|/autoresearch_plan|g' \
    -e 's|/autoresearch:debug|/autoresearch_debug|g' \
    -e 's|/autoresearch:fix|/autoresearch_fix|g' \
    -e 's|/autoresearch:security|/autoresearch_security|g' \
    -e 's|/autoresearch:ship|/autoresearch_ship|g' \
    -e 's|/autoresearch:scenario|/autoresearch_scenario|g' \
    -e 's|/autoresearch:predict|/autoresearch_predict|g' \
    -e 's|/autoresearch:learn|/autoresearch_learn|g' \
    -e 's|/autoresearch:reason|/autoresearch_reason|g' \
    -e 's|/autoresearch:probe|/autoresearch_probe|g' \
    -e 's|`Agent tool`|`@mention`|g' \
    -e 's|`Agent` tool|`@mention`|g' \
    -e 's|\.claude/skills/autoresearch|.opencode/skills/autoresearch|g' \
    -e 's|\.claude/agents/autoresearch-worker|.opencode/agents/autoresearch-worker|g' \
    "$src_file" > "$dst_file"
}

# Sync reference files
for f in "$SRC"/references/*.md; do
  basename=$(basename "$f")
  adapt_file "$f" "$DST/references/$basename"
  printf '  synced: references/%s\n' "$basename"
done

# Sync SKILL.md
adapt_file "$SRC/SKILL.md" "$DST/SKILL.md"

# Sync worker subagent (with OpenCode-specific frontmatter rewrite)
if [[ -f "$REPO_ROOT/.claude/agents/autoresearch-worker.md" ]]; then
  mkdir -p "$REPO_ROOT/.opencode/agents"
  WORKER_DST="$REPO_ROOT/.opencode/agents/autoresearch-worker.md"
  adapt_file "$REPO_ROOT/.claude/agents/autoresearch-worker.md" "$WORKER_DST"
  # Replace Claude Code frontmatter (tools/model/maxTurns) with OpenCode form
  # (mode: subagent, hidden: true, lowercase tools as a YAML map).
  python3 -c "
import re, sys
path = sys.argv[1]
with open(path, 'r') as fh:
    content = fh.read()
m = re.match(r'^(---\n)(.*?)(\n---\n)(.*)$', content, re.DOTALL)
if not m:
    sys.exit(0)
head, fm, sep, body = m.group(1), m.group(2), m.group(3), m.group(4)
lines = fm.split('\n')
keep = []
for ln in lines:
    if ln.startswith('tools:') or ln.startswith('model:') or ln.startswith('maxTurns:') or ln.startswith('mode:') or ln.startswith('hidden:'):
        continue
    if ln.strip().startswith('bash:') or ln.strip().startswith('read:') or ln.strip().startswith('write:') or ln.strip().startswith('edit:'):
        continue
    keep.append(ln)
keep.append('mode: subagent')
keep.append('hidden: true')
keep.append('tools:')
keep.append('  bash: true')
keep.append('  read: true')
keep.append('  write: true')
keep.append('  edit: true')
new_fm = '\n'.join(keep).rstrip('\n')
with open(path, 'w') as fh:
    fh.write(head + new_fm + sep + body)
" "$WORKER_DST" 2>/dev/null || {
    printf 'Warning: python3 worker frontmatter patch failed for %s\n' "$WORKER_DST" >&2
  }
  printf '  synced: agents/autoresearch-worker.md\n'
fi

# Patch frontmatter: version → compatibility + metadata
python3 -c "
import re, sys, os

dst = sys.argv[1]
skill_path = os.path.join(dst, 'SKILL.md')

with open(skill_path, 'r') as f:
    content = f.read()

content = content.replace('# Claude Autoresearch', '# OpenCode Autoresearch', 1)

content = re.sub(
    r'^(---\nname: autoresearch\ndescription:.*?)version: ([\d.]+)\n(---)',
    r'\1compatibility: opencode\nmetadata:\n  source: claude-port\n  version: \2\n\3',
    content,
    count=1,
    flags=re.DOTALL
)

with open(skill_path, 'w') as f:
    f.write(content)
" "$DST" 2>/dev/null || {
  printf 'Warning: python3 frontmatter patch failed, SKILL.md may need manual review\n' >&2
}

printf '  synced: SKILL.md\n'

# Count results
total=$(find "$DST" -name '*.md' | wc -l | tr -d ' ')
printf 'Sync complete: %s files updated in %s\n' "$total" "$DST"
