# ADR-006: Vite + React SPA over Next.js

- **Status:** Accepted (2026-11-16)
- **Context:** The frontend is a wallet dashboard calling the API gateway. No SEO requirement, no content pages — purely authenticated, client-side UX.
- **Decision:** Use a **Vite + React SPA** (React Router or TanStack Router). No SSR. Typed API clients are generated from the OpenAPI contracts (§8).
- **Consequences:**
  - Simple build/deploy: static assets, no Node server runtime.
  - No SSR/SEO — revisit only if a real pre-render need appears.
  - `frontend/` is a separate repo; it consumes `contracts/` as its API source of truth.
