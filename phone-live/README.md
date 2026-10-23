# Orby phone access

An opt-in companion for desktop Orby 10.43. See readable ChatGPT, Claude and Gemini task activity on your iPhone. Review and passkey-sign one supported ChatGPT/Codex Allow once / Deny request. Windows independently verifies the signature and rechecks the current permission card before answering.

**The current iPhone route is free Safari / Home Screen access while open. It does not provide background Live Activities or phone notifications.** Follow [the iPhone setup guide](docs/IPHONE-SETUP.md): start the Windows helpers, create a QR invitation in Orby, scan it, connect with a passkey and compare the fingerprint on the PC. No Apple purchase, Android phone or access to Work chats is needed.

| Function | Scope |
| --- | --- |
| Task feed | Readable ChatGPT, Claude and Gemini contexts; unavailable details are not invented |
| Phone permissions | One current, unambiguous, accessible ChatGPT/Codex Allow once / Deny card; explicit opt-in |
| Other approvals / questions | Stay on the PC |
| Free iPhone web app | Safari passkey pairing, exact-action review and signed decisions; keep open |
| Native iPhone | Simulator and unsigned device compile passed on a cloud Mac; signing, installation and APNs deferred |
| Android | Existing Android 11+ test build; not required for iPhone; no physical-device proof |
| Away from home | Temporary HTTPS tunnel while PC and helpers stay awake and online |
| Sleeping PC / unavailable feed | No new approval accepted |

Pending phones cannot see tasks. Each invitation is single use and expires in five minutes; the PC confirms each phone fingerprint. Up to four phones can be paired. Permission requests expire after two minutes; changed prompts, stale PC snapshots, replays, disabled approvals and revoked phones are rejected. An acknowledgement does not prove that a tool action succeeded. Disconnecting cannot undo an action already accepted.

Phone credentials are protected locally; passkeys are held by the authenticator. The PC credential and pinned phone keys use Windows DPAPI. Relay records are encrypted at rest and HTTPS protects transport. This is **not end-to-end encryption of task text**: the relay operator can read the relayed content and must protect the database and storage key.

The withdrawn ChatGPT MCP plugin is not reinstalled. Personal water tracking is excluded from public packages. The earlier hook prototype remains in `hooks/` with separate regression tests and [historical documentation](docs/HOOK-PROTOTYPE.md); no hooks are silently installed.

## Development and deployment

Use Node 24+: `npm.cmd ci --ignore-scripts`, then `npm.cmd test`. Windows adapter tests use the adjacent Orby source or `windows/` in the source ZIP. The optional browser test uses an isolated Chrome profile and virtual authenticator when `ORBY_PLAYWRIGHT_ROOT` points to a Playwright package directory. It never opens a user's browser session. Automated/simulated results are not physical iPhone proof.

`npm.cmd run package` creates the source ZIP with the web assets, relay, native sources and Windows adapter. It excludes credentials, databases, signing keys, generated builds and personal water files. The native iPhone [Mac build check](https://github.com/kevinenas/Orby/actions/runs/39993496758) produced compile diagnostics, not an installable IPA. The physical iPhone Safari test is still required.

`Start-PhoneAccess.cmd` starts hidden local relay/tunnel helpers, protects private files and enables task sharing with remote approvals off. `Stop-PhoneAccess.cmd` stops only its recorded helpers. Restarting the temporary tunnel changes its hostname and requires new phone pairing/passkeys; Orby 10.43 reloads the Windows connection automatically. No stable hosted service is deployed.

The Dockerfile includes the web assets and is prepared for a persistent relay behind an HTTPS proxy. Configure `PUBLIC_ORIGIN`, `ADMIN_TOKEN`, `STORAGE_KEY` and a protected persistent `/data` volume; provision the desktop credential through the administrator endpoint. Do not expose the container's HTTP listener directly. A production hosted deployment has not been completed or tested.
