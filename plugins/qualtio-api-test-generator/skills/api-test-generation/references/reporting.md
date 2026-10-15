# Report structure

The final report is mandatory and its structure is fixed. Do not replace it with free prose, do not translate it and do not reorder the sections.

## Exact structure

```markdown
## Summary

<One or two sentences: what has been covered and against which source of truth.>

## Generated tests

| File | Type | Endpoint | Coverage |
| --- | --- | --- | --- |
| ... | API integration / API contract | ... | ... |

Validation command: `<scoped command>`

## Validation result

<Summarized output: green, or the specific failure and how it was fixed.>

## Out of scope

<What was requested and has not been done, and why. Write "None" if not applicable.>
```

## Rules

- The `Validation command:` line goes **immediately after** the `Generated tests` table, with no line of text in between.
- The `Type` column uses user-facing descriptive labels: `API integration` or `API contract`. Never the internal identifiers `integration` or `contract`.
- If no test has been generated, the table is kept with a single row that says `None`, and the validation line is `Validation command: n/a`.
- If a single change affects several resources or controllers, generate **one file per resource** and one row per file. Do not group them into a single new file.
- `Out of scope` is never omitted. If there is nothing, write `None`.
