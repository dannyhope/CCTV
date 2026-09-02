# Ideas for Screenshot Automation

## Potential Improvements
- Add a simple GUI interface to start/stop the screenshot process
- Product question: Should CCTV take screenshots more often at certain times, such as during working hours?
- Add image compression options to further reduce file size
- Product question: Is opening the finished video in QuickTime enough, or should CCTV include a screen for browsing the screenshot timeline?
- Product question: Should CCTV save a screenshot only when the screen changes?
- Product question: Should CCTV automatically blur faces or other private information?
- Product question: Should CCTV ever send screenshots away from the Mac? If yes, where should they go and what privacy protections are required?

## Existing Tools
- **Chronolapse**: Open-source tool that takes screenshots at intervals
- **Time Sink**: Commercial app that tracks application usage and can take screenshots
- **ScreenFetch**: Command-line tool for system monitoring with screenshot capabilities
- **iSpy**: Open-source camera security software with motion detection

## Helpful Frameworks
- **Electron**: Could be used to build a cross-platform GUI for this tool
- **SwiftUI**: For creating a native macOS application with better integration
- **FFmpeg**: For potentially creating timelapse videos from the screenshots

## Architecture Ideas
- Product question: Should CCTV support several Macs sending screenshots to one central service?
- Product question: Does CCTV need a searchable database about screenshots, or are folders and videos enough?
- Product question: Should other developers be able to add capture or video-processing plugins?
