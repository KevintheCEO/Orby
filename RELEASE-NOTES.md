# Orby 10.40 Beta — Quiet Home and direct AI file handoff

Orby 10.40 brings the latest black-and-charcoal Home, AI task views and desktop interactions to the public Windows build.

- Compact AI activity sits above a full-width music card; idle Home stays quiet.
- One AI button reveals ChatGPT, Claude and Gemini. Task companions, task details and available usage bars remain in the provider view.
- File drop supports all three providers with direct file-list paste and an optional message, without opening a file chooser. Orby verifies attachment readiness and sends once; uncertain sends are never automatically repeated.
- Adaptive Mini, roomier Settings, smoother hover/resize transitions, usage-bar fill animations and double-click wake-up feedback are included.
- Weather has been removed. This public edition contains no water card, drinking reminder, intake tracking, private module or personal data.

## Download and update

Use **Orby-Setup.exe** to install or update your existing managed folder. Quit Orby from its tray icon first. Preferences stay separate from the application files. For portable use, fully extract **Orby-Windows.zip**, then open **Orby.exe**.

**Orby-Source.zip** contains the tagged source and build scripts. **FILES.sha256** lists the portable/embedded runtime files. **SHA256SUMS.txt** covers the release downloads. Source, tag and release point to the same commit.

## Verification and limits

Public Home and menu checks, installer safety checks, attachment-state regressions and native packaged-host checks passed. The final setup and portable folder were scanned by Microsoft Defender with no threats found; a redacted source scan found no credentials. See VALIDATION.md for scope.

Windows x64 / Windows PowerShell 5.1. Binaries are unsigned. Provider sign-in, supported app/site controls, upload permissions and connectivity are required. Transfer time depends on the file, service and network. Codex allowance is separate from ChatGPT message limits. Claude/Gemini usage appears only when supported visible account-page readings are available; unavailable data stays labelled. Reduced motion remains available.
