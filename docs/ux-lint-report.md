# UX Lint Report — CCTV v0.3.0

**Date:** 2026-02-17
**Scope:** macOS menu bar app (Swift/AppKit)
**Files analysed:** StatusBarController.swift, ScheduleController.swift, ScreenshotCapture.swift, VideoCompiler.swift, StorageManager.swift, AppDelegate.swift, main.swift, Info.plist

## 🔴 Critical Issues

### 1. No state persistence
Capturing state resets to "Idle" on every app launch. If the user was capturing before quitting/restarting, they must manually re-enable it.
- **Question for the product manager:** If CCTV was capturing before it closed, should it start capturing again when it reopens, or should the user always press Start?
- **Rule violated:** State Persistence

### 2. Missing keyboard shortcuts
Only "Quit" has a keyboard equivalent (`Cmd+Q`). Start/Stop Capturing, Take Screenshot Now, and Compile Today's Video have no key equivalents.
- **Question for the product manager:** Which actions, if any, should have keyboard shortcuts? For example, should Cmd+Shift+S start or stop capturing, and should Cmd+Shift+T take a screenshot immediately?
- **Rule violated:** Keyboard Shortcuts

### 3. No settings area
Capture interval (60s), JPEG quality (0.7), video FPS (30), compilation time window (00:05–00:10), and storage location are all hardcoded.
- **Question for the product manager:** Which settings should users be able to change? Possible examples are capture frequency, image quality, storage location, and starting CCTV at login.
- **Rule violated:** Settings Area

## 🟠 Medium Issues

### 4. Silent capture — no feedback
When a screenshot is taken, there is no visual confirmation. The menu icon doesn't flash, there's no notification.
- **Question for the product manager:** How should CCTV show that a screenshot was taken: a brief icon animation, a notification, or both?
- **Rule violated:** Autosave Feedback / Visibility of system status

### 5. Modal About dialogue
`showAbout()` uses `NSAlert.runModal()`, which blocks the application.
- **Recommendation:** Use `NSApp.orderFrontStandardAboutPanel` or a non-modal window.
- **Rule violated:** Inline Expansion over Pop-ups

### 6. Errors only visible in menu
When capture or compilation fails, the error is shown in the status menu item, which is only visible when the menu is open.
- **Question for the product manager:** If something goes wrong, should macOS show a notification even when the CCTV menu is closed?
- **Rule violated:** Visibility of system status / Error recovery

### 7. No undo for screenshot deletion
Compiling a video automatically deletes all screenshots for that day with no warning, no undo, and no recovery.
- **Question for the product manager:** After a video is created, should CCTV move the screenshots to the Trash, keep them for a set time, or let the user choose?
- **Rule violated:** User control and freedom / Error prevention

### 8. No compilation progress
"Status: Compiling video…" shown with no progress indicator. Compilation could take minutes.
- **Question for the product manager:** While a video is being created, what progress should CCTV show—for example, “342 of 720 frames”?
- **Rule violated:** Visibility of system status

### 9. Outdated tech debt document
`docs/tech-debt.md` references "script" and "AppleScript" issues from before the Swift rewrite.
- **Recommendation:** Update to reflect the current Swift implementation.
- **Rule violated:** Match between system and real world

## 🟢 Minor Issues

### 10. No Launch at Login
A background capture utility should offer to auto-launch at login.
- **Question for the product manager:** Should CCTV offer an option to start automatically when the user logs in?

### 11. No disk space awareness
At 1–2 GB/day, storage can fill up quickly. No warning when disk space is low.
- **Question for the product manager:** Should CCTV show how much storage it uses and warn when free disk space is low? If so, what warning threshold is appropriate?

### 12. Subtle recording indicator
Filled vs unfilled camera icon distinction is subtle at menu bar size.
- **Question for the product manager:** Should the capturing icon be more noticeable, such as adding a red dot, even though the current design is monochrome?

## ✅ Good Practices Observed

- Clean accessibility description on status bar button
- Clear status text showing state and screenshot count
- Graceful sleep/wake handling with 7-day catchup
- Multi-display support with separate video files
- Non-blocking async operations
- Danny Hope attribution with correct domain
- Well-separated architecture
- Descriptive error messages with LocalizedError conformance
