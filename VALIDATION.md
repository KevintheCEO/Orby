# Orby 10.40 public release validation

Validated on Windows x64 with Windows PowerShell 5.1 on 22 October 2026.

## Scope

The public release uses the canonical 10.40 runtime, with the personal extension and data excluded. Home shows AI activity above music. No water module, reminder controller, bottle textures, private animation catalog, weather client or weather atlas is distributed. The small public `Hydration-Avatar.cs` file is a no-op compatibility surface required by the common avatar renderer; it supplies no water visuals, reminder scheduler or intake tracking.

The file-transfer worker and helpers are unchanged from the validated direct-paste 10.39 implementation. Live checks during that work confirmed the file, exact message and accepted Send action in ChatGPT, Claude and Gemini. Observed handoffs for tiny synthetic files took about 10.5, 2.2 and 3.8 seconds respectively. Those are local test observations, not upload-speed guarantees. An exact model reply was observed in Claude; model replies were not verified for the other two. No new live provider messages are required by this Home-only update.

## Checks

- Existing 10.40 menu/input suite: 2,813 assertions.
- Public Home: 40 assertions covering routing, layout, idle/active states, unavailable media, control bindings and absence of personal reminders/weather.
- Existing managed-installer suite: 19 assertions, including update, downgrade rejection, locked-file recovery, safe destinations and shortcut targets.
- Native packaged public host: Home, AI chooser, provider routing, task inspector, file recovery and normal shutdown.
- All distributed PowerShell source parses in Windows PowerShell 5.1.
- This release checkout: 118 PowerShell files parsed, 14 attachment-state regression assertions and 39 state assertions passed.
- Public source/payload inspected for excluded personal files, runtime data and credentials.
- Public portable payload compared to the already validated 10.40 payload; runtime text and assets must match. Rebuilt binaries use unchanged source.
- 104 runtime source/assets match canonical 10.40 byte-for-byte. The artwork provenance README is public-only documentation; executable/DLL recompilations use unchanged source.
- Public Home previews are actual WPF renders with labelled sample data. No personal application screenshot is used.
- Final release setup and portable application scanned with Microsoft Defender.
- Gitleaks 8.30.1 scanned the public checkout with redaction and reported no leaks.
- Source/tag/release commit and published asset checksums checked together during publication.

## Limits

These checks do not establish compatibility with every future provider UI, language, file type, account or Windows setup. Usage readings require supported available signals. Window focus matters during file transfer. No automatic retry is performed when send outcome is uncertain. Reduced motion and ordinary security controls remain available. The build is unsigned and not configured for byte-for-byte deterministic recompilation.
