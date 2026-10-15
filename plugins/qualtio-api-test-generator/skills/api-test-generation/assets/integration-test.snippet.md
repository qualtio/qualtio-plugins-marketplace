# Template: API integration test (JVM / REST Assured / JUnit 5)

Adapt names, package and configuration to the repository. Do not copy the template if the repository already has its own style: in that case follow it.

```java
package com.example.orders.api;

import io.restassured.http.ContentType;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.Test;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.equalTo;
import static org.hamcrest.Matchers.notNullValue;

class OrdersApiIT extends ApiIntegrationTestSupport {

    @Test
    @Tag("AI_SUPPORTED")
    @DisplayName("Fetching an existing order returns its data")
    void getExistingOrderReturnsOrderData() {
        given()
            .spec(requestSpec())
            .pathParam("id", seededOrderId())
        .when()
            .get("/orders/{id}")
        .then()
            .statusCode(200)
            .contentType(ContentType.JSON)
            .body("id", equalTo(seededOrderId()))
            .body("status", notNullValue());
    }

    @Test
    @Tag("AI_SUPPORTED")
    @DisplayName("Fetching a missing order returns 404")
    void getMissingOrderReturnsNotFound() {
        given()
            .spec(requestSpec())
            .pathParam("id", "00000000-0000-0000-0000-000000000000")
        .when()
            .get("/orders/{id}")
        .then()
            .statusCode(404);
    }
}
```

Points to respect:

- Reuse the existing support base class and `RequestSpecification`. Do not rebuild host, port and authentication configuration in every test.
- One business-oriented `@DisplayName` per method.
- `@Tag("AI_SUPPORTED")` on every generated method.
- Cover the happy path and at least one declared error case.
