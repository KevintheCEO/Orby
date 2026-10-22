# Contributing

Keep changes compatible with Windows PowerShell 5.1. Save non-ASCII PowerShell and XAML files with a UTF-8 BOM. Do not add API keys, personal chat logs, private screenshots, local settings, personal modules or water-tracking assets.

Run focused checks from `src/` for the affected area. `Test-HomeDashboard.ps1` covers public Home and imports the menu suite. `Test-StateMachine.ps1` covers activity transitions. `Test-DropSnapshot.ps1` covers attachment-state interpretation; `Test-DropFlow.ps1` covers composer navigation. Native host checks need a fresh isolated data directory. Do not run tests against another user's real drafts, files or account data. Build release downloads using the root `Build.ps1`; do not package an installed personal app directory.
