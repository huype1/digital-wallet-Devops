# ADR-002: Keycloak over hand-rolled auth

- **Status:** Accepted (2026-11-16)
- **Context:** The platform needs OAuth2/OIDC token issuance, login/registration flows, password reset, and an admin UI. Hand-rolling auth is high-risk and slow to get right.
- **Decision:** Use **Keycloak** to issue JWTs. Services validate tokens locally with `spring-boot-starter-oauth2-resource-server` (stateless — no gateway dependency). Nginx passes JWTs through untouched (§6). Realm config is exported to `infra/keycloak/` and versioned in git.
- **Consequences:**
  - ~1 GB RAM ops overhead accepted (§12).
  - Services stay stateless; revocation/logout uses a Redis token blacklist (§6).
  - Realm changes are reviewed like code (§2) and reproducible via re-import.
