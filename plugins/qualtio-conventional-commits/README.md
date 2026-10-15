# qualtio-conventional-commits

Writes commit messages that follow [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/) from the changes staged in the git index.

It is the **minimal example** of the marketplace: a single skill, shared by Copilot and Claude Code, and one manifest per client.

## Why two manifests

The root `plugin.json` follows the open [Agent Plugins 1.0](https://agent-plugins.org) specification: `$schema`, `name`, `version`, `description` and little else. Copilot reads it as a specification plugin and discovers the skill in `skills/`. Copilot would also work without that file, because it falls back to `.claude-plugin/plugin.json` as a legacy plugin, but that is the format the Copilot documentation no longer recommends.

Claude Code does not implement the specification and only reads `.claude-plugin/plugin.json`. The `category` field is declared in the marketplace entry, not in the manifests: `claude plugin validate` warns if it appears in its manifest and the Agent Plugins schema does not allow it in the other one.

## Structure

```text
qualtio-conventional-commits/
├── plugin.json                    # Copilot: Agent Plugins 1.0
├── .claude-plugin/plugin.json     # Claude
└── skills/conventional-commits/SKILL.md
```

## Installation

```bash
claude plugin install qualtio-conventional-commits@qualtio-plugins-marketplace
copilot plugin install qualtio-conventional-commits@qualtio-plugins-marketplace
```

## Usage

Stage the changes and ask for the message:

```bash
git add -p
```

In Claude Code the skill activates on its own when you ask for a commit, or explicitly:

```text
/qualtio-conventional-commits:conventional-commits
```

## Behavior

- Reads `git diff --staged`. If the index is empty, it says so and stops: it does not run `git add` on its own.
- Returns the message in a code block. It does not run `git commit` unless explicitly asked.
- If the diff mixes several purposes, it proposes splitting it into several commits.
- Writes in the language that predominates in the repository history.
