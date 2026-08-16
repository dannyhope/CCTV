# CCTV — Design

How CCTV should look. Source of truth for visual design; keep code and this document
in step.

## Principles

- Native AppKit throughout. No custom chrome, no bespoke controls, nothing that
  fights the system appearance.
- Light and dark mode come free by using system colours only — `labelColor`,
  `secondaryLabelColor`, `tertiaryLabelColor`, `controlAccentColor`, `systemGreen`.
- SF Symbols for every icon, so weights and sizes track the system.
- The app is invisible until it needs something. Surfaces appear only when there is a
  decision for the user to make.
- Prefer sparse copy. One headline, one supporting line, one obvious action.

## Menu bar item

A single SF Symbol conveys state, so it reads at menu bar size without colour:

| State | Symbol |
| --- | --- |
| Capturing | `camera.fill` |
| Idle | `camera` |
| Blocked on permission | `camera.badge.ellipsis` |

When a screenshot is taken (scheduled or manual), the lens plays a tiny shutter blink:
white iris blades close from the rim inward, hold fully shut for a beat, then open again
(~140ms total). Close eases in; open eases out — close-then-open, like a real shutter.
Skipped when the menu bar icon is hidden. No badge, colour shift, or notification.

The first menu item is always a disabled status line in the form `Status: …`, so the
current state is legible before the user reads any actions.

## Show In

A **Show In** submenu offers three radio options — Menu Bar, Dock, Both — using standard
checkmark state. No separate preferences window. The Dock uses the same menu contents as
the status item.

## Setup window

Shown only when a permission is missing. Feels like a short onboarding card, not a
settings form.

- Title `CCTV`. Titled and closable, no resize, floating level.
- 340pt content column, 32pt side insets, 36pt top / 28pt bottom, height fits content.
- Everything centred. No separators, no multi-paragraph guidance.

**Hero** — `lock.shield.fill` at 44pt in the accent colour, then a 20pt semibold
headline and a single 13pt secondary supporting line.

| State | Headline | Supporting line |
| --- | --- | --- |
| First ask | `Allow screen recording` | `CCTV photographs every display once a minute.` |
| After first ask / rebuild | `Turn screen recording off and on` | `Settings can still show CCTV as allowed after a rebuild. Switch the CCTV toggle off, then on again.` |

**Status** — a quiet 12pt medium label with a small symbol:

| State | Symbol | Colour |
| --- | --- | --- |
| Required | `circle.dotted` | `secondaryLabelColor` |
| Granted | `checkmark.circle.fill` | `systemGreen` |

**Actions** — one large primary push button (`Open Settings`), then a borderless
accent text button (`Show in Finder`). Finder’s tooltip covers the rare “add with +”
case; that explanation does not appear inline.

**Footer** — 11pt tertiary text. Short states only: waiting (`This updates when you
switch it on.` / `If it’s already on, switch it off and on again.`), checking, all
set, or restart needed. The `Restart CCTV` button appears here only when a restart
is genuinely required.

## Tone

Short, specific, second person. Prefer a clear action over explaining the OS.
Avoid "error", "failed", and permission jargon where a description of the situation
will do.
