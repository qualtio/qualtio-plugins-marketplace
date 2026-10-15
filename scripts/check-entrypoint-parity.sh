#!/usr/bin/env bash
#
# Watches the launcher -> rulebook architecture inside each multi-client plugin.
#
#  1. RULEBOOK PARITY: the Copilot agent (com.github.copilot/agents/*.agent.md) and the
#     Claude subagent (claude/agents/*.md) are mirrored rulebooks. Their markdown
#     body (after the frontmatter) must be byte-for-byte identical, except that
#     the Claude rulebook may end with the additional section
#     "## If the delegation message lacks detail" (subagents start without
#     conversation history; the Copilot agent does not need it).
#
#  2. THIN LAUNCHERS: the Copilot command (com.github.copilot/commands/*.prompt.md) and the
#     Claude command (claude/commands/*.md) are launchers. They must not carry
#     behavior-rule sections, nor link markdown files outside their own
#     directory: no client resolves those links at runtime, so they would be
#     rules the model may never see.
#
#  3. WIRING: the Copilot prompt must delegate via the `agent:` frontmatter to the
#     `name:` of the Copilot agent, and the body of the Claude command must name
#     the Claude subagent.
#
#  4. TOOL COVERAGE: every Copilot tool category must have its equivalent granted
#     in the Claude subagent. The two clients use different vocabularies with no
#     structural way to compare them, so the mapping is deliberately explicit.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

ERRORS=0
err() { ERRORS=$((ERRORS+1)); printf 'ERROR [%s] %s\n' "$1" "$2" >&2; }
ok()  { printf 'OK    [%s] %s\n' "$1" "$2"; }

# Headings that mark behavior rules. Only valid in rulebooks.
RULE_HEADINGS='^## (Behavior|Non-Negotiable Reminders|Global Rules|Validation Guardrails|Quick Examples|External Sources)$'

# Markdown body (everything after the frontmatter closes), without trailing spaces.
extract_body() {
  awk 'NR==1 && $0=="---" {infm=1; next} infm && /^---$/ {infm=0; body=1; next} body' "$1" \
    | sed -E 's/[[:space:]]+$//'
}

# Same as extract_body but cutting before the subagent's own section.
extract_body_without_claude_tail() {
  extract_body "$1" | awk '/^## If the delegation message lacks detail$/ {exit} {print}'
}

trim_trailing_blank() {
  awk '{l[NR]=$0} END {last=NR; while (last>0 && l[last] ~ /^[[:space:]]*$/) last--; for (i=1;i<=last;i++) print l[i]}'
}

extract_fm_value() {
  awk -v key="$2" 'NR==1 && $0=="---" {infm=1; next} infm && /^---$/ {exit}
       infm && index($0, key":")==1 {sub("^" key ":[[:space:]]*",""); print; exit}' "$1" \
    | sed -E "s/^['\"]//; s/['\"]$//"
}

# Returns the `tools:` tokens, one per line. Accepts the Copilot form
# `tools: [a, b]` and the Claude form `tools: A, B`.
extract_tools() {
  awk 'NR==1 && $0=="---" {infm=1; next} infm && /^---$/ {exit}
       infm && /^tools:/ {sub(/^tools:[[:space:]]*/,""); print; exit}' "$1" \
    | sed -E 's/^\[//; s/\]$//' | tr ',' '\n' \
    | sed -E "s/^[[:space:]'\"]+//; s/[[:space:]'\"]+$//" | awk 'NF'
}

# Explicit map Copilot category -> Claude equivalents (one is enough).
map_copilot_category_to_claude() {
  case "$1" in
    read)    echo "Read" ;;
    search)  echo "Grep Glob" ;;
    edit)    echo "Edit Write" ;;
    web)     echo "WebFetch WebSearch" ;;
    todo)    echo "TodoWrite" ;;
    execute) echo "Bash" ;;
    *)       echo "" ;;
  esac
}

for plugin_dir in plugins/*/; do
  plugin="$(basename "$plugin_dir")"

  # Agent Plugins 1.0 puts the Copilot components in com.github.copilot/; the
  # legacy path is accepted only for plugins that have not migrated yet.
  cop_agent="$(find "$plugin_dir/com.github.copilot/agents" "$plugin_dir/agents" -maxdepth 1 -name '*.agent.md' 2>/dev/null | head -1 || true)"
  cla_agent="$(find "$plugin_dir/claude/agents" -maxdepth 1 -name '*.md' 2>/dev/null | head -1 || true)"
  cop_prompt="$(find "$plugin_dir/com.github.copilot/commands" "$plugin_dir/prompts" -maxdepth 1 -name '*.md' 2>/dev/null | head -1 || true)"
  cla_cmd="$(find "$plugin_dir/claude/commands" -maxdepth 1 -name '*.md' 2>/dev/null | head -1 || true)"

  # A skill-only plugin has no entry points to compare.
  if [ -z "$cop_agent" ] && [ -z "$cla_agent" ] && [ -z "$cop_prompt" ] && [ -z "$cla_cmd" ]; then
    ok "$plugin" "skill-only plugin: entry point parity does not apply"
    continue
  fi

  # --- 1. rulebook parity ---
  if [ -n "$cop_agent" ] && [ -n "$cla_agent" ]; then
    if diff -u \
        <(extract_body "$cop_agent" | trim_trailing_blank) \
        <(extract_body_without_claude_tail "$cla_agent" | trim_trailing_blank) >/tmp/parity.$$ 2>&1; then
      ok "$plugin" "Copilot and Claude rulebooks identical"
    else
      err "$plugin" "the rulebooks diverge ($cop_agent vs $cla_agent):"
      sed 's/^/        /' /tmp/parity.$$ >&2
    fi
    rm -f /tmp/parity.$$
  elif [ -n "$cop_agent" ] || [ -n "$cla_agent" ]; then
    err "$plugin" "only one of the two rulebooks exists; they must come as a pair"
  fi

  # --- 2. thin launchers ---
  for launcher in "$cop_prompt" "$cla_cmd"; do
    [ -n "$launcher" ] || continue
    if extract_body "$launcher" | grep -Eq "$RULE_HEADINGS"; then
      err "$plugin" "$(basename "$launcher"): a launcher cannot carry rule sections"
    fi
    # Markdown links to .md files outside its own directory: nobody resolves them at runtime.
    if extract_body "$launcher" | grep -oE '\]\([^)]+\.md[^)]*\)' | grep -q '\.\./'; then
      err "$plugin" "$(basename "$launcher"): links to markdown outside its directory; no client resolves it at runtime"
    fi
  done
  [ -z "$cop_prompt" ] && [ -z "$cla_cmd" ] || ok "$plugin" "launchers without rules or external links"

  # --- 3. wiring ---
  if [ -n "$cop_prompt" ] && [ -n "$cop_agent" ]; then
    declared="$(extract_fm_value "$cop_prompt" agent)"
    expected="$(extract_fm_value "$cop_agent" name)"
    if [ "$declared" = "$expected" ] && [ -n "$expected" ]; then
      ok "$plugin" "the Copilot prompt delegates to '$expected'"
    else
      err "$plugin" "the Copilot prompt declares agent:'$declared' but the agent is named '$expected'"
    fi
  fi
  if [ -n "$cla_cmd" ] && [ -n "$cla_agent" ]; then
    expected="$(extract_fm_value "$cla_agent" name)"
    if [ -n "$expected" ] && extract_body "$cla_cmd" | grep -q "$expected"; then
      ok "$plugin" "the Claude command delegates to '$expected'"
    else
      err "$plugin" "the Claude command does not name the subagent '$expected' in its body"
    fi
  fi

  # --- 4. tool coverage ---
  if [ -n "$cop_agent" ] && [ -n "$cla_agent" ]; then
    claude_tools="$(extract_tools "$cla_agent" | tr '\n' ' ')"
    missing=0
    while IFS= read -r category; do
      [ -n "$category" ] || continue
      equivalents="$(map_copilot_category_to_claude "$category")"
      if [ -z "$equivalents" ]; then
        err "$plugin" "Copilot tool category with no mapping defined: '$category'"
        missing=1; continue
      fi
      found=0
      for e in $equivalents; do
        case " $claude_tools " in *" $e "*) found=1; break ;; esac
      done
      if [ "$found" -eq 0 ]; then
        err "$plugin" "Copilot grants '$category' but the Claude subagent has none of: $equivalents"
        missing=1
      fi
    done < <(extract_tools "$cop_agent")
    [ "$missing" -eq 0 ] && ok "$plugin" "equivalent tool coverage across clients"
  fi
done

echo
if [ "$ERRORS" -eq 0 ]; then
  echo "Entry point parity OK."
else
  printf 'Entry point parity: %d error(s).\n' "$ERRORS" >&2
  exit 1
fi
