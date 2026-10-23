# Connect your phones to Orby

This is the new desktop-to-phone connection. Do not reinstall the old MCP plugin. You do not need to open a Work chat on your phone.

## 1. Windows

Install Orby 10.42 into the existing managed Orby folder. Keep the personal `Personal/` folder and user data. The sharing installer contains no water tracking.

Double-click `Start-PhoneAccess.cmd` in `phone-live/`. It uses the Node and Cloudflare tools already installed on this PC. It starts two hidden helpers, creates a temporary HTTPS address, restricts its private folder to your Windows account and SYSTEM, and saves the PC connection code with Windows protection. It never prints your administrator or PC credential. If dependencies are missing after extracting source elsewhere, run `npm.cmd ci --ignore-scripts` in this folder once.

Restart Orby after the first setup. Open **Settings → Phone access**. Task sharing will be on. Phone approval answering stays off until you choose it. Copy the relay HTTPS address shown there. The PC and helpers must stay awake and running, including when you are away from home.

## 2. Android first

Copy `Orby-Live-Android-test.apk` from the PC to your own Android phone, then open it on the phone to install the local test build. Android may ask you to allow installation from the particular file/browser app you used. Enable it only for this installation; you can turn that permission off afterward. This APK is not a Play Store release. Android 11 or later and a screen-lock PIN/password/biometric are required.

Open **Orby Live** on the phone. Enter the HTTPS relay address. On Windows, click **Create invitation**. Paste that invitation into the phone app, give the phone a name, and tap **Connect phone** within five minutes.

The phone shows a fingerprint. In Windows Orby, click **Refresh phones**. Compare the full fingerprint on the two screens. Click **Fingerprints match — trust phone** only when they match. Before this, the phone cannot read task details or answer anything.

Open a real task in one of the AI apps on the PC. The phone should show its provider, title and readable current action. Repeat with ChatGPT, Claude and Gemini. If Orby cannot read an app's task context, it cannot invent it for the phone.

For the background feed, tap **Start / renew lock-screen feed** and allow Android's requested notification permission. This is an Android ongoing activity card, not Apple's Live Activity. The first version runs in a user-started two-hour session; renew it in the app. Android battery/system restrictions may delay or stop it. Tapping the card opens the exact task/request list. Private command text and access tokens stay off the lock screen.

## 3. iPhone

There is no signed iPhone installer yet. Windows cannot install Swift source or an unsigned simulator build on an iPhone. Apple signing and remote Live Activity push are not set up for this account. You do not need to configure or buy anything to try the Android and Windows parts.

When ready, a Mac or cloud Mac can generate the included Xcode project and build/sign it for your account. The macOS workflow checks a simulator build but has not been run. TestFlight distribution and remote ActivityKit push need the Apple developer team, registered app identifiers, signing profiles and APNs key. Never paste private Apple keys into chat or commit them to GitHub.

On the Mac/build service:

1. Install Xcode and XcodeGen. Run `xcodegen generate` in `ios/`.
2. Select your Apple team for both targets. Replace both `com.example` identifiers with your registered app and widget identifiers. Keep the Live Activities setting and app Push Notifications capability.
3. Compile an unsigned simulator build first and fix any diagnostics, then build/sign for the phone or TestFlight. `DesktopPhoneHome` is now the default screen; the hook screen is historical source.
4. Configure the relay environment before starting: `APNS_KEY_PATH`, `APNS_KEY_ID`, `APPLE_TEAM_ID`, `APP_BUNDLE_ID`, `APNS_ENV`. Use the main app's bundle ID. Development-device builds use sandbox; TestFlight uses production. Store signing secrets privately on the relay host.
5. In the signed iPhone app, repeat the address/invitation/fingerprint flow above. Create a fresh invitation for each phone. Pairing a second phone does not revoke the first.
6. Tap **Start / renew Live Activity**, lock the iPhone and verify updates while the app is backgrounded. Dynamic Island requires compatible hardware. Renew the Live Activity within eight hours; Apple controls delivery timing and may delay updates. No continuous desktop-style animation loop is promised.

The APK build does not prove that the iPhone app compiles, signs or receives push. Those remain separate tests.

## 4. Try one supported permission

After task delivery works, enable **Let trusted phones answer supported requests** in Windows Phone access, then save. It is an explicit setting, separate from task viewing.

Use a harmless, deliberately approval-gated action in a disposable ChatGPT/Codex project. Keep the actual permission card available on the PC. On the phone, tap **Review exact request**. Read the entire action, select **Allow once** or **Deny**, and confirm with the phone's screen lock. The decision is signed for that exact request and expires after two minutes.

The phone first shows **recorded / waiting for PC**. Windows then reports **submitted** or **resolved** after handling the native prompt. That does not assert the requested tool action succeeded. If you see **stale**, **expired**, **cancelled**, **offline** or **uncertain**, check the PC and do not assume approval took effect.

Only existing, unambiguous ChatGPT/Codex Allow once / Deny permission cards are supported. Claude/Gemini arbitrary desktop approval controls and multiple-choice questions stay on the computer. Do not weaken the AI's approval policy to force a test.

Repeat with Deny, a changed/cancelled prompt, a request older than two minutes, a sleeping PC, lost phone network and a revoked phone. None should allow a new action. Reopening an old review must not repeat a response. A second phone trying the same request must not produce another native click.

## 5. Away from home and stopping

Switch the phone to mobile data after the local test. Task details and supported approvals should use the same HTTPS address. This must be checked on a real device; the completed PC internet test used a simulated phone client.

The temporary tunnel changes address after restarting. `Stop-PhoneAccess.cmd` stops only this project's recorded helpers. Start again for a new address, then restart Orby and reconnect each phone with a fresh invitation for that address. Revoke old phone entries so they do not fill the four-phone limit. A stable domain/host removes this reconnection step; none is set up yet.

To disable the feature, turn off **Enable phone access** in Orby and save. Revoke a phone from **Refresh phones → Revoke**, or disconnect in the phone app. Disconnecting cannot undo an accepted action. The relay host can read task/request text; encrypted storage is not end-to-end encryption.

## Evidence from Windows

Automated tests exercise real local HTTP, encrypted records, per-phone P256 signatures, exact prompt binding, role isolation, stale/expired requests, session replay, revocation and PC acknowledgement. A public HTTPS round trip exercised the actual Windows HTTP client against a simulated phone. Packaged public and personal Windows checks passed. The Android APK compiled and its signature verified. Android background behavior, native phone screen-lock signing, iPhone compilation/signing/APNs and a permanent hosted deployment remain unverified.
