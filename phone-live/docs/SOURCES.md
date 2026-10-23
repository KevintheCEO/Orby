# Integration references

Checked against primary documentation on 18 October 2026. Installed provider support must be tested separately; documentation is not proof of a device build.

- Codex hooks: https://learn.chatgpt.com/docs/hooks
- Claude Code hooks: https://code.claude.com/docs/en/hooks
- Apple Live Activity push: https://developer.apple.com/documentation/activitykit/starting-and-updating-live-activities-with-activitykit-push-notifications
- Apple Live Activity presentation, duration and animation limits: https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities
- App Clips and Live Activities: https://developer.apple.com/documentation/appclip/offering-live-activities-with-your-app-clip

The app uses `LocalAuthentication` on the foreground review screen, rather than approving directly from a locked widget. Credentials remain in the app's Keychain. The relay authenticates a phone credential; it cannot independently attest Face ID or a physical human touch. A compromised phone or relay is outside this prototype's trust boundary.

The service retains encrypted request records for at most 24 hours, pruned at least once a minute while running. Full tool input is transmitted to the relay for exact review, so use a relay you control. It does not transmit chat histories or tool output. Secret detection is best-effort, not a complete data-loss prevention system. Disable phone permissions for sensitive environments.
