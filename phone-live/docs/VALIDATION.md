# Validation · 24 October 2026

Orby Live 0.4.1 phone glass UI; Windows Orby remains 10.47.

- **56 automated tests passed, 0 failed, 0 skipped**, including the full relay, browser passkey, notification, handoff and independent Windows signature checks. Browser tests used the installed Chromium browser and a virtual authenticator.
- The new UI fixture checks Dark, Light, live Follow device changes, appearance persistence without resetting pairing, original mascot textures and native eye paths, stable task colors and expanded cards, all task details/filtering, all 81 public motion previews, Reduce Motion, background pausing, inert task text and no horizontal overflow at 320/375/390/430/768 pixels.
- The white rendered mascot body is copied byte for byte from the installed Windows Orby artwork. Four colored variants are exported using the desktop renderer. No water artwork or private settings are included.
- The updated app keeps the existing pairing key, signed-decision flow and notification subscription. No Windows installer update is necessary for this web UI release.
- Screenshots and fixture results are in the workspace `outputs/iphone-glass-ui/`. Their activity is synthetic preview data, not a record of the user's tasks.

## Physical and platform limits

The earlier real iPhone tests passed pairing, task viewing over mobile data, Lock Screen notification delivery and the actual five-minute question handoff with a signed choice response independently verified by Windows. Those tests predate this UI release. The new glass rendering, appearance switches and motion smoothness have not yet been checked on the physical iPhone. WebKit is not installed in this Windows runtime. Real custom dictation and Stop still need physical-device checks.

The native iOS simulator and unsigned device compilation passed in an earlier cloud Mac run. No signed native iPhone app, native background Live Activity or Apple push delivery was produced. The user chose the free Home Screen web app.

Task viewing covers ChatGPT, Claude and Gemini; native answering applies only to the supported, accessible ChatGPT/Codex controls exposed by the PC bridge. The PC, relay and tunnel must remain awake and online. No live approval is executed by the automated synthetic tests.

## Direct phone test poll

Eight additional tests and an extended browser passkey flow cover direct notification routing, five signed poll choices, isolation from real permissions/native clicks, replay, expiry, revocation, changed text, missing user verification and offline recovery. The normal PC countdown rule is unchanged. Physical delivery and the direct poll reply are pending the current user test.
