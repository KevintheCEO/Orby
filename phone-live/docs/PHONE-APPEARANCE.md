# Orby for iPhone · Glass UI

Orby Live 0.4.0 adds the approved Midnight Glass and Frosted Pearl designs to the existing free Home Screen web app. Windows remains Orby 10.47; this update does not replace the desktop installation.

## Open the update

Reload Orby from its existing iPhone Home Screen icon. Keep the same address and pairing. In **Settings → Appearance**, choose **Follow device**, **Dark**, or **Light**. Follow device reacts to the iPhone’s system appearance, including changes made by its own schedule. It does not inspect the wallpaper or create a separate time schedule. Manual appearance and gentle-motion choices are remembered on this device.

Dark mode has a near-black background and smoked translucent cards. Light mode uses pale pearl glass and graphite text. Glass has a readable fallback, and the interface respects Reduce Motion. The pairing credential and notification subscription are not changed by appearance choices.

## Your team

Home groups real tasks by ChatGPT, Claude and Gemini. A provider card has a white main companion, plus up to four larger companions in the Windows task colors: red, purple, teal and gold. Working companions each have their own blue activity ring. Task IDs retain their colors while they remain active, even if the feed changes order. The count includes every task, including tasks beyond the five displayed companions.

Tap a provider to reveal all its task rows, then a row to read its title and current detail. The Tasks screen can show all tasks or filter by provider. No sample tasks are inserted into the connected app. Task cards and expanded state survive the normal refresh, so motion does not restart every three seconds.

## Motion

The body is copied byte for byte from the existing `Rendered-assets/body.png`. Colored variants are exported through `OrbyRenderedAssets.Body` from `Rendered-Assets.cs`, using the existing desktop palette. Eye placement, face paths and arm paths come from `Native-Avatar.cs`; these are not new CSS circle mascots. See `web/mascot/provenance.json` and `scripts/Export-DesktopMascot.ps1`.

The public Windows catalog’s 81 clips are ported to browser transforms, eye motion, particles and lightweight props. Private water reminders and drinking clips are excluded. State-appropriate startup, working, research, thinking, waiting, error, resting and completion motions run automatically. Idle gestures add variety; tapping a companion gives a wake-up and wave. Card presses, task expansion and review sheets have soft transitions.

**Settings → Meet Orby’s moves** previews all 81 clips. Desktop cursor-follow becomes a touch/pointer interaction. Desktop window, drag, music and volume clips are visual previews only: they do not drag a PC window, change volume, start playback or issue a PC command. These are web adaptations, not the native Windows renderer.

Motion pauses offscreen and when the app is hidden. **Gentler motion** stops character animations and animated transitions. The iPhone’s system Reduce Motion setting also stops them and cannot be overridden by this switch.

## Requests are still explicit

Requests remain on Home and notification links open the exact review sheet. No tap on an avatar, navigation button, theme or motion preview signs or sends a decision. The full request, explicit response, current revision, expiry and passkey checks are retained. Existing five-minute handoff and notification rules are unchanged.

Supported ChatGPT/Codex question and permission controls remain distinct from Claude/Gemini task viewing. Stop remains a separately reviewed request on Home when the PC exposes it; the UI does not invent a per-task Stop action.

## Verification limits

The UI and all 81 preview clips were checked in an isolated Chromium browser at mobile widths, using synthetic activity. Tests cover live device-theme changes, persistence without resetting pairing, stable companions, task details, filtering, Reduce Motion, background pausing, overflow and inert task text. Existing browser passkey and relay/Windows signature checks also run. WebKit is not installed in this Windows runtime. Physical iPhone appearance, animation smoothness and glass rendering still need a user check; the earlier successful real iPhone notification and question-response proof is separate.
