# Local validation · 18 October 2026

- Node.js 24.21.0 on Windows.
- `npm.cmd test`: **15 passed, 0 failed**. Local HTTP tests exercise independent source/phone clients, exact request retrieval, role isolation, single-use invites, request revision checks, expiry, cancellation, replay prevention, queued approvals, token revocation, encrypted storage and hook allow/deny/fallback contracts.
- APNs sender test checks its ES256 signature locally using a generated test key and a mocked HTTP/2 connection. It verifies topic, priority and ActivityKit JSON. **No request is sent to Apple in this test.**
- `npm.cmd audit --omit=dev --audit-level=moderate`: no known vulnerabilities reported at validation time.
- Relay startup, private setup generation and demo status submission succeeded locally. The relay correctly reports that Apple push is not configured. Generated configurations keep phone permission answering disabled.
- Node syntax checks passed for the relay entry point and hook adapter.

**Not verified:** Swift compilation, macOS CI, code signing, a physical iPhone, Face ID/passcode behavior, Apple push acceptance/delivery, iOS background behavior, provider hook installation in a real Codex/Claude Code session or App Store/TestFlight distribution.

This package is development source, not a production-ready or signed iPhone release. Desktop Orby was not modified.
