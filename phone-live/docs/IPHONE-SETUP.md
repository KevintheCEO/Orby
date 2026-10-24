# Orby on your iPhone — free notifications

Orby 10.47 and Orby Live 0.3.1 use an iPhone Home Screen web app. No paid Apple membership or TestFlight is needed. The app shows short project/status cards and lets you review supported ChatGPT/Codex questions and permissions. Real iPhone notifications can appear on the Lock Screen and in Notification Center after you enable them. This is not an Apple Live Activity or Dynamic Island widget.

## Existing connection

Keep the same installed Windows Orby folder and existing relay/tunnel. Updating the relay with `scripts/Restart-PhoneRelay.ps1` preserves the current address and phone keys. Updating Windows preserves your settings, paired phone keys and private water data.

On the iPhone, use **Share → Add to Home Screen**, then open the Orby icon. If it is already connected, keep that connection. If it asks to connect, use a fresh invitation from Windows **Settings → Phone access** and confirm the matching fingerprint on the PC. Safari and the Home Screen window may use separate storage; never assume that pairing in Safari also paired the installed web app.

## Enable notifications

1. Open Orby from its **Home Screen icon**, not a normal Safari tab.
2. Expand **Phone alerts**, tap **Enable notifications**, and allow the iPhone prompt.
3. Leave **Only notify me when I am away from my PC** enabled for project updates. Windows treats a locked or idle PC as away; it cannot know your physical location. Unanswered questions have the separate five-minute handoff below.
4. Tap **Test Lock Screen notification**, then lock your iPhone. The test is scheduled ten seconds later. Delivery follows the iPhone notification and Focus settings. An accepted push service response is not proof that the phone displayed it.
5. Tap the notification to open Orby. Permission notifications open a current review; they never approve anything from the Lock Screen.

Notifications use Web Push, an encrypted subscription and a server key stored in the relay's encrypted database. No Apple signing key is required. [WebKit documents Home Screen notifications and their free developer access](https://webkit.org/blog/13878/web-push-for-web-apps-on-ios-and-ipados/).

## Five-minute question handoff

A supported question or permission appears in desktop Orby first. If it is still unanswered after five minutes, Windows rechecks the actual current controls. With an online relay and a trusted phone subscribed for notifications, the desktop question overlay closes to the usual Home/notch view and the current request is sent to the phone. Without a ready phone, the PC question stays available.

The notification contains a short generic alert, not the question text, commands or conversation transcript. Tapping it opens the exact current question inside Orby. Answer options match the PC. Where the desktop form provides an unambiguous writable response field, a phone text box is available; use the iPhone keyboard microphone to dictate. Tap **Send answer** and confirm the passkey before anything is sent.

Permission requests use **Allow once / Deny**. Answer choices, custom text and stop actions have distinct signed action types; an answer cannot become a permission approval. Each signing challenge has a two-minute lifetime. If a question remains pending, Windows can issue a fresh challenge only after rechecking the same exact native question; old signatures cannot answer the new challenge. Changed, answered, revoked or offline requests are rejected.

A **Stop this task** control is offered only for a single current ChatGPT/Codex task with a matching visible window and one accessible Stop control. It is bound to that task's turn and requires explicit review and phone confirmation. Ambiguous controls and unsupported apps stay on the PC. This is not unrestricted remote control of every AI app.

After a local answer is submitted, Orby discards older request scans and clears the answered overlay. The journal reader now follows complete appended lines rather than rereading a long conversation on every update. A submitted reply is still distinguished from confirmed resolution and successful tool execution.

## Read activity

The phone groups readable activity by provider and project. It shows the current step and task count instead of mirroring the desktop conversation. Task viewing covers available ChatGPT, Claude and Gemini contexts. Interactive question, permission and stop handling currently covers supported ChatGPT/Codex controls. Claude/Gemini arbitrary desktop actions are not implemented.

Keep the Windows PC, relay and tunnel awake and online. The Home Screen app need not stay open for permitted notifications, but it must open to fetch the exact current request and confirm your answer. A sleeping PC cannot carry out phone decisions.

## Pairing and reset

For a first connection, run `Start-PhoneAccess.cmd`, open Windows **Settings → Phone access → Create invitation / QR code**, and use the five-minute invitation in the phone app. Connect with a passkey and compare the complete fingerprint before trusting the phone on the PC. Enable **Let trusted phones answer questions and permissions**, then **Save connection**.

The free temporary tunnel changes hostname after a full stop/start. That requires fresh phone pairing and notification permission/subscription on the new address. A relay-only restart preserves the tunnel address. A stable domain/host is not deployed. Revoke old phone entries so they do not fill the four-phone limit.

Disable phone access or revoke the phone to stop sharing. You can also turn notifications off in the phone app. Disconnection cannot undo an already accepted action. Task records use encrypted storage and HTTPS; the relay host can read task text, so this is not end-to-end encryption.

## Evidence and limits

The earlier physical iPhone test verified pairing, task display over mobile data and a passkey-signed no-action denial independently checked against the Windows-pinned key. The new notification, five-minute handoff, typed-response and stop paths have automated browser/relay/native fixture checks. Home Screen Lock Screen test notification delivery has now been confirmed on the physical iPhone. A live five-minute question handoff/response and real custom response/Stop still need the user's iPhone test.

`scripts/Run-PhoneConnectionCheck.ps1` can repeat a harmless ten-minute passkey diagnostic. It never enters the real permission queue or grants access. The physical result is separate from a real native permission click.

The native iPhone app and Live Activity extension previously compiled for simulator and unsigned device on [the cloud Mac](https://github.com/kevinenas/Orby/actions/runs/39993496758). Signing, native installation and native APNs/Live Activity delivery remain deferred under the free-version choice.


Desktop request controls must remain accessible to Windows. For a handoff test, keep the relevant chat visible and Windows unlocked; lock only the phone. An unreadable, hidden or ambiguous desktop request cannot be answered remotely through this UI-based adapter. A brief accessibility redraw does not restart an unchanged question timer, but a missing request for more than ten seconds ends continuity. Changing the question, choices, app window or journal task/turn invalidates its prior review.


While a supported question waits on the PC, the notch shows a five-minute countdown. The small closed notch also keeps that time visible. Unavailable phone/controls pause the handoff. The desktop card closes only once the relay acknowledges the current question. Premature project alerts are suppressed while a desktop review is waiting; the phone instead explains that the question is still waiting on the PC. An actual question notification is separate and opens its review. A native response marked stale is not a confirmed successful answer.
