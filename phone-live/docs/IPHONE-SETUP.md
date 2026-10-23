# Connect your iPhone for free

This is the foreground Safari / Home Screen version you chose. No Apple membership purchase, TestFlight installation, Android phone or Work chat is needed. It shows the computer's readable ChatGPT, Claude and Gemini task activity. A trusted phone can review and passkey-sign one supported ChatGPT/Codex permission at a time.

**Keep the phone screen open to see updates. This free version has no background Live Activity, Lock Screen feed or phone notifications.** The native iPhone build is separate and deferred.

## Pair once

1. On Windows, use Orby 10.43. Double-click `Start-PhoneAccess.cmd` in this folder. Wait for “Phone relay ready.” Orby reloads the connection automatically; an older Orby version must be restarted. The helpers stay running in the background.
2. Open **Orby → Settings → Phone access → Create invitation / QR code**.
3. Scan that QR code with your iPhone Camera and open the link in **Safari**. The invitation is filled in automatically and expires after five minutes. Do not share it.
4. Give the phone a name and tap **Connect with passkey**. Complete the iPhone's passkey confirmation. Use a current iOS/Safari version and enable a screen lock and passkeys. The signing key stays in the passkey provider; Orby does not receive your Face ID, passcode or Apple password.
5. The phone shows a fingerprint and waits. On Windows, click **Refresh phones**, compare the complete fingerprint, then click **Fingerprints match — trust phone**. Until this confirmation, no task details are shared.
6. Keep Safari open. Start a task on the PC and check that its provider, title and readable activity appear. Try ChatGPT, Claude and Gemini separately. Orby can only show context the connected desktop app exposes.

For an app-style window, use Safari's **Share → Add to Home Screen before pairing**, open that icon, then paste a fresh invitation from Windows. Safari and the Home Screen window can use separate storage, so pairing in one does not guarantee the other is connected. Scan-to-Safari is the simplest first test.

## Optional harmless connection test

After pairing, run `scripts/Run-PhoneConnectionCheck.ps1` on Windows. Refresh Safari, find **Connection test — no action will run**, then tap **Deny test** and confirm your iPhone passkey. Windows verifies the returned signature against its locally pinned phone key and acknowledges the test. The harmless diagnostic lasts ten minutes. Real permission requests still expire after two minutes. Its records are separate from real permission requests: it cannot execute a command, grant access or reach the native approval worker. It works with real permission answering still off.

This checks the physical phone signature and PC acknowledgement, not a real desktop permission click. A successful result is saved to `outputs/iPhone-connection-check.json` on this workspace PC.

## Test a supported approval

Task viewing works with permission answering off. To test answering, first enable **Let trusted phones answer supported requests** in Windows Phone access and **Save connection**.

Use a harmless, deliberately approval-gated task in a disposable ChatGPT/Codex project. Keep its actual permission card available on the PC. On your phone, open **Review exact request**, read the complete action, check **I have read the complete action**, then tap **Allow once** or **Deny**. Confirm the passkey prompt. Each signature binds that one choice to the exact request and expires with it.

The phone shows recorded / waiting for PC, then the Windows acknowledgement. “Submitted” or “resolved” confirms handling of the permission card, not successful completion of the tool action. Changed prompts, requests older than two minutes, sleeping PCs, revoked phones and repeated responses must fail closed. Do not weaken the desktop AI's approval policy to force a test.

Remote answering currently supports one unambiguous, accessible **ChatGPT/Codex Allow once / Deny** card. Arbitrary Claude/Gemini approvals and general questions remain on the PC. Their readable task activity is still shown.

## Away from home

After pairing, switch the iPhone to mobile data and check that the same task feed refreshes. The Windows PC, relay and tunnel must stay awake and online. This is not an always-on hosted service.

The temporary HTTPS address changes when the helpers restart. Run `Stop-PhoneAccess.cmd`, then `Start-PhoneAccess.cmd` for a fresh session. Create a new invitation and pair again; passkeys are bound to the old hostname. Revoke old entries in Windows so they do not fill the four-phone limit. Orby 10.43 reloads the new address automatically. A stable domain and host can remove this step later.

To stop sharing, disable **Enable phone access** and save, revoke the phone in Windows, or choose **Disconnect this phone** in Safari. Disconnection cannot undo an action already accepted. Task records are encrypted at rest and transported over HTTPS; the relay host can read task text, so this is not end-to-end encryption.

## What has actually been tested

Local tests exercise registration, exact origin, passkey user verification, signature binding, pending-phone isolation, all three task providers, expired/stale requests, revocation and PC acknowledgement. An isolated Chrome browser with a virtual platform authenticator completed the real browser registration/review/sign/ack flow. A physical iPhone Safari test subsequently passed: the user confirmed the task feed over mobile data, and a passkey-signed no-action denial was independently verified on Windows against the pinned phone key and acknowledged. This does not test a real native permission click, background Live Activity or APNs delivery.

The separate native iPhone app and Live Activity extension compiled successfully for both simulator and unsigned device in [the Mac build check](https://github.com/kevinenas/Orby/actions/runs/39993496758). No signed IPA, phone installation or APNs delivery was produced. Native background Live Activities remain deferred under your free-version choice.
