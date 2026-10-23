# iPhone setup comes first

You only need the iPhone version. Ignore the Android APK and Android test instructions.

## Build and installation are different steps

The native app and its Live Activity extension are in `ios/`. GitHub's standard Mac runner can compile this project from a Windows computer, so you do not need to own a Mac for that check. The workflow compiles both the simulator and the unsigned device target. It produces diagnostics, not an installable signed IPA.

Signing in to developer.apple.com and accepting the developer agreement registers a free developer account. It does not itself enroll you in the paid Apple Developer Program. Apple documents free personal-device testing using Xcode on a Mac; TestFlight distribution is a membership benefit. Remote Live Activity updates use APNs and the app's Push Notifications capability.

Apple sources:

- [Developer account and free personal testing](https://developer.apple.com/help/account/basics/about-your-developer-account)
- [Program membership and TestFlight](https://developer.apple.com/programs/)
- [Live Activity push requirements](https://developer.apple.com/documentation/activitykit/starting-and-updating-live-activities-with-activitykit-push-notifications)

## What you should do now

Stay signed in at [Apple Developer account](https://developer.apple.com/account/). Check whether the page offers **Join / Enroll**, or shows an active Apple Developer Program membership and Team ID. Do not purchase a membership or create signing keys until the source compile check has passed and you choose the installation route. Never send your Apple password, verification code, certificate password or private key in chat.

After the source compiles, a TestFlight build needs:

1. An active developer team and your app record in App Store Connect.
2. Registered app and widget identifiers, with app Push Notifications enabled.
3. The app's distribution certificate and matching app/widget provisioning profiles, kept in private build secrets.
4. A signed archive uploaded to your App Store Connect account and processed for TestFlight.
5. An APNs key configured privately on your relay, with matching team and app identifiers.
6. Installation on your iPhone, pairing with desktop Orby, and a real Lock Screen / background delivery test.

No Apple account resources are created automatically. No membership purchase is made. An unsigned compilation does not prove signing, installation, Face ID, APNs delivery or physical-device behavior.

Once installed, open Orby Live, paste the relay address and a five-minute invitation from Windows Orby's **Settings → Phone access**. Compare the full phone fingerprint on both screens, then trust the phone on the PC. Start the Live Activity in the phone app. Review a request in the app and confirm with the screen lock before it is signed. Task viewing covers the three providers' readable contexts; remote answering currently covers supported ChatGPT/Codex permission cards only.
