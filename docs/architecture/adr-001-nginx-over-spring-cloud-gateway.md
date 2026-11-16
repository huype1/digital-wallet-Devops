# ADR-001: Nginx over Spring Cloud Gateway

- **Status:** Accepted (2026-11-16)
- **Context:** The platform needs an edge gateway routing `/api/**` to the three services. Candidates: Spring Cloud Gateway (JVM, programmable filters) and Nginx.
- **Decision:** Use **Nginx** as the API gateway: static routing, timeouts, passive health checks at the edge. No business logic at the gateway.
- **Consequences:**
  - Circuit breakers live in the services (ADR-008), not at the edge.
  - Nginx stays dumb: config is routing + timeouts only (§5.1, §7).
  - A Spring Cloud Gateway swap-in remains possible if edge-level breakers or custom filters ever become necessary (§12).
