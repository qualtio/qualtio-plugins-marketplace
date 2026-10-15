# qualtio-api-test-generator

Generates REST API **integration** and **contract** tests, detecting the repository stack and reusing its conventions. When an OpenAPI specification exists, it is used as the source of truth.

It is a complete multi-client plugin: one shared skill and native entry points in each client.

## Structure

```text
qualtio-api-test-generator/
├── plugin.json                    # Copilot: Agent Plugins 1.0 manifest ($schema)
├── .claude-plugin/plugin.json     # Claude: its own manifest (the only path it reads)
├── com.github.copilot/
│   ├── agents/*.agent.md          # Copilot: self-contained RULEBOOK
│   └── commands/*.prompt.md       # Copilot: LAUNCHER, delegates via frontmatter `agent:`
├── claude/
│   ├── agents/*.md                # Claude: RULEBOOK, mirror of the Copilot one
│   └── commands/*.md              # Claude: LAUNCHER
└── skills/api-test-generation/    # SHARED: single source of truth
    ├── SKILL.md
    ├── references/                # stack-detection, reporting, openapi-contract
    └── assets/                    # test templates
```

### Launcher → rulebook architecture

```text
Copilot:  com.github.copilot/commands/*.prompt.md ──(frontmatter `agent:`)──▶ com.github.copilot/agents/*.agent.md
Claude:   claude/commands/*.md ────────────────────(instructed delegation)──▶ claude/agents/*.md
                                                                                │
                                                                both load ──────┴──▶ skills/api-test-generation/
```

The **launchers** carry no rules: they only collect the request and delegate. The **rulebooks** are self-contained because no client resolves markdown links at runtime. The **domain rules** live in the skill, which does resolve its internal links.

The two rulebooks must be byte-for-byte identical in their body, except for the final section that belongs to the Claude subagent. `scripts/check-entrypoint-parity.sh` verifies it.

## Installation

```bash
claude plugin install qualtio-api-test-generator@qualtio-plugins-marketplace
copilot plugin install qualtio-api-test-generator@qualtio-plugins-marketplace
```

## Usage

**Claude Code**

```text
/generate-api-test integration, cover GET /orders/{id} in the orders service.
/generate-api-test contract, validate POST /payments against docs/openapi.yaml.
```

The subagent can also be invoked directly with `@agent-qualtio-api-test-generator:qualtio-api-test-generator`, or auto-delegation can activate it based on its `description`.

**Copilot**

Select the `Generate API Test` prompt, or the `qualtio-api-test-generator:qualtio-api-test-generator` agent.

## The two test types

| Type | What it validates | Source of truth |
| --- | --- | --- |
| `integration` | That the service responds as expected over HTTP | Repository conventions, and OpenAPI if it exists |
| `contract` | That responses comply with the declared schema, status codes and fields | **Mandatory**: OpenAPI specification |

If `contract` is requested and no specification can be located, the plugin stops and asks for it. A contract test without a contract is not a contract test.

## Behavior guarantees

- Detects the stack before generating and reuses the existing HTTP client, assertions, fixtures and structure.
- Marks every generated test with the stack's `AI_SUPPORTED` convention, so it can be told apart later.
- Runs the narrowest validation command that covers what was generated, not the full suite.
- One file per resource when the change spans several controllers.
- Final report with a fixed structure, including the `Validation command:` line right after the tests table.
- Never invents endpoints, payloads or response codes.

## Known asymmetry between clients

The Copilot agent uses `disable-model-invocation: true`: it never triggers on its own. Claude has no equivalent field for subagents, so the subagent keeps auto-delegation **and** manual invocation at the same time. This is a deliberately accepted divergence; the only filter against unwanted activations is the precision of its `description`.
