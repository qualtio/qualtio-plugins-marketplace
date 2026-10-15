---
name: conventional-commits
description: "Writes a commit message that follows the Conventional Commits specification from the changes staged in the git index. Use it when the user asks to write a commit, generate a commit message, fix the format of a commit or prepare a changelog entry."
argument-hint: "Optional: scope or additional context about the change"
user-invocable: true
---

# Conventional Commits

Write a commit message for the changes that are already in the git index.

## Procedure

1. Read the staged changes with `git diff --staged`. If the index is empty, tell the user and stop: do not propose a message for unstaged changes and do not run `git add` on your own.
2. Determine the **type** from the nature of the change, not from the user's words.
3. Determine the **scope** from the area of the code touched. Omit it if the change is cross-cutting.
4. Write the subject in the imperative, in lowercase and without a trailing period, with a maximum of 72 characters.
5. Add a body only if the change needs to explain the *why*. The *what* is already in the diff.
6. Return the message inside a code block ready to copy. Do not run `git commit` unless the user explicitly asks for it.

## Format

```text
<type>(<scope>): <subject>

<optional body>

<optional footer>
```

## Allowed types

| Type | When to use it |
| --- | --- |
| `feat` | New user-visible functionality |
| `fix` | Correction of a defect |
| `docs` | Documentation only |
| `style` | Formatting without behavior change |
| `refactor` | Restructuring without change in behavior or functionality |
| `perf` | Performance improvement |
| `test` | Adding or fixing tests |
| `build` | Build system or dependencies |
| `ci` | Continuous integration configuration |
| `chore` | Maintenance that fits nowhere else |
| `revert` | Reverting a previous commit |

## Breaking changes

An incompatible change is marked in **both** ways:

- `!` before the colon: `feat(api)!: remove the v1 users endpoint`
- `BREAKING CHANGE:` footer explaining the migration

## Rules

- One commit, one purpose. If the diff mixes several purposes, propose splitting it into several commits instead of forcing a single message.
- Do not invent issue numbers or ticket references. If the user provides them, put them in the footer as `Refs: ABC-123`.
- Write the message in the language that predominates in the repository history. If the history is empty or ambiguous, use English.
- Do not include file names in the subject: the diff already provides that.

## Examples

```text
feat(auth): add silent renewal of the session token

The client logged the user out when the token expired even if the
user was still active. It is now renewed in the background 60s
before expiry.

Refs: PLAT-482
```

```text
fix(uploads): reject files that exceed the declared limit

BREAKING CHANGE: requests that exceed max-file-size now respond
413 instead of 200 with an empty body.
```

```text
refactor(orders): extract the totals calculation into its own service
```
