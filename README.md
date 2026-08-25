# CCTV – Time-Lapse Screenshot Recorder

A macOS menu bar application that captures periodic screenshots and compiles them into daily time-lapse videos.

## Overview

CCTV runs as a menu bar app and captures a screenshot of all connected displays every 60 seconds. At midnight (0:05–0:10), the app automatically compiles the day's screenshots into an MP4 video file (30 FPS) that plays back as a time-lapse.

**Use case:** Review how you spend your time, identify bottlenecks, and increase throughput.

## Features

- **Guided permission setup** – Checks on launch that it can record the screen, and walks you through granting access if it can't
- **Automatic screenshotting** – Captures all displays every 60 seconds (no audio)
- **Daily video compilation** – Automatically compiles screenshots into MP4 format each day
- **Menu bar / Dock presence** – Show in the menu bar, the Dock, or both (`Show In` in the menu)
- **Menu control** – Start/stop capturing, compile videos manually, view storage folder
- **Resume on wake** – Resumes capturing after sleep and catches up on missed compilations
- **Multi-display support** – Captures all connected displays; creates separate videos for each if needed
- **Low footprint** – No main window; defaults to menu bar only

## Building

### Requirements
- macOS 14.0 or later
- Swift 5.10+

### Build and Run

Native Swift can’t hot-reload like a web app — a rebuild is required — but you do **not**
need to copy into `/Applications` while developing. Work from the project build:

```bash
cd "$(dirname "$0")"

# Quit any running CCTV, rebuild, codesign, relaunch (.build/release/CCTV-<n>.app)
make run

# Same, automatically, whenever you save a Swift / Info.plist file (needs fswatch)
make watch

# Optional: install that build into /Applications/CCTV-<n>.app for Login Items / daily use
make install

make clean
```

Dev launches use `.build/release/CCTV-<n>.app` (e.g. `CCTV-9.app`). Each rebuild bumps
`CFBundleVersion` and stamps that number into the **display name**, **bundle id**, and
**.app filename** so Finder and Screen Recording settings can’t mix this build up with
an older “CCTV”. Check **About CCTV** for `v0.3.0 (n)`; marketing version stays until
you change it on purpose.

Ad-hoc signing means macOS needs a fresh Screen Recording grant after rebuilds — grant
the numbered app (e.g. **CCTV 9**), not a leftover plain **CCTV** entry.

## Storage

Screenshots and videos are saved to:
```
~/Library/Application Support/CCTV/
├── screenshots/
│   ├── YYYY-MM-DD/
│   │   ├── display-0_HH-MM-SS.jpg
│   │   ├── display-0_HH-MM-SS.jpg
│   │   └── ...
│   └── ...
└── videos/
    ├── YYYY-MM-DD.mp4
    ├── YYYY-MM-DD-display-1.mp4
    └── ...
```

Screenshots are automatically deleted after successful video compilation.

## Menu Options

(Available from the menu bar icon and/or the Dock, depending on **Show In**.)

- **Status** – Shows current state (Capturing/Idle/Blocked) and screenshot count for today
- **Grant Screen Recording Permission…** – Only shown when access is missing; opens the setup window
- **Start/Stop Capturing** – Toggle automatic 60-second capture interval
- **Compile Today's Video** – Manually compile today's screenshots into video
- **Take Screenshot Now** – Capture immediately without waiting for the next interval
- **Open Storage Folder** – Browse screenshots and videos in Finder
- **Show In** – Menu Bar, Dock, or Both
- **About CCTV** – App version and website link
- **Quit** – Stop the app

## How It Works

### Capture Phase
1. Every 60 seconds, the app uses `ScreenCaptureKit` to capture all displays at 2x resolution
2. Each display is saved as a JPEG with 70% compression
3. Screenshots are timestamped and organized by date

### Compilation Phase
- Every 5 minutes, the app checks if it's 00:05–00:10 (midnight window)
- If yes and today's screenshots exist but no video compiled yet, compilation begins
- On wake from sleep, the app checks the last 7 days for uncompiled screenshots and compiles any missing

### Video Format
- **Codec:** H.264
- **Frame rate:** 30 FPS
- **Container:** MP4
- **Playback:** Compatible with QuickTime, VLC, and all standard video players

## Installation

1. Build the app: `make run`
2. Once running, the app will appear in the menu bar as a camera icon
3. To keep it running on startup, add the app to **System Preferences > General > Login Items**

## Permissions

CCTV needs **Screen & System Audio Recording** access. On launch it checks for it, and
if it's missing the app opens a setup window that links straight to the right pane in
System Settings and updates itself the moment you grant access. The macOS permission
dialog is shown at most once; after that CCTV relies on its own setup window so it
doesn't keep nagging.

Because `make` signs the app ad hoc, macOS treats each rebuild as a new app. System
Settings may still show CCTV as on from an older build — turn the entry off and on
again, or remove and re-add it. To rehearse the flow without
touching real settings:

```bash
open --env CCTV_FORCE_PERMISSION_DENIED=1 .build/release/CCTV.app
```

## Notes

- Videos are compiled at midnight UTC, not local time (adjust system timezone if needed)
- Multi-display setups create separate video files per display
- Storage grows at ~1–2 GB per day depending on display resolution and activity

---

A Danny Hope product – https://dannyhope.co.uk
