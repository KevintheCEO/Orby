# Security and privacy

Orby is a local Windows desktop companion. The public 10.40 package excludes personal modules, water reminders and intake tracking. It does not include user settings, chat logs, connection credentials or private captures. Weather/location polling and the withdrawn desktop phone connector are absent.

## Data and permissions

Orby reads supported local AI activity and accessibility information, media sessions and available account-usage signals. It can open or focus provider applications. With your explicit Send action, it pastes selected files and your message into the chosen AI provider and sends them. That provider handles the upload and applies its own privacy rules. This is not an Orby-hosted file relay.

File handoff uses the Windows clipboard and desktop accessibility controls. It depends on the correct foreground window and supported provider controls. Unknown send outcomes are not automatically retried. A failed message send does not prove that attachments were never uploaded. Review the provider before trying again.

Supported permission/question prompts still require explicit user choices. Orby does not automatically approve requests. Status and usage support varies by provider; unavailable readings are labelled.

Preferences, cached activity/usage information, logs and copied file-inbox contents can contain sensitive filenames or task text. They remain under the user's local Orby data directory, normally `%LOCALAPPDATA%\Orby`, and are not encrypted as a whole. Diagnostic captures may include private conversation or window text. Review and redact them before sharing. Git ignore rules are a precaution, not a substitute for reviewing uploads. Local files have no general automatic-retention guarantee.

Account integrations may use provider-owned local authorization stores. Orby does not ask you to paste passwords or API keys. No such credentials are distributed with this release. Visible Claude/Gemini usage-page reading does not read browser cookies or passwords. Only use official installed provider clients and trusted executables on PATH.

## Windows behavior

The native launcher hosts installed Windows PowerShell 5.1 with normal policy checks. Setup installs per user, verifies its embedded file manifest, rejects unrelated destinations and downgrades, and stages replacement with rollback. Quit the running app before updating. Startup is opt-in. No antivirus exclusions, policy overrides or automatic firewall changes are applied.

Binaries are unsigned. SHA-256 checksums establish download consistency, not publisher identity or a security certification. The release was scanned with Microsoft Defender at publication time; this does not guarantee all future detections or behavior. Previously quarantined versions should remain blocked. If a new detection appears, leave the file blocked and report its name and hash; do not restore it or disable protection.

## Reporting

For a security concern, use GitHub private vulnerability reporting if enabled; otherwise contact the repository maintainer without posting private files or credentials publicly. Regular compatibility problems can be reported in Issues with redacted reproduction steps.
