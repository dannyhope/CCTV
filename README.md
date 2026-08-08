# CCTV – Time-Lapse Screenshot Recorder

A macOS menu bar application that captures periodic screenshots and compiles them into daily time-lapse videos.

## Overview

CCTV runs as a menu bar app and captures a screenshot of all connected displays every 60 seconds. At midnight (0:05–0:10), the app automatically compiles the day's screenshots into an MP4 video file (30 FPS) that plays back as a time-lapse.

**Use case:** Review how you spend your time, identify bottlenecks, and increase throughput.

## Features

- **Automatic screenshotting** – Captures all displays every 60 seconds (no audio)
- **OCR text index** – Extracts on-screen text with macOS Vision OCR and stores it verbatim plus a term→times index for later search
- **Daily video compilation** – Automatically compiles screenshots into MP4 format each day
- **Menu bar control** – Start/stop capturing, compile videos manually, view storage folder
- **Resume on wake** – Resumes capturing after sleep and catches up on missed compilations
- **Multi-display support** – Captures all connected displays; creates separate videos for each if needed
- **Low footprint** – Runs as an accessory app (no main window)

## Building

### Requirements
- macOS 14.0 or later
- Swift 5.10+

### Build and Run

```bash
cd "$(dirname "$0")"

# Build the app
make build

# Build, bundle, codesign, and run
make run

# Clean build artefacts
make clean
```

The bundled app will be located at `.build/release/CCTV.app`.

## Storage

Screenshots, videos, and OCR text are saved to:
```
~/Library/Application Support/CCTV/
├── screenshots/
│   ├── YYYY-MM-DD/
│   │   ├── display-0_HH-mm-ss.jpg
│   │   └── ...
│   └── ...
├── videos/
│   ├── YYYY-MM-DD.mp4
│   ├── YYYY-MM-DD-display-1.mp4
│   └── ...
└── ocr/
    ├── verbatim/
    │   └── YYYY-MM-DD/
    │       ├── display-0_HH-mm-ss.json
    │       └── ...
    └── index.json
```

Screenshots are automatically deleted after successful video compilation. OCR verbatim
records and the term index are kept so they can power a future search UI.

## Menu Bar Options

- **Status** – Shows current state (Capturing/Idle) and screenshot count for today
- **Start/Stop Capturing** – Toggle automatic 60-second capture interval
- **Compile Today's Video** – Manually compile today's screenshots into video
- **Take Screenshot Now** – Capture immediately without waiting for the next interval
- **Open Storage Folder** – Browse screenshots and videos in Finder
- **About CCTV** – App version and website link
- **Quit** – Stop the app

## How It Works

### Capture Phase
1. Every 60 seconds, the app uses `ScreenCaptureKit` to capture all displays at 2x resolution
2. Each display is saved as a JPEG with 70% compression
3. Screenshots are timestamped and organized by date
4. Vision OCR extracts text from each image; the full text is stored under `ocr/verbatim/` and terms are appended to `ocr/index.json`

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

## Notes

- The app requests screen capture permission on first run (required for ScreenCaptureKit)
- Videos are compiled at midnight UTC, not local time (adjust system timezone if needed)
- Multi-display setups create separate video files per display
- Storage grows at ~1–2 GB per day depending on display resolution and activity

---

A Danny Hope product – https://dannyhope.co.uk
