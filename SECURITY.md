# Security and privacy

Orby does not contain or request a ChatGPT API key, Spotify API key, Spotify password, cookie, access token, refresh token, or private key. It connects locally to the installed ChatGPT Windows app and the active Windows Spotify media session.

Runtime settings, reminders, alerts, and diagnostic captures are stored locally under `%LOCALAPPDATA%\Orby`. They are excluded from the public repository by `.gitignore`. Do not commit files from that folder or paste captures containing private conversation text into issues.

Orby does not send ChatGPT messages or Spotify credentials to a remote Orby server. File handoff stays on the local Windows desktop. The ChatGPT app and Spotify still apply their own account, upload, privacy, and permission rules.

The included `Orby.exe` is only a local launcher for the included app files. It does not contain credentials or contact a remote service.
