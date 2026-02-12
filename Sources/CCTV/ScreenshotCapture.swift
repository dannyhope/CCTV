import AppKit
import ScreenCaptureKit

final class ScreenshotCapture {
	func capture() async throws {
		let content = try await SCShareableContent.excludingDesktopWindows(
			false,
			onScreenWindowsOnly: true
		)

		let displays = content.displays
		guard !displays.isEmpty else {
			throw CaptureError.noDisplays
		}

		let now = Date()
		let dir = StorageManager.shared.screenshotsDirectory(for: now)
		try StorageManager.shared.ensureDirectory(dir)

		for (index, display) in displays.enumerated() {
			let filter = SCContentFilter(display: display, excludingWindows: [])

			let config = SCStreamConfiguration()
			config.width = display.width * 2
			config.height = display.height * 2
			config.showsCursor = false

			let image = try await SCScreenshotManager.captureImage(
				contentFilter: filter,
				configuration: config
			)

			let filename = StorageManager.shared.screenshotFilename(
				displayIndex: index,
				date: now
			)
			let fileURL = dir.appendingPathComponent(filename)

			try saveAsJPEG(image: image, to: fileURL, quality: 0.7)
		}
	}

	private func saveAsJPEG(image: CGImage, to url: URL, quality: CGFloat) throws {
		let rep = NSBitmapImageRep(cgImage: image)
		guard let data = rep.representation(
			using: .jpeg,
			properties: [.compressionFactor: quality]
		) else {
			throw CaptureError.encodingFailed
		}
		try data.write(to: url)
	}
}

enum CaptureError: LocalizedError {
	case noDisplays
	case encodingFailed

	var errorDescription: String? {
		switch self {
		case .noDisplays:
			return "No displays found"
		case .encodingFailed:
			return "Failed to encode screenshot as JPEG"
		}
	}
}
