# Security and privacy

Orby does not contain or request a ChatGPT API key, Spotify API key, Spotify password, cookie, access token, refresh token, or private key. It connects locally to the installed ChatGPT Windows app and the active Windows Spotify media session.

Runtime settings, reminders, alerts, and diagnostic captures are stored locally under `%LOCALAPPDATA%\Orby`. They are excluded from the public repository by `.gitignore`. Do not commit files from that folder or paste captures containing private conversation text into issues.

Orby does not send ChatGPT messages or Spotify credentials to a remote Orby server. File handoff stays on the local Windows desktop. The ChatGPT app and Spotify still apply their own account, upload, privacy, and permission rules.

The included `Orby.exe` is only a local launcher for the included app files. It does not contain credentials or contact a remote service.

## v5.9 security remediation
The previous unsigned launcher used hidden PowerShell with ExecutionPolicy Bypass and automatically registered a per-user Run startup entry. Defender reported Behavior:Win32/Persistence.A!ml against the previous executable. These behaviors are plausible contributors, not a confirmed root cause from Defender telemetry.

This build removes automatic startup registration, disables its settings control, removes execution-policy overrides and hidden/minimized launch flags, and includes the launcher source. It does not add antivirus exclusions, restore quarantined files, or change Windows policy. The executable remains unsigned; Windows reputation/signing warnings may still occur.

Verification on 2026-10-06: Microsoft Defender custom scan of the complete replacement folder returned "found no threats" (exit 0). All PowerShell files parsed without errors; the app rendered its Home and compact previews using ordinary Windows PowerShell policy (exit 0). This is a point-in-time scan, not a guarantee of future detection results. Keep the previous detected executable quarantined and replace old published downloads with this build.

Console-free update: launcher uses CreateNoWindow for its PowerShell child at the user's request. No execution-policy override or startup registration is added. Full-folder Defender scan found no threats; console-free launch rendered previews successfully on 2026-10-06.
