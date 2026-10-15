---
description: "Generates REST API integration or contract tests reusing the repository conventions and the OpenAPI specification when one exists."
argument-hint: "Service or repository, endpoint or flow, test type (integration or contract) and OpenAPI specification if available"
---

# Generate API Test

This command is a launcher. All routing, framework, dependency, validation and report rules belong to the `qualtio-api-test-generator` subagent: do not generate, edit or validate any test yourself in the main conversation.

1. If the request below is empty or contains only whitespace, ask the user once for the minimum routing data (repository or service, test type integration or contract, endpoint or flow, source of truth if one exists) before delegating.
2. Delegate to the `qualtio-api-test-generator` subagent through the agent tool. The subagent starts with no history, so the delegation message must contain the request below verbatim plus any routing context the user has already given in this conversation.
3. Return the subagent's final report to the user unchanged. Do not summarize it, do not translate it and do not alter its structure.

Use this request as input:

```text
$ARGUMENTS
```

Valid request forms:

```text
/generate-api-test integration, cover GET /orders/{id} in the orders service using the current repository conventions.
```

```text
/generate-api-test contract, validate POST /payments against the OpenAPI specification in docs/openapi.yaml.
```

```text
/generate-api-test integration, use this Swagger as the source of truth and cover customer registration: http://localhost:8080/swagger-ui/index.html
```

```text
/generate-api-test contract, cover GET /orders. I also mention frontend cleanup, but keep the request strictly within the scope of API tests.
```
