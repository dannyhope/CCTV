# UX Lint Report — CCTV v0.3.0

**Date:** 2026-02-17
**Scope:** macOS menu bar app (Swift/AppKit)
**Files analysed:** StatusBarController.swift, ScheduleController.swift, ScreenshotCapture.swift, VideoCompiler.swift, StorageManager.swift, AppDelegate.swift, main.swift, Info.plist

## 🔴 Critical Issues

### 1. No state persistence
Capturing state resets to "Idle" on every app launch. If the user was capturing before quitting/restarting, they must manually re-enable it.
- **Recommendation:** Persist `isRunning` state to `UserDefaults` and restore it on launch.
- **Rule violated:** State Persistence

### 2. Missing keyboard shortcuts
Only "Quit" has a keyboard equivalent (`Cmd+Q`). Start/Stop Capturing, Take Screenshot Now, and Compile Today's Video have no key equivalents.
- **Recommendation:** Add key equivalents — e.g. `Cmd+Shift+S` for toggle capture, `Cmd+Shift+T` for take screenshot now.
- **Rule violated:** Keyboard Shortcuts

### 3. No settings area
Capture interval (60s), JPEG quality (0.7), video FPS (30), compilation time window (00:05–00:10), and storage location are all hardcoded.
- **Recommendation:** Add a Preferences window with configurable options (interval, quality, storage path, launch at login).
- **Rule violated:** Settings Area

## 🟠 Medium Issues

### 4. Silent capture — no feedback
When a screenshot is taken, there is no visual confirmation. The menu icon doesn't flash, there's no notification.
- **Recommendation:** Briefly animate the menu bar icon when a screenshot is captured. For manual captures, show a transient notification.
- **Rule violated:** Autosave Feedback / Visibility of system status

### 5. Modal About dialogue
`showAbout()` uses `NSAlert.runModal()`, which blocks the application.
- **Recommendation:** Use `NSApp.orderFrontStandardAboutPanel` or a non-modal window.
- **Rule violated:** Inline Expansion over Pop-ups

### 6. Errors only visible in menu
When capture or compilation fails, the error is shown in the status menu item, which is only visible when the menu is open.
- **Recommendation:** Post system notifications for errors so they're visible even when the menu is closed.
- **Rule violated:** Visibility of system status / Error recovery

### 7. No undo for screenshot deletion
Compiling a video automatically deletes all screenshots for that day with no warning, no undo, and no recovery.
- **Recommendation:** Move screenshots to Trash or add a configurable retention period.
- **Rule violated:** User control and freedom / Error prevention

### 8. No compilation progress
"Status: Compiling video…" shown with no progress indicator. Compilation could take minutes.
- **Recommendation:** Show frame count progress (e.g. "Compiling: 342/720 frames...").
- **Rule violated:** Visibility of system status

### 9. Outdated tech debt document
`docs/tech-debt.md` references "script" and "AppleScript" issues from before the Swift rewrite.
- **Recommendation:** Update to reflect the current Swift implementation.
- **Rule violated:** Match between system and real world

## 🟢 Minor Issues

### 10. No Launch at Login
A background capture utility should offer to auto-launch at login.
- **Recommendation:** Add "Launch at Login" menu item using `SMAppService`.

### 11. No disk space awareness
At 1–2 GB/day, storage can fill up quickly. No warning when disk space is low.
- **Recommendation:** Show disk usage in status menu and warn on low space.

### 12. Subtle recording indicator
Filled vs unfilled camera icon distinction is subtle at menu bar size.
- **Recommendation:** Use a more distinctive icon pair (e.g. red dot overlay when capturing).

## ✅ Good Practices Observed

- Clean accessibility description on status bar button
- Clear status text showing state and screenshot count
- Graceful sleep/wake handling with 7-day catchup
- Multi-display support with separate video files
- Non-blocking async operations
- Danny Hope attribution with correct domain
- Well-separated architecture
- Descriptive error messages with LocalizedError conformance
