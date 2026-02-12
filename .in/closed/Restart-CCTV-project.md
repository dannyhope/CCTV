# Build CCTV Mac App
**Refined:** 2026-02-12
**Done when:** A Swift menu bar app runs in the background, captures a screenshot every minute, and compiles each day's screenshots into a single time-lapse video — so Danny can review how he spends his time, spot bottlenecks, and increase throughput.

## Outcome hierarchy
1. App captures screenshots automatically → enables visibility
2. Visibility into time spent → identifies bottlenecks
3. Bottleneck identification → elimination
4. Elimination → increased throughput

## Spec

### Tech
- **Language:** Swift
- **Platform:** macOS
- **UI:** Menu bar icon (no main window)

### Capture
- Screenshot of all screens, every 60 seconds
- Saved as image files to a local directory
- No audio capture

### Video compilation
- Once daily, compile that day's screenshots into a single video file
- Output format suitable for QuickTime playback

### Viewer
- None built-in — use QuickTime / Finder to review videos

### Menu bar
- Start/stop capture
- Basic status (capturing / paused / idle)
