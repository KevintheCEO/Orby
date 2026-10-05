ORBY v5.3 - PET PERSONALITY AND MUSIC PLAYER

This build adds nine small personality clips: six randomized idle gestures and three thinking variations. They are finite, low-amplitude movements that return to neutral and never replace a real task state. The white Orby and colored task companions share animation clocks, so each companion performs the animation belonging to its own task.

Soft sound cues are included for selected idle gestures and success, attention, error, and tap actions. Sounds are enabled by default and can be disabled from Settings. Quiet mode and Reduced motion suppress the appropriate cues.

Click the Spotify cover in the notch to open the compact in-app music panel. It shows the high-resolution cover, title, artist, live position, duration, play/pause, previous, next, shuffle, repeat, and a seek bar when Spotify exposes that capability. Volume buttons use the existing system-volume bridge. The panel stays inside Orby and does not launch Spotify.

The latest layout keeps this player inside the expanded notch. The cover click expands Orby and switches the notch to its Music tab beside the existing Home, controls, animations, and settings tabs. Home returns to the ChatGPT task view; no separate popup window is used for the normal cover-art flow.

The Spotify bridge targets the exact Spotify Windows media session and rejects stale track seeks. Playback actions are sent through Windows Global System Media Transport Controls. If Windows denies media-session access, Orby keeps the panel available and reports that Spotify is not connected; no credentials or API keys are needed.

Close the old Orby, extract this folder, and run Start-Orby-Debug.cmd.

Orby registers itself to start with Windows by default through the current user's Startup Run entry. You can turn this off with the "Start Orby with Windows" setting. On a restricted Windows profile, use Start-Orby.cmd once after sign-in or add that launcher to the Startup folder.

On launch, Orby plays a short boot glow, waves with its little arms, and then settles into its normal idle behavior. Reduced motion skips the greeting.

Validation: Test-Music-Player.ps1, Test-Pet-Personality.ps1, Test-Animation-Pack.ps1, Test-Idle-Pet.ps1, Test-Mini-Orbys.ps1, Test-Media-Art.ps1, Test-Cover-Layout.ps1, and Test-Task-Pack.ps1 pass locally. Live Spotify playback was not changed by the tests; it must be verified on the user's desktop with Spotify playing.

ORBY v5.1 - NORMAL CHAT STATUS TRACKER
Regular ChatGPT now has an independent UI tracker. When the normal ChatGPT window exposes a Stop or Generating signal, Orby shows LIVE and the visible activity. When a previously active normal response stops, Orby distinguishes STOP, FAIL, NEED and DONE using the newest visible controls/text, then returns to idle after the short result display. Work/Codex task-feed state cannot suppress this normal-chat path.
This tracks broad states and elapsed visible activity. It does not invent a percentage or claim hidden model progress. The tracker requires the ChatGPT window to be visible enough for Windows accessibility inspection; an inaccessible or hidden window is treated as unknown.
Close the old Orby, extract this folder and run Start-Orby-Debug.cmd. Test a normal chat with a long prompt, Stop, a completed answer, and a visible error. NORMAL-CHAT-RESEARCH.txt documents the supported and unsupported approaches.
ORBY v5.0 - SYNCHRONIZED MINI ORBYS
Replaced the four plain compact-header dots with tiny Orby faces. Red, purple, teal and amber correspond to the four companions behind the primary white avatar. Each mini uses the same task, body color, animation clip and animation clock as its companion. Hover shows its task title and action. Unassigned minis dim and become idle; removed tasks unlink their renderer. Approval priority and file/prompt handoff remain intact.
Close old Orby, extract this folder and run Start-Orby-Debug.cmd. NORMAL-CHAT-RESEARCH.txt explains feasible normal-chat tracking and limits. This update does not claim a new working normal-chat tracker or a percentage-complete feed.
ORBY v4.9 - APPROVAL REQUESTS IN THE NOTCH
Recognizes request_permissions both as a direct tool call and inside tools.request_permissions(...) in an exec/custom tool call. Tracks its call_id so unrelated results or background work do not clear a pending request. File access and network permission requests appear as attention with an amber expanded notch, the task title, permission category and Open ChatGPT button. Approval stays in ChatGPT; Orby does not silently grant access.
Tasks needing input/approval take priority over newer running tasks, while all running task companions remain tracked. Answering the matching permission call resumes the task; terminal events clear the request. The event card refreshes when a different pending task or permission action is selected even if it is already showing attention.
Close old Orby, extract this folder and run Start-Orby-Debug.cmd. Source remains PowerShell 5.1 compatible and ASCII safe. Existing multi-task avatars and file/prompt handoff are retained.
ORBY v4.8 - MULTIPLE TASK COMPANIONS
The compact and expanded avatars now show the current white Orby in front with smaller task companions behind it: red for task two, purple for task three, teal for task four and amber for task five. Each companion has its own native animation renderer and follows its own task action and attention state. Companions fade in and are reused across polls; a completed/stopped/failed task removes only its own companion. Reduced motion is respected and removed renderers unsubscribe from the frame loop.
The compact task title adds +N for additional running tasks. Hover the title or avatar to read every active task name and current action, including tasks beyond the five visible characters. The expanded panel retains its task labels. Duplicate chat IDs are filtered so tool calls do not create extra companions. Idle Orby returns to one white avatar.
Close old Orby, extract this folder and run Start-Orby-Debug.cmd. File/prompt paste and send checks from v4.7 are preserved.
ORBY v4.7 - PROMPT CONFIRMATION BEFORE SEND
The user's v4.6 log showed Insert prompt: Prompt insertion was not confirmed, before Send was attempted. The capture includes an enabled Send control. Prompt confirmation now reacquires the composer and polls its ValuePattern and TextPattern for up to five seconds after SetValue. Either exact matching channel can confirm insertion while the other provider channel catches up. Comparison normalizes CRLF/LF and trailing editor line breaks; it preserves spaces, case and internal line breaks and rejects different text. Actual Send invocation and acknowledgement remain in place. Error diagnostics include lengths without storing prompt contents.
Close the old Orby, extract this folder and run Start-Orby-Debug.cmd. Drop files, enter a prompt and press Enter. File paste from v4.6 is preserved. End-to-end live send has not been tested by the agent.
ORBY v4.6 - DIRECT FILE PASTE HANDOFF
After opening a new chat and confirming its message editor is empty, Orby focuses that editor, verifies ChatGPT is foreground and a recognized composer has keyboard focus, places the dropped files in the native Windows FileDrop clipboard format and pastes them with Ctrl+V. This bypasses attachment-menu and file-picker discovery. It waits for every attachment name to appear without an upload error before inserting and verifying the exact prompt, then invokes Send and checks acknowledgement.
The clipboard is materialized before replacement and restored after attachment confirmation or failure, only if Orby's transfer marker remains present. A clipboard change by the user is preserved. Nothing is pasted when focus cannot be verified. Failed handoffs retain files and prompt in Orby. Do not retry a sent-but-unacknowledged message without checking ChatGPT.
Close the old Orby, extract this fresh folder and run Start-Orby-Debug.cmd. Drop a file, enter your prompt and press Enter. This is a desktop handoff, so accepted file formats and size limits depend on ChatGPT.
Local native FileDrop and composer regression tests passed; actual ChatGPT file-paste acceptance and send still require live confirmation.
ORBY v4.5 - ATTACHMENT MENU ACTION SUPPORT
Attachment discovery now accepts InvokePattern and ExpandCollapsePattern instead of requiring InvokePattern. A visible enabled Add files and more menu trigger can therefore be expanded. Already expanded controls are left open. Attachment controls are retried for five seconds while the new chat initializes. Control captures now include supported action patterns to diagnose unavailable controls.
The user capture confirmed a visible enabled Add files and more button. Its actual action patterns were not included in that older capture; live upload/send still requires confirmation. Existing upload-name, prompt and send acknowledgement checks remain in place.
ORBY v4.4 - ASK CHATGPT PLACEHOLDER HANDLING
The real control capture identifies the message editor as Ask ChatGPT. Its 11-character label matches the stopped draft-length check. The composer selector now explicitly recognizes Ask ChatGPT. A ValuePattern value equal to a known composer placeholder label is treated as empty before insertion; genuine different draft text is preserved. TextPattern document content takes priority when it supplies real message text, and placeholder normalization is disabled while verifying the inserted prompt. Send acknowledgement may recognize the restored placeholder as an empty composer.
Capture now includes edit-pattern availability, value length, whether value equals label and text length without recording message contents. Live upload/send remains to be verified; this change removes the specific placeholder/draft check blocker shown in the screenshot.

ORBY v4.3 - COMPOSER SELECTION AND ATTACHMENT HANDOFF
Live app log established that new chat was invoked but the worker stopped at its non-empty draft check before any attachment. Previous lookup matched any edit whose name contained ChatGPT, including unrelated fields. Composer selection now rejects search/address/title labels and ranks prompt-textarea, Message ChatGPT, Ask anything and named prompt controls. It requires an editable ValuePattern and waits up to eight seconds for the new composer to become empty. Draft text is not erased or logged.
Attachment and Send lookups now accept accessible actionable control types and help labels. Attachment labels include Add files and more; native file-picker ownership may be a child app process and is verified by owner HWND chain. Failures at any stage automatically save %LOCALAPPDATA%\Orby\chatgpt-controls.txt. Existing attachment-name and prompt verification remain before Send.
End-to-end upload and send still need live confirmation. No ChatGPT window was visible to the agent when read-only control capture was attempted. Local tests validate selection/routing but do not establish desktop upload success.

ORBY v4.2 - CHATGPT CONTROL DISCOVERY
New chat discovery now checks all accessible control types, shortcut-bearing labels, help labels and new-chat automation IDs. It invokes only a supported InvokePattern on the matched control or its containing button/link. Waits up to four seconds for accessibility initialization. This does not click guessed screen coordinates or substitute New task for New chat.
If no New chat control is available, a local labels-only capture is automatically saved to %LOCALAPPDATA%\Orby\chatgpt-controls.txt. Capture-ChatGPT-Controls.cmd can also create and open this file manually. The capture records Button/Hyperlink/Edit/MenuItem names, IDs, help labels and availability, not composer values or message bodies. This diagnostic is needed to establish the real app accessibility layout if broader discovery still fails.
Live new-chat/upload/send remains unverified in the agent environment. Seven control-label tests and fourteen routed-drop/prompt tests passed.

ORBY v4.1 - CHAT HANDOFF FOCUS AND FASTER ART
ChatGPT handoff: replaced AutomationElement.SetFocus on the app root with native restore/activate and foreground verification. Search now includes Chromium/WebView child HWND accessibility roots. Error messages identify the failed stage. Original empty-draft, attachment and prompt checks remain before sending. Live end-to-end upload/send is still unverified here.
Spotify artwork: dedicated media worker is independent of health/toast/news scanning. Media polls about every 350-450 milliseconds; artwork UI refreshes every 200 milliseconds. A short stabilization refresh after track changes catches late thumbnail updates. Full original image resolution is decoded; WPF uses high-quality scaling. Image quality still depends on the thumbnail Spotify supplies; no invented detail or external artwork downloads.

ORBY v4.0 - DRAG ROUTING FIX
The recording showed files reaching the notch without a visible drop target. Removed an older main-window file-shelf drag handler that intercepted preview events before the composer. The shelf now handles drops only on its own Files-panel drop zone. Composer handlers explicitly receive handled preview events. Native WPF routed drag-over/drop regression now covers an already-handled event and confirms that the target opens, a chip appears, and no upload starts before a prompt.
Close the old app completely before starting this version. Drag a real local file from File Explorer onto the notch, release in the dashed area, then enter a prompt. The actual desktop ChatGPT attachment/send step is still unverified and depends on accessible controls. A Windows privilege mismatch can separately block Explorer drops; the launcher does not request elevation.

ORBY v3.9 - REFERENCE DROP COMPOSER
Reworked the file-drop view to the supplied layout: wide dashed target on drag hover, rounded dark chat panel, file chips at top, Orby beside a full-width bottom prompt bar and arrow button. PreviewDrop captures dropped files before child controls. DragLeave is debounced to avoid immediate collapse during the resize. No actual ChatGPT conversation is embedded in this panel; it collects files and prompt for desktop handoff.
Drop to stage files, type the prompt, Enter or arrow to attempt attachment and send in a new ChatGPT chat. Home closes/discards the staged input; + resets the drop target. Live sending remains dependent on accessible desktop ChatGPT controls and is not verified here. Logs now include FILE DROP received and FILE HANDOFF results, and Capture-Orby-State.cmd includes them.

ORBY v3.8 - DROP FILES, TYPE PROMPT, ENTER TO SEND
Drag files over Orby to expand a drop target. Drop up to 20 files to stage them. Type a prompt in the notch. Enter (or Send to ChatGPT) starts the handoff; Shift+Enter adds a line. Dropping alone never uploads. Prompt/file data is retained if the handoff fails. OK discards the staged selection.
The worker targets the ChatGPT desktop app New chat control, verifies an empty accessible composer, selects attachments through its native picker, waits for visible file names, inserts and verifies the prompt, and invokes an enabled Send button. It checks for composer clearing or Stop generating after Send. If acknowledgement is ambiguous, retry is disabled and the UI asks you to verify ChatGPT. UI changes, inaccessible WebView controls, localization and unsupported file pickers can prevent handoff. No keyboard Send fallback or silent clipboard substitution. There is no API key dependency.
Live end-to-end upload/send is unverified in this restricted environment. Native WPF staging/validation checks passed; actual desktop ChatGPT UI compatibility needs testing. Enter is the explicit user action requesting the external send.

ORBY v3.7 - EVENT CARDS AND FILE HANDOFF
Needs-input/recognized permission events automatically expand a compact amber card and keep it open. Open ChatGPT to review/approve/deny in the real app. Orby does not impersonate Allow/Deny buttons: there is no supported approval API connected here. Recognized journal events include exec_approval_request, apply_patch_approval_request, approval_request and existing request_user_input. Permission prompts absent from the journal/accessibility feed may need further integration.
Task completion automatically shows a compact green gradient card with a native success reaction. The gradient moves gently; reduced motion keeps it still. The card clears after the feed completion display expires or when OK is clicked.
Drop up to 20 files onto the notch. Orby tries the desktop app New chat/New task button, attachment controls, and native Open file picker. This uses accessible English controls. It never presses Send. If controls are unavailable, it copies the file list to the clipboard and clearly asks you to paste into a new chat. The original files are used; folders are ignored. UI automation attachment is not verified against a live desktop session in the agent sandbox.
A confirmed attachment/new-chat workflow still needs testing on your ChatGPT version. No embedded ChatGPT conversation panel or direct permission approval bridge is included. Existing Spotify artwork/task name/idle gestures and no-headphones preference preserved.

ORBY v3.6 - HEADPHONES REMOVED
Headphones are no longer displayed, including in animation previews. Gentle listening movement remains. Task reactions, idle gestures, Spotify cover and task name are preserved.

ORBY v3.5 - SOLID BLUE HEADPHONES
Flat solid-blue headphone band and rounded cushions. No outlines, gradients or accents. Listening bob and hover/click hiding preserved.

ORBY v3.4 - HEADPHONE REDESIGN
Redesigned music headphones: fitted charcoal headband, rounded dark ear cushions, fine edge highlights, subtle blue accent strips. Original hover/click hiding and gentle listening bob preserved. Preview included as Headphones-preview.png.

ORBY v3.3 - LISTENING PET
During music playback Orby wears small headphones and gently bobs. Hovering the avatar hides the headphones; moving away restores them. Clicking hides them for at least two seconds. Pausing stops the listening behavior. Actual task states take priority. Reduced motion suppresses the listening bob. This is a gentle listening gesture, not audio beat detection.

ORBY v3.2 - COVER LAYOUT FIX
Spotify artwork smoothly moves beside the expanded toolbar buttons when the menu opens, then returns beside the compact task name when it closes. It stays clickable. Placement uses actual toolbar coordinates, and reduced motion moves it without an animation.

ORBY v3.1 - NATIVE ARTWORK AND COMPLETION FIX
Fixes the real Spotify thumbnail error: async WinRT stream objects were unprojected COM objects. The stream reader now invokes the declared Windows interfaces, avoiding PowerShell overload resolution errors. Native thumbnail reference regression reproduced the object form and passed the corrected reader. Task working/needs-input/completed/failed/stopped reactions now take priority over desktop notification banners, so completion can play its success hop and checkmark. Task title, album-art click and idle gestures are preserved.

ORBY v3.0 - COMPACT TASK NAME
The compact notch now shows the ChatGPT task name beside the avatar. Long titles shorten with an ellipsis; hover for the full name. Idle shows No active task. Song titles do not overwrite the task name. Spotify cover is a 32-pixel tile to the right of the task name, before the colored status dots. All existing Spotify artwork fixes and idle gestures are included.

ORBY v2.9 - SPOTIFY ARTWORK READER FIX
Uses the .NET Windows Runtime stream bridge to read thumbnails instead of the DataReader/Size path. Missing artwork retries every 5 seconds (poll cadence may add up to 3 seconds); unavailable Windows media service retries every 15 seconds. Cleanup cannot discard successful reads. Each read has a 2.5-second timeout and an 8 MB cap.
If art stays missing, run Capture-Orby-State.cmd from this new build and inspect the MEDIA ART lines in %LOCALAPPDATA%\Orby\orby-state-capture.txt. The capture shows media session app IDs and the exact image/connection error. Song artwork is never substituted with a fake cover.

ORBY v2.8 - IDLE PET PERSONALITY
Orby now chooses small random idle gestures: curious looks, double blinks, little side steps, stretches, daydreaming, tiny hops, and playful bounces. First gesture after 8-16 seconds, then randomized 18-38 second pauses. Gestures avoid immediate repeats and respect individual cooldowns. Idle motion stays within 3 pixels sideways and 4 pixels vertically. Real work, needs-input, completion, failure, stop, music and notifications take priority. AFK sleep is preserved. Reduced motion disables random idle gestures. Preview the four new gestures from the sparkle animation picker.

ORBY v2.7 - SPOTIFY COVER ART
The compact notch shows Spotify album artwork in the center. Click the cover to open Spotify. The cover stays accessible during hover expansion. No song labels are added to the notch; the tooltip shows the song. Paused Spotify keeps its last cover, marked paused in the tooltip. No Spotify session or missing artwork hides the cover. Music must be enabled in settings.
Artwork comes from the local Windows media session, with no API key or external artwork lookup. Spotify must publish a Windows media session and thumbnail. Artwork is read in the background and cached; image decoding occurs only when artwork changes.

V2.6 YOUR ANIMATION PACK
62 supplied animation definitions are compiled into the native procedural renderer.
Use the sparkle button in Orby's toolbar to open the live animation picker.
The picker previews all 62 without changing any real task or starting work.
Auto-connected: boot, idle/blink/cursor attention, thinking/search/command work,
waiting for input, stopped, success/error, notch open/close, notification/reminder,
health warning, break/coffee, volume, media state, AFK sleep/wake and occasional idle gestures.
Reduce motion is available in Settings and the picker; Windows animation preference is respected.
Work loops and particles clear immediately on terminal states. Existing task parser remains authoritative.
The supplied 4500ms watchdog and 60fps target are not adopted: long real tasks and display-sync remain.
Animations that require voice, real progress, headphones, window/drag tracking or updates are
previewable but not automatically triggered without those inputs. Live percentages/audio levels
are never invented. The preview uses demonstration input only for input-bound animations.
Music state is connected, but actual audio-envelope capture is not implemented.
Indicators use Orby's small dot/ring/bubble primitives; this is a Windows-native interpretation.
Your original pack, specification and starter files are preserved under animation-pack.

V2.5 REFERENCE LAYOUT
Restored the requested notch silhouette: straight top edge, rounded bottom corners.
Compact mode is a slim 360x58 strip with the orb and four colored status marks.
Expanded mode is 620x230: toolbar, large orb/task card and four colored task pills.
The pills show real active local task titles. Empty slots show honest desktop statuses.
No demonstration agent names or invented running tasks are shown.
Use the small grid button to open desktop controls (music, alerts, planner, watchlist, files).
Use + for Settings. File drops still open the Files controls.
Preserves fixed-layout native reveal and cursor checks from the stutter fix.

V2.4 OPENING-STUTTER FIX
The outer window and all panel content now retain fixed dimensions.
Only a native reveal mask animates; the text and tabs no longer reflow per frame.
A matching Windows input region keeps areas outside the notch available to other apps.
Hover exit checks the actual cursor position against visible notch bounds rather than
trusting transient MouseLeave notifications during the reveal animation.
Retains display-paced native avatar and motion. Close all older Orby instances before launch.

DISPLAY-SYNC PERFORMANCE UPDATE
Animations use WPF rendering callbacks, following the available display/compositor cadence.
No fixed 18 FPS avatar or 60 FPS spring timer. Refresh rate is detected automatically.
Faster 290ms-response opening and 200ms closing; no per-frame Windows window resizing.
Cached geometry/transforms, native animation, background task-journal reads and fewer UI scans.
Smooth eyelid blink. Home footer and debug capture include display Hz and measured render FPS.
The detected refresh is a target, not a guarantee: load, Windows and graphics affect delivered FPS.
Your current display was detected as 165Hz; see VALIDATION.txt for measured results.

COUCOU SOURCE MERGE
Spring-based opening and the 340 ms non-overshooting close curve ported from Coucou.
Refined dark palette and a new Files tab. Drag files onto the notch or use Add file.
Copies are local under %LOCALAPPDATA%\Orby\inbox; originals are never moved.
Copies happen in the background, accept up to 100 MB, and never overwrite duplicates.
No automatic deletion: manage shelf copies yourself through Open shelf folder.
Nothing is uploaded or sent to an AI by the file shelf. Show selected reveals the file.

SMOOTH UI UPDATE
Eased hover expansion/collapse, centered resizing, 180ms exit grace, tab fade/slide,
rounded controls with animated hover and press feedback. Animations can reverse smoothly.

ORBY v2.6 - DESKTOP COMPANION

START
Close the older Orbit/Orby first. Extract this entire ZIP into a fresh folder.
Double-click Start-Orby-Debug.cmd for the first run, or Start-Orby.cmd for background use.
Requires Windows and built-in Windows PowerShell 5.1. No API key required.
Hover over the notch to expand. Move away to collapse. Right-click Orby's tray icon
for Settings, focus, quiet mode, reposition, and Quit. Double-click the tray for Settings.

HOME
Media: previous, play/pause, next, volume and mute. Song/artist use Windows media sessions
when available. The orb dances while a connected session reports playing.
Computer health: battery, network adapter connection and CPU; reacts to changes.
Downloads: watches the selected folder, reports partial-file bytes and stable new files.
This is file detection, not a browser's true download percentage.
Quick actions: files, chosen apps, screenshot, focus, settings.
Screenshots save under %LOCALAPPDATA%\Orby\Screenshots only when clicked.

ALERTS
Local alert inbox, quiet mode, preview toggle, app-name filtering, and a test alert.
Full Windows notification access depends on Windows permission and application identity.
This portable build falls back to accessible visible notification banners when unavailable;
it cannot promise complete Notification Center history. Settings reports the connection.

PLANNER
Add persistent reminders in minutes, cancel selected reminders, and start/stop focus.
Configure recurring break reminders and focus length in Settings.
Orby must be running to deliver reminders. Overdue reminders are delivered after restart.

WATCHLIST
Add comma-separated tickers or company names. Public headlines are explicitly opt-in.
Enable 'Allow Google News searches for my watchlist topics' in Settings to connect.
That sends those topics to news.google.com about every five minutes. Initial stories seed
inbox without a burst of alerts; later new stories produce at most three alerts per check.
This is a headline feed, not live stock prices or a trading recommendation.
Connection failures are shown. No automatic external searches are enabled by default.

AI TASKS
Preserves the local ChatGPT/Codex task journal bridge, title/action, STOP/FAIL/NEEDS YOU,
and reference white-orb animations. Cloud-only tasks are not verified.
The local feed clears stale working state rather than keeping LIVE indefinitely.

SETTINGS AND DATA
Settings, reminders, inbox and diagnostics live locally in %LOCALAPPDATA%\Orby.
You choose favorite .exe apps, download folder, app filters, media session, focus/breaks,
quiet mode and previews. No auto-start registration or service installation is performed.

DIAGNOSTICS
Capture-Orby-State.cmd: recent Orby event/state records.
Capture-ChatGPT-Logs.cmd and Capture-ChatGPT-UI.cmd: existing raw ChatGPT capture helpers.
Those older helpers may save their capture under OrbitNotch; see the printed location.
Test-StateMachine.cmd, Test-PetFeed.cmd, Test-LocalTasks.cmd, Test-Desktop.cmd: checks.
See VALIDATION.txt for what was actually verified and what still needs a live manual test.



















V5.1 FIXED WINDOW SELECTION
A hidden secondary ChatGPT renderer is no longer accepted as the active window. Orby skips offscreen process roots so normal-chat activity is read from the visible ChatGPT renderer. Searching/browsing activity is promoted to LIVE even when ChatGPT does not expose a named Stop button.
