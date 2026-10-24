# Integration references

Checked against primary documentation on 18 October 2026. Installed provider support must be tested separately; documentation is not proof of a device build.

- Codex hooks: https://learn.chatgpt.com/docs/hooks
- Claude Code hooks: https://code.claude.com/docs/en/hooks
- Apple Live Activity push: https://developer.apple.com/documentation/activitykit/starting-and-updating-live-activities-with-activitykit-push-notifications
- Apple Live Activity presentation, duration and animation limits: https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities
- App Clips and Live Activities: https://developer.apple.com/documentation/appclip/offering-live-activities-with-your-app-clip

The app uses `LocalAuthentication` on the foreground review screen, rather than approving directly from a locked widget. Credentials remain in the app's Keychain. The relay authenticates a phone credential; it cannot independently attest Face ID or a physical human touch. A compromised phone or relay is outside this prototype's trust boundary.

The service retains encrypted request records for at most 24 hours, pruned at least once a minute while running. Full tool input is transmitted to the relay for exact review, so use a relay you control. It does not transmit chat histories or tool output. Secret detection is best-effort, not a complete data-loss prevention system. Disable phone permissions for sensitive environments.

## Phone UI references · 24 October 2026

- Device appearance: https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/At-rules/@media/prefers-color-scheme
- Glass surfaces: https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/Properties/backdrop-filter
- Browser animation timing: https://developer.mozilla.org/en-US/docs/Web/API/Web_Animations_API
- Reduce Motion: https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/At-rules/@media/prefers-reduced-motion

The phone body is the existing public Orby rendered production layer. Its palette variants use the existing `Rendered-Assets.cs` renderer; native face/arm paths and all 81 public clips come from `Native-Avatar.cs` and `Animation-Catalog.cs`. No personal water artwork is included. `web/mascot/provenance.json` records the body hash and palette.

Provider mark paths are reused from the existing Windows `Reference-Home.xaml` and `Provider-Icons.xaml`. The Windows attribution records Claude’s header SVG at https://claude.com/ and Gemini’s sparkle at https://www.gstatic.com/lamda/images/gemini_sparkle_v002_d4735304ff6292a690345.svg (retrieved 10 October 2026). Brand marks belong to their respective owners; Orby is independent.
