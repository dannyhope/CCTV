# Later: port the extension to Safari and Firefox

**Readiness:** auto-refined
**Roadmap:** now

## Task

Port this browser extension to Safari and Firefox, preserving the existing
Chrome behaviour and user experience.

## Acceptance criteria

- Confirm the supported Safari and Firefox versions.
- Identify and resolve API, manifest, permissions, and packaging differences.
- Test the ported extension in both browsers.
- Update build, release, installation, and support documentation.

## Auto-investigation
**Investigated:** 2026-09-03

### Findings
- This repository is currently a pure native Swift/AppKit macOS application, not a browser extension.
- Capture is implemented through ScreenCaptureKit in `Sources/CCTV/ScreenshotCapture.swift`; the app has no WebExtension source, manifest, browser-facing JavaScript, or browser packaging configuration.
- The product specification describes a menu-bar/Dock application with macOS screen-recording permissions and local screenshot/video storage (`docs/spec.md`), which cannot be ported to Safari or Firefox as a like-for-like browser extension without a new product surface and architecture.
- The current build/release flow is Swift Package Manager plus ad-hoc signed `.app` bundles via `Makefile`; it does not produce a Chrome extension artifact.

### Scope
- Decide whether this is intended to become a separate browser extension product, or whether the task was captured against the wrong repository.
- If a browser extension is desired here, define the browser-visible job, data flow between the extension and the native CCTV app, and supported platforms before implementation.
- Estimated complexity: large.

### Proposed implementation
1. Confirm the product decision and identify the source repository or extension code to port.
2. If starting from CCTV, write a browser-extension architecture/spec covering extension UI, background/service-worker responsibilities, native messaging or server integration, permissions, privacy, and storage.
3. Build a standards-based WebExtension core, then add Safari-specific packaging/conversion and Firefox manifest/signing/review configuration.
4. Create browser-specific test matrices and release/install/support documentation; preserve the native app’s existing macOS behaviour and build flow.

### Questions for refinement
1. **Is this task for this CCTV repository, or should it target another repository containing the Chrome extension?**

   **Answer:**

2. **What should the browser extension do, and how should it relate to CCTV’s native screen capture?** Options include a companion control panel, a browser-tab capture tool, or a separate product.

   **Answer:**

3. **Which Safari and Firefox versions/platforms must be supported, and what distribution channels are intended?** For example, Safari on macOS via Safari Web Extension packaging/App Store, and Firefox desktop via AMO.

   **Answer:**

### Documentation impact
- Update `docs/spec.md` and `docs/design.md` only after the product boundary and browser-extension user experience are decided.
- Add browser build, release, installation, support, privacy, and permission documentation once the extension architecture is defined.

### Related items
- _(parent will fill)_
