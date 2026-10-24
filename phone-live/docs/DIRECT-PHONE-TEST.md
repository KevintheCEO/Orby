# Direct phone poll · no real action

For an explicitly requested test, the PC can send a poll directly to a paired phone without waiting for the normal five-minute desktop handoff. This diagnostic does not change the normal desktop rule or the desktop's approval configuration.

The five choices test Allow, Deny, Stop, opening an app, and network access. Every choice is explicitly labelled test only. It records a passkey-signed choice; it cannot open an app, stop a task, lock/reset the phone or grant permission. A user may manually lock the iPhone before the notification arrives.

On the PC, `scripts/Send-PhoneTest.ps1` creates the poll using the existing DPAPI-protected PC connection. Its `-Watch -TestId <id>` mode independently verifies the result with the Windows-pinned phone public key and acknowledges verified/failed. It never invokes the native approval worker.

The record lives in its own encrypted `d-phone-test` namespace and separate `/web/phone-test` and `/desktop/phone-test` endpoints. It never enters `d-request` or `/desktop/sync` decisions. The server fixes the choices and text, binds the response to the exact review hash, expiry and passkey assertion, and permits one response only. Revocation, a changed PC session or an offline PC invalidates it. Polls expire in ten minutes. Old records are pruned during reads.

Notifications require the current Home Screen app's own subscription, explicit iPhone permission and the same relay origin. An old temporary address's subscription is not reused at a new origin. The test can intentionally alert while the PC is active; ordinary activity/permission notification rules remain unchanged. The notification contains a generic test message and a test ID. Tapping only opens the poll; it never submits the choice. If the app is already open, the poll also appears on Home.

Reload the Home Screen app once after installing the feature so its notification worker and review UI are current. Then lock the iPhone if testing a Lock Screen banner, tap the notification, review the poll, choose one option, acknowledge no action will run, and confirm Send test answer with the passkey. Delivery acceptance by the push service is not proof of physical iPhone display or a successful response.
