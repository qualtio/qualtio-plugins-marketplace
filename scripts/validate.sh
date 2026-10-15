#!/usr/bin/env bash
#
# Static validation of the marketplace and its plugins.
#
# It combines two layers:
#   1. `claude plugin validate` for the marketplace and for each plugin.
#   2. Checks of its own for the Copilot surface, which no official tool
#      covers (`copilot plugin` has no `validate`): the Agent Plugins 1.0
#      manifest ($schema, allowed fields, components in com.github.copilot/,
#      mcp.json) or, with a warning, the legacy format.
#
# It is deliberately static: it does not install plugins, does not load them
# at runtime and does not run any model. It validates manifests, paths, names
# and frontmatter.
#
# Severities:
#   ERROR   -> always fails.
#   WARNING -> reported; promoted to an error with --strict.

if ! (eval ': < <(true)') >/dev/null 2>&1; then
  if command -v bash >/dev/null 2>&1; then exec bash "$0" "$@"; fi
  printf 'ERROR [global] Bash is required. Run: bash ./scripts/validate.sh\n' >&2
  exit 1
fi

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MANIFEST="$REPO_ROOT/.claude-plugin/marketplace.json"

STRICT=0
QUIET=0
ONLY_PLUGIN=""
ERRORS=0
WARNINGS=0

usage() {
  cat <<EOF
Usage: validate.sh [--strict] [--quiet] [--plugin NAME]

  --strict          Promote warnings to errors.
  --quiet           Reduce the informational log.
  --plugin NAME     Validate a single plugin.
  --help            Show this help.

Exit codes: 0 success, 1 failure.
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --strict) STRICT=1 ;;
    --quiet)  QUIET=1 ;;
    --plugin) ONLY_PLUGIN="${2:-}"; shift ;;
    --help|-h) usage; exit 0 ;;
    *) printf 'ERROR [args] Unknown option: %s\n' "$1" >&2; usage >&2; exit 1 ;;
  esac
  shift
done

info()  { [ "$QUIET" -eq 1 ] || printf 'INFO  [%s] %s\n' "$1" "$2"; }
err()   { ERRORS=$((ERRORS+1)); printf 'ERROR [%s] %s\n' "$1" "$2" >&2; }
warn()  {
  WARNINGS=$((WARNINGS+1))
  if [ "$STRICT" -eq 1 ]; then ERRORS=$((ERRORS+1)); printf 'ERROR [%s] %s (warning promoted by --strict)\n' "$1" "$2" >&2
  else printf 'WARN  [%s] %s\n' "$1" "$2" >&2; fi
}

# --- dependencies ------------------------------------------------------------
for dep in claude jq; do
  if ! command -v "$dep" >/dev/null 2>&1; then
    printf 'ERROR [deps] Missing "%s" in PATH.\n' "$dep" >&2
    case "$dep" in
      claude) printf 'HINT  [deps] brew install --cask claude-code\n' >&2 ;;
      jq)     printf 'HINT  [deps] brew install jq\n' >&2 ;;
    esac
    exit 1
  fi
done

[ -f "$MANIFEST" ] || { printf 'ERROR [marketplace] %s does not exist\n' "$MANIFEST" >&2; exit 1; }
jq empty "$MANIFEST" 2>/dev/null || { printf 'ERROR [marketplace] Invalid JSON in marketplace.json\n' >&2; exit 1; }

# --- layer 1: official validator --------------------------------------------
validate_with_claude() {
  local scope="$1" path="$2" out
  if out="$(claude plugin validate "$path" --strict 2>&1)"; then
    info "$scope" "claude plugin validate: OK"
  else
    err "$scope" "claude plugin validate failed:"
    printf '%s\n' "$out" | sed 's/^/        /' >&2
  fi
}

# --- layer 2: Copilot surface -----------------------------------------------
# Checks that a file has YAML frontmatter and the required keys.
check_frontmatter() {
  local scope="$1" file="$2"; shift 2
  local first; first="$(head -1 "$file")"
  if [ "$first" != "---" ]; then
    err "$scope" "$(basename "$file"): does not start with '---' frontmatter"
    return
  fi
  if ! awk 'NR>1 && $0=="---" {found=1; exit} END {exit !found}' "$file"; then
    err "$scope" "$(basename "$file"): frontmatter has no closing '---'"
    return
  fi
  local key
  for key in "$@"; do
    if ! awk -v k="$key" 'NR==1{next} /^---$/{exit} index($0, k":")==1 {found=1} END{exit !found}' "$file"; then
      err "$scope" "$(basename "$file"): missing required key '$key' in the frontmatter"
    fi
  done
}

PLUGIN_SCHEMA="https://agent-plugins.org/schemas/1.0.0/plugin.schema.json"
MCP_SCHEMA="https://agent-plugins.org/schemas/1.0.0/mcp.schema.json"
COPILOT_NS="com.github.copilot"

validate_skills() {
  local scope="$1" dir="$2"
  [ -d "$dir/skills" ] || return 0
  local d found=0
  for d in "$dir"/skills/*/; do
    [ -d "$d" ] || continue
    found=1
    case "$(basename "$d")" in _*) continue ;; esac
    if [ ! -f "$d/SKILL.md" ]; then
      err "$scope" "skills/$(basename "$d")/: missing the SKILL.md entry point"
    else
      check_frontmatter "$scope" "$d/SKILL.md" description
    fi
  done
  [ "$found" -eq 1 ] || warn "$scope" "skills/ exists but is empty"
}

# MCP servers declared in a file: consistency of 'type', 'url' and 'command'.
# $3 is the set of allowed remote types (Claude: http|sse|ws; spec: streamable-http|sse).
validate_mcp_servers() {
  local scope="$1" file="$2" remote_types="$3" label
  label="$(basename "$file")"
  jq empty "$file" 2>/dev/null || { err "$scope" "$label: invalid JSON"; return; }
  local n; n="$(jq -r '.mcpServers // {} | length' "$file")"
  [ "$n" -gt 0 ] || err "$scope" "$label: 'mcpServers' is empty or missing"
  local srv
  while IFS= read -r srv; do
    [ -n "$srv" ] || continue
    local url cmd type
    url="$(jq -r --arg s "$srv" '.mcpServers[$s].url // empty' "$file")"
    cmd="$(jq -r --arg s "$srv" '.mcpServers[$s].command // empty' "$file")"
    type="$(jq -r --arg s "$srv" '.mcpServers[$s].type // empty' "$file")"
    if [ -n "$url" ] && [ -n "$cmd" ]; then
      err "$scope" "$label '$srv': cannot declare both 'url' and 'command'"
    elif [ -n "$url" ]; then
      case "|$remote_types|" in *"|$type|"*) ;; *) err "$scope" "$label '$srv': remote server with 'type' '$type'; allowed: $remote_types" ;; esac
      case "$url" in https://*) ;; *) err "$scope" "$label '$srv': the remote url must be https" ;; esac
    elif [ -z "$cmd" ]; then
      err "$scope" "$label '$srv': declares neither 'url' nor 'command'"
    fi
  done < <(jq -r '.mcpServers // {} | keys[]' "$file")
}

validate_manifest_identity() {
  local scope="$1" cop="$2" mp_name="$3" mp_version="$4" name_pattern="$5"
  local name version
  name="$(jq -r '.name // empty' "$cop")"
  version="$(jq -r '.version // empty' "$cop")"
  [ -n "$name" ] || err "$scope" "plugin.json: missing 'name'"
  [ -n "$(jq -r '.description // empty' "$cop")" ] || err "$scope" "plugin.json: missing 'description'"
  if [ -n "$name" ] && ! printf '%s' "$name" | grep -Eq "$name_pattern"; then
    err "$scope" "plugin.json: 'name' does not match the format pattern: $name"
  fi
  if [ -n "$name" ] && [ "$name" != "$mp_name" ]; then
    err "$scope" "plugin.json 'name' ($name) does not match the marketplace entry ($mp_name)"
  fi
  if [ -n "$version" ] && [ -n "$mp_version" ] && [ "$version" != "$mp_version" ]; then
    err "$scope" "plugin.json 'version' ($version) does not match the marketplace one ($mp_version)"
  fi
}

# Copilot components in a given directory (legacy root or com.github.copilot/).
# $3 = name of the commands directory (prompts in legacy, commands in spec).
validate_copilot_components() {
  local scope="$1" base="$2" cmd_dir="$3" prefix="$4"
  local f found
  if [ -d "$base/agents" ]; then
    found=0
    for f in "$base"/agents/*; do
      [ -e "$f" ] || continue
      found=1
      case "$f" in
        *.agent.md) check_frontmatter "$scope" "$f" name description ;;
        *) err "$scope" "${prefix}agents/: $(basename "$f") must be named *.agent.md" ;;
      esac
    done
    [ "$found" -eq 1 ] || warn "$scope" "${prefix}agents/ exists but is empty"
  fi
  if [ -d "$base/$cmd_dir" ]; then
    found=0
    for f in "$base/$cmd_dir"/*; do
      [ -e "$f" ] || continue
      found=1
      case "$f" in
        *.md) check_frontmatter "$scope" "$f" description ;;
        *) err "$scope" "${prefix}${cmd_dir}/: $(basename "$f") must be a .md file (Copilot accepts *.prompt.md and *.md)" ;;
      esac
    done
    [ "$found" -eq 1 ] || warn "$scope" "${prefix}${cmd_dir}/ exists but is empty"
  fi
}

# Agent Plugins 1.0: root manifest with $schema. Copilot stops looking at agents/ and
# prompts/ at the root and only loads its components from com.github.copilot/.
validate_copilot_spec() {
  local scope="$1" dir="$2" cop="$3" mp_name="$4" mp_version="$5"
  local schema; schema="$(jq -r '."$schema" // empty' "$cop")"
  [ "$schema" = "$PLUGIN_SCHEMA" ] || err "$scope" "plugin.json: unknown \$schema: $schema (expected $PLUGIN_SCHEMA)"

  # Only the fields of the official schema (additionalProperties: false). The legacy
  # path fields (agents, skills, commands, hooks, mcpServers) do not exist in 1.0.
  local extra
  extra="$(jq -r '[keys[] | select(. as $k | ["$schema","name","version","description","author","homepage","repository","license","keywords","extensions"] | index($k) | not)] | join(", ")' "$cop")"
  [ -z "$extra" ] || err "$scope" "plugin.json: fields not allowed by Agent Plugins 1.0: $extra"

  validate_manifest_identity "$scope" "$cop" "$mp_name" "$mp_version" '^[a-z0-9]([a-z0-9.-]*[a-z0-9])?$'
  case "$(jq -r '.name // empty' "$cop")" in *--*|*..*) err "$scope" "plugin.json: 'name' cannot contain '--' or '..'" ;; esac

  # With $schema, Copilot ignores the legacy components at the root: leaving them there
  # means having files that no client loads (Claude does not either: it uses claude/).
  local legacy
  for legacy in agents prompts hooks.json; do
    [ -e "$dir/$legacy" ] && err "$scope" "$legacy at the root: with \$schema Copilot does not load it; move it to $COPILOT_NS/"
  done
  [ -f "$dir/.mcp.json" ] && [ ! -f "$dir/mcp.json" ] && err "$scope" ".mcp.json without mcp.json: with \$schema Copilot reads mcp.json at the root"

  if [ -d "$dir/$COPILOT_NS" ]; then
    validate_copilot_components "$scope" "$dir/$COPILOT_NS" commands "$COPILOT_NS/"
    [ -f "$dir/$COPILOT_NS/hooks/hooks.json" ] && { jq empty "$dir/$COPILOT_NS/hooks/hooks.json" 2>/dev/null || err "$scope" "$COPILOT_NS/hooks/hooks.json: invalid JSON"; }
    [ -f "$dir/$COPILOT_NS/lsp.json" ] && { jq empty "$dir/$COPILOT_NS/lsp.json" 2>/dev/null || err "$scope" "$COPILOT_NS/lsp.json: invalid JSON"; }
    local entry
    for entry in "$dir/$COPILOT_NS"/*; do
      case "$(basename "$entry")" in agents|commands|rules|hooks|lsp.json) ;; *) warn "$scope" "$COPILOT_NS/$(basename "$entry"): entry that Copilot does not document" ;; esac
    done
  fi

  if [ -f "$dir/mcp.json" ]; then
    local ms; ms="$(jq -r '."$schema" // empty' "$dir/mcp.json" 2>/dev/null || true)"
    [ "$ms" = "$MCP_SCHEMA" ] || err "$scope" "mcp.json: unknown or missing \$schema (expected $MCP_SCHEMA)"
    validate_mcp_servers "$scope" "$dir/mcp.json" "streamable-http|sse"
    # If Claude has its own .mcp.json, it must declare the same servers and urls.
    if [ -f "$dir/.mcp.json" ]; then
      local a b
      a="$(jq -S '[.mcpServers // {} | to_entries[] | {name: .key, url: (.value.url // ""), command: (.value.command // "")}]' "$dir/mcp.json")"
      b="$(jq -S '[.mcpServers // {} | to_entries[] | {name: .key, url: (.value.url // ""), command: (.value.command // "")}]' "$dir/.mcp.json")"
      [ "$a" = "$b" ] || warn "$scope" "mcp.json (Copilot) and .mcp.json (Claude) declare different servers"
    fi
  fi
}

# Legacy Copilot format: plugin.json without $schema, components at the root.
validate_copilot_legacy() {
  local scope="$1" dir="$2" cop="$3" mp_name="$4" mp_version="$5"
  warn "$scope" "legacy plugin.json (no \$schema): Agent Plugins 1.0 is the format Copilot documents; migrate to com.github.copilot/"
  validate_manifest_identity "$scope" "$cop" "$mp_name" "$mp_version" '^[a-z0-9]+(-[a-z0-9]+)*$'
  local field target
  for field in agents skills commands hooks; do
    target="$(jq -r --arg f "$field" '.[$f] // empty | if type=="string" then . else empty end' "$cop")"
    [ -n "$target" ] || continue
    if [ ! -e "$dir/${target%/}" ] && [ ! -e "$dir/$target" ]; then
      err "$scope" "plugin.json '$field' points to a path that does not exist: $target"
    fi
  done
  validate_copilot_components "$scope" "$dir" prompts ""
  [ -d "$dir/$COPILOT_NS" ] && err "$scope" "$COPILOT_NS/ exists but the manifest does not declare \$schema: Copilot does not load it"
}

validate_copilot_surface() {
  local scope="$1" dir="$2" mp_name="$3" mp_version="$4"
  local cop="$dir/plugin.json"

  if [ ! -f "$cop" ]; then
    if [ -d "$dir/agents" ] || [ -d "$dir/prompts" ] || [ -d "$dir/$COPILOT_NS" ]; then
      err "$scope" "Copilot components found but the root manifest (plugin.json) is missing"
    else
      warn "$scope" "no plugin.json at the root: Copilot falls back to Claude's manifest as a legacy plugin; Agent Plugins 1.0 requires a plugin.json with \$schema"
    fi
  else
    jq empty "$cop" 2>/dev/null || { err "$scope" "plugin.json (Copilot): invalid JSON"; return; }
    if [ -n "$(jq -r '."$schema" // empty' "$cop")" ]; then
      info "$scope" "Agent Plugins 1.0 manifest"
      validate_copilot_spec "$scope" "$dir" "$cop" "$mp_name" "$mp_version"
    else
      validate_copilot_legacy "$scope" "$dir" "$cop" "$mp_name" "$mp_version"
    fi
  fi

  validate_skills "$scope" "$dir"

  # .mcp.json is what Claude reads (and legacy Copilot).
  [ -f "$dir/.mcp.json" ] && validate_mcp_servers "$scope" "$dir/.mcp.json" "http|sse|ws"
  return 0
}

# --- walk ---------------------------------------------------------------------
info marketplace "Validating $REPO_ROOT"
validate_with_claude marketplace "$REPO_ROOT"

COUNT=0
while IFS=$'\t' read -r mp_name mp_source mp_version; do
  [ -n "$mp_name" ] || continue
  if [ -n "$ONLY_PLUGIN" ] && [ "$ONLY_PLUGIN" != "$mp_name" ]; then continue; fi

  dir="$REPO_ROOT/${mp_source#./}"
  if [ ! -d "$dir" ]; then
    err "$mp_name" "the marketplace 'source' does not exist: $mp_source"
    continue
  fi
  case "$mp_source" in ./*) ;; *) warn "$mp_name" "'source' should start with './' (Claude requires it): $mp_source" ;; esac

  COUNT=$((COUNT+1))
  info "$mp_name" "Validating $dir"
  validate_with_claude "$mp_name" "$dir"
  validate_copilot_surface "$mp_name" "$dir" "$mp_name" "$mp_version"
done < <(jq -r '.plugins[] | [.name, .source, (.version // "")] | @tsv' "$MANIFEST")

if [ -n "$ONLY_PLUGIN" ] && [ "$COUNT" -eq 0 ]; then
  err args "Plugin '$ONLY_PLUGIN' does not appear in marketplace.json"
fi

echo
printf 'Summary: %d plugin(s) validated, %d error(s), %d warning(s)%s\n' \
  "$COUNT" "$ERRORS" "$WARNINGS" "$([ "$STRICT" -eq 1 ] && echo ' [--strict]')"

[ "$ERRORS" -eq 0 ] || exit 1
echo "Validation passed."
