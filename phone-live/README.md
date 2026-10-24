# Orby phone access

Orby 10.47 + Orby Live 0.4.0 provide free iPhone Home Screen notifications, a compact live project/status overview and signed responses to supported desktop requests. Follow [the iPhone guide](docs/IPHONE-SETUP.md). The approved dark/light glass interface reuses the original rendered Orby mascot and 81 public desktop motion clips; [appearance and motion guide](docs/PHONE-APPEARANCE.md).

- A still-unanswered ChatGPT/Codex question hands off after five minutes, when a trusted notification-capable phone and the relay are ready. Otherwise it remains on the PC.
- Tap a notification to open the exact current question. Choose an answer or, where the desktop form supports it, type/dictate a response. Sending requires an explicit tap and passkey confirmation.
- Permission prompts use Allow once / Deny. Stop is offered only for a single identifiable current task with an unambiguous visible Stop control. Windows independently verifies the signed action and rechecks its exact native target.
- The phone shows readable ChatGPT, Claude and Gemini project summaries. Arbitrary Claude/Gemini remote controls are not supported.
- Project notifications wait until the PC is idle/locked by default. A visible Orby phone screen suppresses duplicate background alerts. Question text and commands stay out of notification previews.
- This is a Home Screen web app, not a native Live Activity or Dynamic Island widget. No Apple membership purchase is needed. Native iPhone signing and Live Activity delivery are deferred.

The PC and local HTTPS helpers must remain awake and online. The temporary tunnel changes address on a full restart, requiring new pairing/subscriptions. No stable hosted service is deployed. A relay-only restart preserves the existing address and keys.

The withdrawn MCP connector stays withdrawn. Public packages exclude personal water files, credentials and databases. Phone tokens/keys are protected locally; relay records are encrypted at rest and HTTPS protects transport. The relay operator can read task/request content; this is not end-to-end encryption.

## Verification

Use Node 24+: `npm.cmd ci --ignore-scripts`, then `npm.cmd test`. Windows checks use the adjacent source or `windows/` from the source ZIP. The optional isolated Chrome test uses a virtual authenticator when `ORBY_PLAYWRIGHT_ROOT` points to a Playwright package directory. These automated checks are separate from real iPhone delivery.

The prior physical iPhone pairing, mobile-data task feed and no-action signed denial passed. Home Screen Lock Screen test notification delivery was confirmed on the physical iPhone. The real five-minute ChatGPT question handoff and a signed choice response now passed on the physical iPhone: Windows independently verified the response, sent the answer and acknowledged the question as resolved. Custom response/Stop behavior still requires a physical-device test. Native simulator/unsigned device compilation passed previously; no signed iPhone app or native push delivery was produced.

`npm.cmd run package` exports sanitized source, including the service worker, web app, relay, native prototypes and Windows adapter. It excludes private data and signing keys. `Start-PhoneAccess.cmd` starts the private test helpers; `Stop-PhoneAccess.cmd` stops only those recorded helpers. `scripts/Restart-PhoneRelay.ps1` reloads the relay without changing the tunnel. Native Android sources are retained as a separate earlier prototype; the current user is testing iPhone.

The Dockerfile includes the web app and is prepared for a protected persistent relay behind an HTTPS proxy. Configure `PUBLIC_ORIGIN`, `ADMIN_TOKEN`, `STORAGE_KEY` and a persistent `/data` volume. Do not expose its HTTP listener publicly. A hosted production deployment has not been completed.


While a supported question waits on the PC, the notch shows a five-minute countdown. The small closed notch also keeps that time visible. Unavailable phone/controls pause the handoff. The desktop card closes only once the relay acknowledges the current question. Premature project alerts are suppressed while a desktop review is waiting; the phone instead explains that the question is still waiting on the PC. An actual question notification is separate and opens its review. A native response marked stale is not a confirmed successful answer.
