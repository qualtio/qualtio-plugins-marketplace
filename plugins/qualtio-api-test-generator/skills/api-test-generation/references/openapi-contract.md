# Contract tests against OpenAPI

Only for the `contract` path. Requires a locatable OpenAPI specification.

## Locating the specification

In order:

1. Path given by the user.
2. Repository files: `openapi.yaml`, `openapi.json`, `swagger.yaml`, or inside `docs/`, `api/`, `spec/`, `src/main/resources/`.
3. Endpoint served by the service: `/v3/api-docs`, `/swagger.json`, `/openapi.json`.

If it does not appear in any of the three, stop and ask the user for it.

## What a contract test validates

For each covered operation:

- The response code is **declared** in the specification for that operation.
- The response body validates against the declared schema.
- Fields marked as `required` are present and not null.
- Types and formats match what is declared (`string`, `integer`, `date-time`, `uuid`...).
- Values of an `enum` belong to the declared set.
- Headers declared as required are present.

## What a contract test does NOT validate

- Business rules.
- Concrete data values, unless the specification fixes them with `enum` or `const`.
- Performance.

If the user asks to validate business rules, that is the `integration` path. Say so and route accordingly.

## Drift between code and specification

If you detect that the service returns something the specification does not declare:

- **do not adjust the test to the actual behavior of the service**,
- generate the test against the specification,
- and record the discrepancy in the `Out of scope` section of the report.

The specification is the contract. A test that adapts to the violation stops detecting it.
