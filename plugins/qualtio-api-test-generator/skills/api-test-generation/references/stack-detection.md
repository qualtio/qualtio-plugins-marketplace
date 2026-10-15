# Stack detection

Detect the stack before generating anything. The goal is to **reuse**, not to impose.

## Detection order

1. Build file at the root and in the affected module:
   - `pom.xml` or `build.gradle` → JVM
   - `package.json` → Node
   - `pyproject.toml`, `requirements.txt` → Python
   - `go.mod` → Go
   - `*.csproj` → .NET
2. API tests already present in the repository. They outweigh any default: if there is already a style, follow that style.
3. Continuous integration configuration, to infer the real validation command used in the project.

## What to always reuse

- HTTP client and assertion library already present.
- Fixtures, data factories, request builders and authentication helpers.
- Folder structure and naming convention of the existing tests.
- Profiles, environment variables and service startup configuration in tests.

## Defaults when the repository has no API tests

Use them only if there is nothing to reuse, and state in the report that you have introduced a framework.

| Stack | HTTP client | Runner | AI_SUPPORTED mark |
| --- | --- | --- | --- |
| JVM | REST Assured | JUnit 5 | `@Tag("AI_SUPPORTED")` |
| Node | supertest or native fetch | Vitest or Jest | `[AI_SUPPORTED]` label in the test name |
| Python | httpx | pytest | `@pytest.mark.ai_supported` marker |
| Go | net/http/httptest | testing | `// AI_SUPPORTED` comment above the function |
| .NET | HttpClient | xUnit | `[Trait("AI_SUPPORTED", "true")]` |

## Scoped validation command

Choose the narrowest command that runs only what was generated:

| Stack | Example |
| --- | --- |
| Maven | `mvn test -Dtest=OrdersApiIT` |
| Gradle | `gradle test --tests '*OrdersApiIT'` |
| Node | `npx vitest run tests/api/orders.spec.ts` |
| Python | `pytest tests/api/test_orders.py` |
| Go | `go test ./internal/api -run TestOrders` |
| .NET | `dotnet test --filter FullyQualifiedName~OrdersApi` |
