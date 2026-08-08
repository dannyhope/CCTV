# CCTV — Specification

How CCTV should work. This is the source of truth for behaviour; if code, README or
notes disagree with this document, change them to match — or change this document
first when the product decision has moved on.

## Purpose

CCTV records what happens on your screen so you can review how you spent your time,
spot bottlenecks and increase throughput. It takes a screenshot every minute and
compiles each day into a time-lapse video. It also extracts on-screen text via
macOS OCR so that text can later be searched by time.

## Shape of the app

A menu bar accessory app. No dock icon, no main window. Everything is driven from the
menu bar item.

## Capture

- Every 60 seconds, all connected displays are captured at 2x via ScreenCaptureKit.
- Saved as JPEG at 70% quality, no cursor, one file per display.
- Capture does not start on its own; the user starts it from the menu.
- After each display image is saved, macOS Vision OCR (`VNRecognizeTextRequest`,
  accurate recognition with language correction) extracts the on-screen text.
- OCR is best-effort: a recognition or store failure must not prevent the screenshot
  from being kept.

## OCR storage

OCR output is stored under `~/Library/Application Support/CCTV/ocr/` and **outlives**
screenshot deletion after video compilation, so a future search UI can still use it.

```
ocr/
  verbatim/YYYY-MM-DD/
    display-0_HH-mm-ss.json
  index.json
```

### Verbatim records

One JSON file per capture, named to mirror the screenshot. Fields:

| Field | Meaning |
| --- | --- |
| `timestamp` | ISO8601 UTC instant of the capture |
| `displayIndex` | Display that was captured |
| `text` | Full OCR string for that image |

### Term index

`ocr/index.json` is an inverted index mapping each term to the list of capture
timestamps (ISO8601 UTC) where it appeared:

```json
{
  "invoice": ["2026-08-08T15:31:00Z", "2026-08-08T15:32:00Z"],
  "netlify": ["2026-08-08T15:31:00Z"]
}
```

- Terms are lowercased tokens of length ≥ 2 matching `[a-z0-9][a-z0-9_-]*`.
- A term receives a capture's timestamp at most once for that capture.
- Index updates are serialized so concurrent multi-display captures cannot corrupt
  the file.

No search UI is part of this behaviour yet; the stores exist so one can be added later.

## Compilation

- H.264 MP4 at 30 FPS, one video per display per day.
- Runs automatically between 00:05 and 00:10, and on wake for any of the last 7 days
  that has screenshots but no video.
- Screenshots for a day are deleted once its video compiles. OCR data is kept.

## Storage

`~/Library/Application Support/CCTV/`, with `screenshots/YYYY-MM-DD/`,
`videos/YYYY-MM-DD.mp4`, and `ocr/` as above.

**Open Storage Folder** reveals that folder, creating it first if capture has never run.

## Known constraints

- Compilation uses the system timezone, so the midnight window follows local time.
