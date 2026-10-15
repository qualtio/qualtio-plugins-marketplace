# qualtio plugins marketplace

[qualtio](https://qualt.io)'s plugin marketplace, compatible with **GitHub Copilot** (CLI and VS Code) and **Claude Code**.

A marketplace is a versioned catalog of plugins. You add it once, browse what is published and from there install, update or uninstall plugins from any of the three clients.

## Contents

- [Published plugins](#published-plugins)
- [Quick reference](#quick-reference)
- [Using it from Claude Code](#using-it-from-claude-code)
- [Using it from Copilot CLI](#using-it-from-copilot-cli)
- [Using it from VS Code](#using-it-from-vs-code)
- [Repository structure](#repository-structure)
- [Validation](#validation)
- [License](#license)
- [References](#references)

## Published plugins

| Plugin | What it does | Surface |
| --- | --- | --- |
| [`qualtio-conventional-commits`](plugins/qualtio-conventional-commits/) | Writes commit messages that follow Conventional Commits from the staged changes in git | Shared skill |
| [`qualtio-api-test-generator`](plugins/qualtio-api-test-generator/) | Generates REST API integration and contract tests reusing the conventions of the repository | Shared skill + Copilot agent and prompt + Claude subagent and command |

The first one is the **minimum viable plugin**: a single skill and a single manifest that serves both ecosystems. The second one is the **complete multi-client plugin**, with native entry points in each client.

## Quick reference

| Action | Claude Code | Copilot CLI |
| --- | --- | --- |
| Add the marketplace | `claude plugin marketplace add qualtio/qualtio-plugins-marketplace` | `copilot plugin marketplace add https://github.com/qualtio/qualtio-plugins-marketplace.git` |
| Browse the catalog | `claude plugin marketplace list` | `copilot plugin marketplace browse qualtio-plugins-marketplace` |
| Install a plugin | `claude plugin install <plugin>@qualtio-plugins-marketplace` | `copilot plugin install <plugin>@qualtio-plugins-marketplace` |
| List installed plugins | `claude plugin list` | `copilot plugin list` |
| Update | `claude plugin update <plugin>@qualtio-plugins-marketplace` | `copilot plugin update <plugin>@qualtio-plugins-marketplace` |
| Uninstall | `claude plugin uninstall <plugin>` | `copilot plugin uninstall <plugin>@qualtio-plugins-marketplace` |

## Using it from Claude Code

Requirements: Claude Code and Git on your `PATH`.

```bash
claude plugin marketplace add qualtio/qualtio-plugins-marketplace   # owner/repo shortcut for GitHub
claude plugin marketplace list                                      # confirms it was registered

claude plugin install qualtio-api-test-generator@qualtio-plugins-marketplace
claude plugin list
```

After installing, the plugin exposes in Claude Code:

- the `/generate-api-test` command
- the `qualtio-api-test-generator` subagent
- the `api-test-generation` skill, which activates on its own when the context fits

Update and uninstall:

```bash
claude plugin update qualtio-api-test-generator@qualtio-plugins-marketplace   # requires restarting the session
claude plugin uninstall qualtio-api-test-generator
```

> The versioned cache survives uninstalling. If you change the content without bumping the version, purge it by hand:
> `rm -rf ~/.claude/plugins/cache/qualtio-plugins-marketplace/<plugin>`

## Using it from Copilot CLI

Requirements: GitHub Copilot CLI and Git on your `PATH`.

```bash
copilot plugin marketplace add https://github.com/qualtio/qualtio-plugins-marketplace.git
copilot plugin marketplace list
copilot plugin marketplace browse qualtio-plugins-marketplace

copilot plugin install qualtio-api-test-generator@qualtio-plugins-marketplace
copilot plugin list
```

The plugin exposes in Copilot:

- the `qualtio-api-test-generator:qualtio-api-test-generator` agent
- the `Generate API Test` prompt
- the `api-test-generation` skill

## Using it from VS Code

Copilot's plugin marketplace support in VS Code is in preview.

1. Enable plugins in [`chat.plugins.enabled`](vscode://settings/chat.plugins.enabled).
2. Add the repository URL to [`chat.plugins.marketplaces`](vscode://settings/chat.plugins.marketplaces):

   ```json
   "chat.plugins.marketplaces": [
     "https://github.com/qualtio/qualtio-plugins-marketplace.git"
   ]
   ```

3. Command Palette → **Chat: Manage Plugin Marketplaces** → select `qualtio-plugins-marketplace` and install.
4. To force a check for updates: **Chat: Update Plugins**.

Two details that often surprise:

- Registering the marketplace in Copilot CLI does **not** register it in VS Code: each client keeps its own configuration.
- VS Code **does** discover the plugins already installed by Copilot CLI from the local directory of installed plugins.

## Repository structure

```text
.
├── .claude-plugin/
│   └── marketplace.json              # single catalog: read by all three clients
├── plugins/
│   ├── qualtio-conventional-commits/ # minimum viable plugin
│   │   ├── plugin.json               # Copilot: Agent Plugins 1.0 manifest ($schema)
│   │   ├── .claude-plugin/plugin.json# Claude: its own manifest (the only path it reads)
│   │   └── skills/conventional-commits/SKILL.md
│   └── qualtio-api-test-generator/   # complete multi-client plugin
│       ├── plugin.json               # Copilot: Agent Plugins 1.0 manifest ($schema)
│       ├── .claude-plugin/plugin.json# Claude: its own manifest (the only path it reads)
│       ├── com.github.copilot/       # Copilot: everything client-specific
│       │   ├── agents/*.agent.md     #   RULEBOOK
│       │   └── commands/*.prompt.md  #   LAUNCHER, delegates via the `agent:` frontmatter
│       ├── claude/                   # Claude: everything client-specific
│       │   ├── agents/*.md           #   RULEBOOK, mirror of the Copilot one
│       │   └── commands/*.md         #   LAUNCHER
│       └── skills/                   # SHARED: single source of truth (and mcp.json if there is an MCP server)
├── scripts/
│   ├── validate.sh                   # static validation (includes the Copilot surface)
│   └── check-entrypoint-parity.sh    # rulebook and launcher parity
└── .githooks/pre-commit
```

## Validation

Two independent static checks. They can be run separately and in any order:

```bash
./scripts/validate.sh --strict          # does this load correctly in every client?
./scripts/check-entrypoint-parity.sh    # does it behave the same in both?
```

`validate.sh` checks conformance with the specification: manifests, paths, names and frontmatter. It chains `claude plugin validate --strict` and adds the checks of the Copilot surface, which no official tool covers because `copilot plugin` has no `validate` subcommand.

`check-entrypoint-parity.sh` checks something no manifest validator can see: that a plugin that loads fine in both clients behaves the same in both. It only applies to multi-client plugins.

The details of both, with what each one checks and why, are in [scripts/README.md](scripts/README.md).

To run both before every commit, enable the hook once per clone, from the repository root:

```bash
git config --local core.hooksPath .githooks
```

> Do not set it with `--global`: `.githooks` is a path relative to each repository and would point to a nonexistent folder in every other one, silently disabling their hooks.

## License

[MIT](LICENSE).

## References

**Claude Code**

- [Create plugins](https://code.claude.com/docs/en/plugins)
- [Plugins reference](https://code.claude.com/docs/en/plugins-reference)
- [Create and distribute a marketplace](https://code.claude.com/docs/en/plugin-marketplaces)

**GitHub Copilot**

- [Creating a plugin for Copilot CLI](https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/plugins-creating)
- [Creating a marketplace for Copilot CLI](https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/plugins-marketplace)
- [Copilot CLI plugin reference](https://docs.github.com/en/copilot/reference/copilot-cli-reference/cli-plugin-reference)
- [Agent plugins in VS Code](https://code.visualstudio.com/docs/copilot/customization/agent-plugins)
