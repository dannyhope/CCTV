# run /ux-lint
**Broadcast:** 3a499bf4-960b-45e2-b295-2276d69f13bb
**Readiness:** auto-refined
**Roadmap:** now

## Auto-investigation
**Investigated:** 2026-02-17

### Findings
- This is a macOS menu bar app with a minimal UI: a status bar icon + NSMenu dropdown
- The sole UX surface is the menu: status line, toggle, compile, screenshot, open folder, about, quit
- No windows, panels, or forms — the "interface" is entirely menu-based
- Icon changes between `camera.fill` (capturing) and `camera` (idle) to reflect state
- Status line shows: "Status: Capturing (N screenshots today)" or "Status: Idle (N screenshots today)"
- No screenshots of the running app are available in the repo; ux-lint would need to review code only (or Danny could provide a screenshot)
- The ux-lint skill supports code review mode — no screenshot needed to produce findings

### Scope
- Files relevant to audit: `Sources/CCTV/StatusBarController.swift` (entire menu UX)
- Estimated complexity: small — this is a code-only UX audit of a simple menu
- No changes to code required for the audit itself; findings would generate follow-on `.in/` tasks

### Questions for refinement
1. Should the audit be done against code alone, or can you provide a screenshot of the live menu?
2. Should findings be filed as new `.in/` tasks, or just reported in a one-off document?

### Related items
- `run /ux-lint` (`.in/refined/run-ux-lint.md`) — **duplicate** — same title, same Broadcast ID `3a499bf4-960b-45e2-b295-2276d69f13bb`; that version is already `refined`. This file should be closed/merged.

### Suggested renames
1. `ux-audit-menu-bar-interface.md` — outcome-oriented, names the specific UI being audited
2. `run-ux-lint-on-status-bar-menu.md` — more specific than current name
