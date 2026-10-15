# Scripts

Two **independent** static validations. Neither installs plugins, neither loads anything at runtime and neither runs a model: both work on the files in the repository.

They can be run separately and in any order. The pre-commit hook runs both because this repository needs both, but they do not depend on each other.

| Script | What it validates | Scope |
| --- | --- | --- |
| [`validate.sh`](validate.sh) | Conformance with the specification: manifests, paths, names and frontmatter | Every plugin |
| [`check-entrypoint-parity.sh`](check-entrypoint-parity.sh) | Consistency between the two client surfaces of the same plugin | Multi-client plugins only |

---

## `validate.sh`

It answers one question: **does this load correctly in every client?**

It combines two layers:

1. `claude plugin validate --strict` on the marketplace and on every plugin in the catalog.
2. Checks of its own for the Copilot surface. `copilot plugin` has no `validate` subcommand, so no official tool covers this part.

### What it checks

For the catalog:

- `marketplace.json` is valid JSON and the official validator accepts it
- every `source` exists and starts with `./` (Claude requires it, Copilot tolerates it)

For each plugin:

- the Copilot manifest is valid JSON and has `name` and `description`
- `name` is kebab-case and matches the marketplace entry
- `version` matches between the manifest and the catalog
- the fields that declare paths (`agents`, `skills`, `commands`, `hooks`) point to something that exists
- agents are named `*.agent.md` and have `name` and `description` in the frontmatter
- prompts are named `*.prompt.md` and have `description`
- every folder in `skills/` has its `SKILL.md` with `description`
- `.mcp.json`, if present, declares consistent servers: valid names, an explicit `type` and an https URL for remote ones, and never `url` and `command` at the same time

A plugin that only ships skills does not need a Copilot manifest at the root: the script detects that and does not require it. It only asks for one if there is an `agents/` or `prompts/` folder.

### Severities

- `ERROR`: always fails.
- `WARNING`: reported, and does not fail unless `--strict` is used.

### Usage

```bash
./scripts/validate.sh                                 # the whole catalog
./scripts/validate.sh --strict                        # warnings as errors
./scripts/validate.sh --plugin qualtio-api-test-generator
./scripts/validate.sh --quiet
```

Exit code `0` if it passes, `1` if it fails.

### Dependencies

`claude` and `jq` on the `PATH`. Claude's static validator does not need a signed-in session, only the binary.

---

## `check-entrypoint-parity.sh`

It answers a different question: **does it behave the same in both clients?**

A plugin can load perfectly in Copilot and in Claude and still behave differently in each. No manifest validator detects that, because it is not a structure problem.

It only applies to multi-client plugins. If a plugin has no client-specific entry points, the script says so and moves on.

### Why it is needed

The two clients require different formats and paths for an agent's rulebook, and there is no include mechanism between files: markdown links are not resolved at runtime. That forces you to **keep the same text duplicated in two files**.

That duplication is not a design decision, it is imposed by the platform. And two files that must be identical and that nobody watches drift apart. When they drift, the plugin answers differently depending on the client and nothing flags it.

### What it checks

**Rulebook parity.** The markdown body of `agents/*.agent.md` and that of `claude/agents/*.md` must be byte-for-byte identical, except that the Claude one may end with `## If the delegation message lacks detail` (subagents start without conversation history and need that instruction; the Copilot agent does not). If they diverge, it prints the diff.

**Delegation wiring.** The `agent:` in the frontmatter of the Copilot prompt must match the `name:` of its agent, and the body of the Claude command must name its subagent.

This is the check that most justifies the script. If `agent:` does not match, Copilot **does not delegate**: the prompt still runs, without any of the agent's rules, and the answer looks reasonable. There is no error in any log.

**Thin launchers.** Launchers must not carry behavior-rule sections, and must not link markdown outside their directory. No client resolves such a link, so it would be a rule the model never sees.

**Tool coverage.** Every category granted in Copilot must have a granted equivalent in Claude. The two use different vocabularies with no structural way to compare them, so the mapping is explicit:

| Copilot | Claude |
| --- | --- |
| `read` | `Read` |
| `search` | `Grep` or `Glob` |
| `edit` | `Edit` or `Write` |
| `web` | `WebFetch` or `WebSearch` |
| `todo` | `TodoWrite` |
| `execute` | `Bash` |

If you add a new category to a Copilot agent, it needs its equivalent in the map or the script fails, warning that it does not know how to translate it.

### Usage

```bash
./scripts/check-entrypoint-parity.sh
```

It has no options. It walks every plugin in the repository. Exit code `0` if it passes, `1` if it fails.

---

## Pre-commit hook

[`.githooks/pre-commit`](../.githooks/pre-commit) runs both in strict mode. Enable it once per clone, from the repository root:

```bash
git config --local core.hooksPath .githooks
```

> Do not set it with `--global`: `.githooks` is a path relative to each repository and would point to a nonexistent folder in every other one, silently disabling their hooks.
