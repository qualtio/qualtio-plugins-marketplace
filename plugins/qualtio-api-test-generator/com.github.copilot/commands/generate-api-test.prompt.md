---
name: Generate API Test
description: "Generates REST API integration or contract tests reusing the repository conventions and the OpenAPI specification when one exists."
argument-hint: "Service or repository, endpoint or flow, test type (integration or contract) and OpenAPI specification if available"
agent: qualtio-api-test-generator
---

# Generate API Test

Generates a scoped API test for the requested behavior. All routing, framework, dependency, validation and report rules belong to the `qualtio-api-test-generator` agent this prompt delegates to.

Use this request as input:

```text
${input:request:Endpoint or OpenAPI specification if available, test type (integration or contract) and repository conventions}
```

Valid request forms:

```text
/Generate API Test integration, cover GET /orders/{id} in the orders service using the current repository conventions.
```

```text
/Generate API Test contract, validate POST /payments against the OpenAPI specification in docs/openapi.yaml.
```

```text
/Generate API Test integration, use this Swagger as the source of truth and cover customer registration: http://localhost:8080/swagger-ui/index.html
```

```text
/Generate API Test contract, cover GET /orders. I also mention frontend cleanup, but keep the request strictly within the scope of API tests.
```
