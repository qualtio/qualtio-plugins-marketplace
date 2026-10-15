# Changelog

## [1.0.0] - 2026-10-15

First published version.

- Shared skill `api-test-generation`: REST API integration and contract tests, stack detection, reuse of repository conventions and OpenAPI as the source of truth when it exists. Final report with a fixed structure including the `Validation command:` line.
- Native entry points in each client: Copilot agent and prompt in `com.github.copilot/`, Claude subagent and command in `claude/`. Mirrored rulebooks, launchers that only delegate.
- Copilot side conforming to Agent Plugins 1.0 (root `plugin.json` with `$schema`); Claude side with `.claude-plugin/plugin.json`.
