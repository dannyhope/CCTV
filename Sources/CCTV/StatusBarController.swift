import AppKit

@MainActor
final class StatusBarController {
	private let statusItem: NSStatusItem
	private let menu = NSMenu()
	private let statusMenuItem = NSMenuItem()
	private let toggleMenuItem = NSMenuItem()

	private let screenshotCapture = ScreenshotCapture()
	private let scheduleController = ScheduleController()
	private let videoCompiler = VideoCompiler()

	init() {
		statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

		if let button = statusItem.button {
			button.image = NSImage(
				systemSymbolName: "camera.fill",
				accessibilityDescription: "CCTV"
			)
		}

		buildMenu()
		statusItem.menu = menu

		scheduleController.onCapture = { [weak self] in
			self?.captureScreenshot()
		}
		scheduleController.onStatusChange = { [weak self] in
			self?.updateStatus()
		}

		updateStatus()
	}

	private func buildMenu() {
		statusMenuItem.isEnabled = false
		menu.addItem(statusMenuItem)
		menu.addItem(.separator())

		toggleMenuItem.target = self
		toggleMenuItem.action = #selector(toggleCapture)
		menu.addItem(toggleMenuItem)

		let compileItem = NSMenuItem(
			title: "Compile Today's Video",
			action: #selector(compileVideo),
			keyEquivalent: ""
		)
		compileItem.target = self
		menu.addItem(compileItem)

		menu.addItem(.separator())

		let takeScreenshotItem = NSMenuItem(
			title: "Take Screenshot Now",
			action: #selector(takeScreenshotNow),
			keyEquivalent: ""
		)
		takeScreenshotItem.target = self
		menu.addItem(takeScreenshotItem)

		let openFolderItem = NSMenuItem(
			title: "Open Storage Folder",
			action: #selector(openStorageFolder),
			keyEquivalent: ""
		)
		openFolderItem.target = self
		menu.addItem(openFolderItem)

		menu.addItem(.separator())

		let aboutItem = NSMenuItem(
			title: "About CCTV",
			action: #selector(showAbout),
			keyEquivalent: ""
		)
		aboutItem.target = self
		menu.addItem(aboutItem)

		menu.addItem(.separator())

		let quitItem = NSMenuItem(
			title: "Quit",
			action: #selector(NSApplication.terminate(_:)),
			keyEquivalent: "q"
		)
		menu.addItem(quitItem)
	}

	private func updateStatus() {
		let count = StorageManager.shared.screenshotCountToday()
		let capturing = scheduleController.isRunning

		if capturing {
			statusMenuItem.title = "Status: Capturing (\(count) screenshots today)"
			toggleMenuItem.title = "Stop Capturing"
		} else {
			statusMenuItem.title = "Status: Idle (\(count) screenshots today)"
			toggleMenuItem.title = "Start Capturing"
		}

		if let button = statusItem.button {
			button.image = NSImage(
				systemSymbolName: capturing ? "camera.fill" : "camera",
				accessibilityDescription: "CCTV"
			)
		}
	}

	@objc private func toggleCapture() {
		if scheduleController.isRunning {
			scheduleController.stop()
		} else {
			scheduleController.start()
		}
		updateStatus()
	}

	@objc private func takeScreenshotNow() {
		captureScreenshot()
	}

	private func captureScreenshot() {
		Task {
			do {
				try await screenshotCapture.capture()
				await MainActor.run { updateStatus() }
			} catch {
				await MainActor.run {
					statusMenuItem.title = "Status: Error — \(error.localizedDescription)"
				}
			}
		}
	}

	@objc private func compileVideo() {
		statusMenuItem.title = "Status: Compiling video…"
		Task {
			do {
				let url = try await videoCompiler.compileToday()
				await MainActor.run {
					statusMenuItem.title = "Status: Video compiled"
					NSWorkspace.shared.open(url)
				}
			} catch {
				await MainActor.run {
					statusMenuItem.title = "Status: Compile failed — \(error.localizedDescription)"
				}
			}
		}
	}

	@objc private func openStorageFolder() {
		let url = StorageManager.shared.baseURL
		NSWorkspace.shared.open(url)
	}

	@objc private func showAbout() {
		let alert = NSAlert()
		alert.messageText = "CCTV v0.3.0"
		alert.informativeText = "Captures periodic screenshots and compiles daily time-lapse videos.\n\nA Danny Hope product\nhttps://dannyhope.co.uk"
		alert.alertStyle = .informational
		alert.addButton(withTitle: "OK")
		alert.addButton(withTitle: "Visit Website")

		let response = alert.runModal()
		if response == .alertSecondButtonReturn {
			if let url = URL(string: "https://dannyhope.co.uk") {
				NSWorkspace.shared.open(url)
			}
		}
	}
}
