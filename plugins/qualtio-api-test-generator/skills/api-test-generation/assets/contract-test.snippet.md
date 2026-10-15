# Template: contract test against OpenAPI (JVM / REST Assured / JUnit 5)

Schema validation is delegated to an OpenAPI validator, not to hand-written field-by-field assertions.

```java
package com.example.orders.api;

import com.atlassian.oai.validator.restassured.OpenApiValidationFilter;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.Test;

import static io.restassured.RestAssured.given;

class OrdersContractTest extends ApiContractTestSupport {

    private static final OpenApiValidationFilter VALIDATION_FILTER =
        new OpenApiValidationFilter("docs/openapi.yaml");

    @Test
    @Tag("AI_SUPPORTED")
    @DisplayName("GET /orders/{id} complies with the contract declared in OpenAPI")
    void getOrderMatchesDeclaredContract() {
        given()
            .spec(requestSpec())
            .filter(VALIDATION_FILTER)
            .pathParam("id", seededOrderId())
        .when()
            .get("/orders/{id}")
        .then()
            .statusCode(200);
    }
}
```

Points to respect:

- The specification path is not copied into every test: extract it to a constant or to the support class.
- The validation filter fails the test if the response code is not declared or if the body does not validate against the schema. That is the main assertion; do not duplicate it by hand.
- If the repository does not use the JVM, apply the equivalent from its ecosystem (for example a JSON schema validator fed with the specification) while keeping the same principle: the specification validates, not the developer.
