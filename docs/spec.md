# CCTV — Specification

How CCTV should work. This is the source of truth for behaviour; if code, README or
notes disagree with this document, change them to match — or change this document
first when the product decision has moved on.

## Purpose

CCTV records what happens on your screen so you can review how you spent your time,
spot bottlenecks and increase throughput. It takes a screenshot every minute and
compiles each day into a time-lapse video.

## Shape of the app

No main window. Controls live in a single menu, reachable from the menu bar icon and/or
the Dock depending on the **Show In** preference:

| Show In | Menu bar icon | Dock icon |
| --- | --- | --- |
| Menu Bar (default) | Yes | No |
| Dock | No | Yes |
| Both | Yes | Yes |

The choice persists across launches. When the menu bar icon is hidden, the same menu is
available from the Dock (Dock menu, and a click on the Dock icon pops it up). The setup
window is the only other surface.

## Permissions

CCTV cannot function without macOS Screen & System Audio Recording access. Permission
handling is a first-class part of launch, not an error case.

### On launch

1. Check every permission CCTV needs. Today that is Screen & System Audio Recording.
2. Do not trust the TCC preflight alone. Probe with ScreenCaptureKit as well —
   after an ad-hoc rebuild, System Settings can still show CCTV as allowed while
   `CGPreflightScreenCaptureAccess()` stays false (or the reverse: preflight can
   flip before the running process can capture).
3. If capture already works, carry on silently. Nothing is shown.
4. If anything is missing:
   - Trigger the system's own prompt **at most once ever** (persisted), so the
     first-run path stays native without re-stacking that dialog on every launch
     or rebuild.
   - Show the setup window as the persistent fallback. After the first ask, this
     is the only prompt — no more system dialogs on relaunch.
   - Poll preflight once a second. Probe ScreenCaptureKit sparingly (on open, when
     preflight flips, and on a slow cadence), because a live probe can re-trigger
     the system permission dialog.

### Setup window

A short onboarding card: why CCTV needs screen recording, and one obvious next step.

- **First ask** — headline `Allow screen recording`, short reason line.
- **After the first ask** (typical after a rebuild) — headline
  `Turn screen recording off and on`, explaining that Settings can still show
  CCTV as allowed while this build cannot capture. Footer reinforces the same.
- **Open Settings** — deep links to the Screen & System Audio Recording privacy pane.
- **Show in Finder** — for when the app isn't listed and has to be added with `+`
  (explained in the button’s tooltip, not in the body copy).

The window floats above other apps so its live status stays visible while the user is
in System Settings. It updates itself the moment permission is granted; the user never
has to press a refresh button.

### Confirming a grant actually works

A granted permission does not always reach the already-running process. So once every
permission reads as granted, CCTV attempts a real capture:

- If it succeeds, the window reports success and stops polling.
- If it fails, the window explains that macOS only hands the access over after a
  restart, and offers a **Restart CCTV** button.

### While running

- Permission revoked mid-session stops capture rather than accumulating silent
  failures, and the menu bar returns to its blocked state.
- A capture failure is re-checked against the live permission state. A genuine error
  is reported as an error; a permission problem reopens the setup window.

### Blocked state in the menu bar

- Icon becomes a camera with a badge, distinct from both capturing and idle.
- Status reads `Blocked — screen recording permission needed`.
- Start Capturing and Take Screenshot Now are disabled.
- A `Grant Screen Recording Permission…` item reopens the setup window.

## Capture

- Every 60 seconds, all connected displays are captured at 2x via ScreenCaptureKit.
- Saved as JPEG at 70% quality, no cursor, one file per display.
- Capture does not start on its own; the user starts it from the menu.
- Each successful capture plays a brief menu bar shutter animation on the camera lens
  (iris closes, then opens, ~140ms) so a shot is felt without opening the menu.

## Compilation

- H.264 MP4 at 30 FPS, one video per display per day.
- Runs automatically between 00:05 and 00:10, and on wake for any of the last 7 days
  that has screenshots but no video.
- Screenshots for a day are deleted once its video compiles.

## Storage

`~/Library/Application Support/CCTV/`, with `screenshots/YYYY-MM-DD/` and
`videos/YYYY-MM-DD.mp4`.

**Open Storage Folder** always reveals that folder, creating it first if capture has
never run. The location stays inspectable from first launch, and the menu item never
appears to do nothing.

## Known constraints

- The build signs the app ad hoc (`codesign --sign -`). macOS ties screen recording
  access to the signature, so **every rebuild needs a fresh grant**. Each rebuild
  stamps the build number into the display name, bundle id
  (`co.uk.dannyhope.cctv.<n>`), and app filename (`CCTV-<n>.app`) so System Settings
  never shows an older “CCTV” entry as if it applied to this binary. Grant the
  numbered app (e.g. **CCTV 9**); remove stale plain **CCTV** entries when you see
  them. A stable signing identity would avoid re-granting after every rebuild.
- Compilation uses the system timezone, so the midnight window follows local time.

## Development

Day-to-day work uses `.build/release/CCTV-<n>.app` via `make run` (or `make watch` to
rebuild and relaunch on save). `/Applications/CCTV-<n>.app` is only for a deliberate
`make install` — it is not updated by ordinary rebuilds. There is no live code reload;
Swift must be recompiled, but quit → rebuild → relaunch is one command.

The preferred local project address is `cctv.local`, recorded in the repository root
as `.local-domain`. CCTV is a pure native AppKit app and does not bind a local HTTP
server, so it has no development HTTP port, browser live-reload workflow, or
portless URL route. `make run` checks the hostname mapping for consistency but does
not start a server. The shared Bombay port-80 proxy therefore needs no route for
`cctv.local`; assigning `cctv.local` to development port `5284` would be incorrect.

Set `CCTV_FORCE_PERMISSION_DENIED=1` to rehearse the permission flow without changing
real system settings:

```bash
open --env CCTV_FORCE_PERMISSION_DENIED=1 .build/release/CCTV-<n>.app
```
