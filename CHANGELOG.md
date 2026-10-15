# Changelog

Notable changes to this marketplace. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and versioning follows [SemVer](https://semver.org/).

## [1.0.0] - 2026-10-15

First published version.

- Single catalog in `.claude-plugin/marketplace.json` that serves GitHub Copilot (CLI and VS Code) and Claude Code.
- Two plugins: `qualtio-conventional-commits` (minimal, one skill) and `qualtio-api-test-generator` (complete, multi-client).
- Copilot side conforms to Agent Plugins 1.0: root `plugin.json` with `$schema` and components under `com.github.copilot/`. Claude side under `.claude-plugin/plugin.json` and `claude/`. Shared skills.
- Static validation (`scripts/validate.sh`): `claude plugin validate --strict` plus the Copilot surface, including the Agent Plugins 1.0 manifest and `mcp.json`.
- Entry point parity (`scripts/check-entrypoint-parity.sh`): mirrored rulebooks, thin launchers, delegation wiring, equivalent tool coverage. Both run by the pre-commit hook.
- MIT license.
