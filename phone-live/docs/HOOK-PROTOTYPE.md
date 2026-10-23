# Historical hook prototype — not the current phone setup

This document preserves the earlier independent design. Use CONNECT-PHONES.md for the current desktop link. The current native app opens the desktop connection screen by default.

# Where this stands

This is an independent native iPhone development project. It uses Orby's simple matte face as artwork. It does not install anything into desktop Orby, ChatGPT Work or an MCP plugin.

**You cannot install this source ZIP or an unsigned simulator build on an iPhone.** Windows can run the relay and automated tests. An Apple-signed device build from a Mac or cloud Mac is required for the phone. Apple push delivery and the Swift code have not been run on an iPhone here.

## How the finished connection is intended to work

1. A supported Codex or Claude Code session produces a real activity or permission hook event.
2. A local hook sends that event directly to your HTTPS relay. No desktop Orby process is involved.
3. The relay sends an ActivityKit update through Apple's push service. The lock screen / Dynamic Island shows Orby's face and a brief activity description.
4. A permission request shows **Review exact request**. Tapping opens the small native app and displays the complete tool input. The lock screen contains neither the private command nor credentials.
5. After reading it, choose **Allow once** or **Deny**, then confirm using Face ID or your iPhone passcode. A decision applies to that one request and expires after two minutes.
6. The waiting AI hook receives the decision. On a timeout or network failure, it returns no decision, leaving the AI's regular approval flow in control. A recorded decision does not prove the tool executed.

There is deliberately no universal button that silently approves future actions.

## What you can test on Windows today

Open PowerShell in the folder containing `package.json`:

```powershell
npm.cmd ci --ignore-scripts
npm.cmd test
```

These tests simulate separate AI and phone clients over real local HTTP. They verify request handling, role isolation, expiration, replay protection, cancellation and provider hook output. They do **not** verify Apple's push service, iOS rendering or real AI hook installation.

For a local relay smoke test:

```powershell
npm.cmd start
```

Leave that window open. In a second PowerShell window in the same folder:

```powershell
npm.cmd run setup
npm.cmd run demo
```

The setup generates private credentials and reviewable hook examples. It does not install hooks. Without Apple configuration, the service explicitly reports that push is not configured. A local HTTP address cannot connect a real iPhone app; use HTTPS for that later stage.

Keep `.data/` and `generated/` private. They contain credentials. The encryption key sits next to the local database for development; production should keep `STORAGE_KEY` and `ADMIN_TOKEN` in an access-controlled secret store. Windows file permissions must restrict these folders to your account. Encryption does not protect against someone who can read both key and database.

## Build the phone part without owning a Mac

You can use a cloud Mac or a macOS CI runner from Windows. Copy this folder into a private Git repository **without** `.data/`, `generated/`, `node_modules/` or any Apple keys. The included `.github/workflows/ios-build.yml` can generate the Xcode project and check an unsigned simulator build on a macOS runner. If this is a subfolder in another repository, place the workflow in that repository's top-level `.github/workflows/` first. CI has not been run for this package yet.

An unsigned CI build is only a compilation check. For actual iPhone delivery, use a Mac build service with your Apple Developer account to archive/sign and distribute through TestFlight or registered-device provisioning. There is no signed IPA in this ZIP. Never send Apple private keys or certificates in chat.

On the Mac/build service:

1. Install Xcode and XcodeGen, then run `xcodegen generate` inside `ios/`.
2. Open `OrbyLive.xcodeproj`. Select your Apple team for both targets and replace `com.example.OrbyLive` and its widget bundle ID with your own registered identifiers.
3. Enable Push Notifications for the app identifier and automatic signing. Use a device provisioning profile with that entitlement. Retain the Live Activities Info.plist setting.
4. Build for your iPhone (iOS 17.2 or later), or archive a signed TestFlight build. TestFlight/App Store push uses APNs **production**; Xcode development-device builds use **sandbox**.
5. Set up an APNs signing key in your Apple Developer account, stored securely on the relay host. Use the **app** bundle ID, not the widget bundle ID, for the APNs topic.

No full-screen pet animation loop is promised. ActivityKit controls transitions and update frequency; the native views change the face/eyes and status when new state arrives. A Live Activity lasts at most eight hours, so the user renews it in the app. Delivery can be delayed or stopped by system settings and budgets. Unsupported iPhones still show the Lock Screen activity if their iOS version supports it; Dynamic Island requires compatible hardware.

## Live phone test, after signing is available

1. Give the relay a stable HTTPS address, forwarding to local port **4319**. A temporary tunnel is only suitable for a private test; its address can change. This is a separate port from the withdrawn connector.
2. In the relay PowerShell window, configure before starting:

```powershell
$env:NODE_ENV = "production"
$env:PUBLIC_ORIGIN = "https://YOUR-RELAY-HOST"
$env:APNS_KEY_PATH = "C:\private\AuthKey_YOURKEY.p8"
$env:APNS_KEY_ID = "YOUR_APPLE_KEY_ID"
$env:APPLE_TEAM_ID = "YOUR_APPLE_TEAM_ID"
$env:APP_BUNDLE_ID = "YOUR_REGISTERED_APP_BUNDLE_ID"
$env:APNS_ENV = "sandbox"
npm.cmd start
```

Use `production` for `APNS_ENV` with TestFlight. The relay binds to loopback; the HTTPS proxy/tunnel provides external access. The health endpoint reports whether keys are configured, not whether delivery succeeded.

3. In a second window with the same `PUBLIC_ORIGIN`, run `npm.cmd run setup`. Open the **signed native app**, paste the HTTPS address and five-minute invitation, then tap **Connect phone**. Invites are single use. A new pairing revokes the old phone.
4. Tap **Start / renew Live Activity**. Lock the phone. Run `npm.cmd run demo`. Verify the demo text appears while the app is in the background. Failure here means stop and fix push before enabling permissions.
5. Only after background delivery works, review the generated hook examples. Merge the Codex example into an appropriate reviewed hooks file; merge the Claude example into the `hooks` section of Claude Code settings. Do not overwrite existing hooks. Current Codex versions require explicit hook review/trust. Verify installed provider versions support `PermissionRequest`.
6. In the relevant generated private config, set `permissionsEnabled` to `true` only when ready. Restart the AI session if its hook configuration is loaded only at startup.
7. Use a harmless, deliberately approval-gated test tool action in a disposable project. Confirm the full exact action on the phone, allow it once, and verify only that action proceeds. Do not reduce the AI's sandbox/approval policy to force a test.
8. Repeat with **Deny**. Repeat while the phone is offline, after two minutes, after cancelling the AI request, and with an old request screen. Nothing stale should permit an action; the normal local prompt should remain the fallback.
9. Re-pair a second phone or disconnect this phone, then verify the old phone can no longer fetch or decide requests. Quit the relay and confirm the AI hook returns to normal approval flow.

## Actual support limits

- **Codex:** documented current command hooks, including eligible `PermissionRequest` approvals. This does not intercept every desktop ChatGPT or Work permission screen.
- **Claude Code:** documented hooks. Sandboxed command **network requests do not invoke `PermissionRequest`**, so those remain on the normal approval path. Special tools requiring direct user interaction remain in that flow.
- **Regular ChatGPT chat, regular Claude desktop chat, Gemini:** no validated permission adapter in this version. No simulated approval is substituted.
- No iPhone app can receive a native Live Activity from a ChatGPT plugin alone. An App Clip is a possible later distribution route, but it also needs native signing and Apple deployment.
- No cloud hosting, Apple account, signing, live device test, CI execution or public publication has been completed for this source package.

## Removing this experiment

Remove only the hook entries you installed, disconnect the phone inside the app, stop the relay, and delete the native app. Do not change desktop Orby: this project never adds anything to it.
