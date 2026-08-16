import AppKit

@MainActor
final class StatusBarController {
	private let statusItem: NSStatusItem
	private let menu = NSMenu()
	private let statusMenuItem = NSMenuItem()
	private let toggleMenuItem = NSMenuItem()
	private let permissionsMenuItem = NSMenuItem()
	private let permissionsSeparator = NSMenuItem.separator()
	private let takeScreenshotMenuItem = NSMenuItem()
	private var presenceMenuItems: [AppPresence: NSMenuItem] = [:]

	private let screenshotCapture = ScreenshotCapture()
	private let scheduleController = ScheduleController()
	private let videoCompiler = VideoCompiler()

	/// SF Symbol currently shown in the menu bar (without shutter animation).
	private var currentSymbolName = "camera.fill"
	/// In-flight shutter frame callbacks; cancelled when status resets mid-blink.
	private var shutterWorkItems: [DispatchWorkItem] = []

	/// Same menu as the status item — used for the Dock menu when the status item is hidden.
	var appMenu: NSMenu { menu }

	init() {
		statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

		buildMenu()
		statusItem.menu = menu

		scheduleController.onCapture = { [weak self] in
			self?.captureScreenshot()
		}
		scheduleController.onStatusChange = { [weak self] in
			self?.updateStatus()
		}

		applyPresence()
		updateStatus()
	}

	/// Shows or hides the menu bar icon to match the current presence preference.
	func applyPresence() {
		statusItem.isVisible = AppPresence.current.showsMenuBarIcon
		refreshPresenceMenuChecks()
	}

	/// Pops the control menu near the cursor — used when Dock-only and the user clicks the Dock icon.
	func popUpMenuNearCursor() {
		let location = NSEvent.mouseLocation
		menu.popUp(positioning: nil, at: location, in: nil)
	}

	private func buildMenu() {
		// Enabling is driven by permission state, not by target/action lookup.
		menu.autoenablesItems = false

		statusMenuItem.isEnabled = false
		menu.addItem(statusMenuItem)

		permissionsMenuItem.title = "Grant Screen Recording Permission…"
		permissionsMenuItem.target = self
		permissionsMenuItem.action = #selector(showPermissions)
		menu.addItem(permissionsSeparator)
		menu.addItem(permissionsMenuItem)

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

		takeScreenshotMenuItem.title = "Take Screenshot Now"
		takeScreenshotMenuItem.action = #selector(takeScreenshotNow)
		takeScreenshotMenuItem.target = self
		menu.addItem(takeScreenshotMenuItem)

		let openFolderItem = NSMenuItem(
			title: "Open Storage Folder",
			action: #selector(openStorageFolder),
			keyEquivalent: ""
		)
		openFolderItem.target = self
		menu.addItem(openFolderItem)

		menu.addItem(.separator())

		let showInMenu = NSMenu(title: "Show In")
		for presence in AppPresence.allCases {
			let item = NSMenuItem(
				title: presence.title,
				action: #selector(selectPresence(_:)),
				keyEquivalent: ""
			)
			item.target = self
			item.representedObject = presence.rawValue
			showInMenu.addItem(item)
			presenceMenuItems[presence] = item
		}
		let showInItem = NSMenuItem(title: "Show In", action: nil, keyEquivalent: "")
		showInItem.submenu = showInMenu
		menu.addItem(showInItem)
		refreshPresenceMenuChecks()

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
		let permitted = PermissionsManager.shared.allGranted

		permissionsMenuItem.isHidden = permitted
		permissionsSeparator.isHidden = permitted
		toggleMenuItem.isEnabled = permitted
		takeScreenshotMenuItem.isEnabled = permitted

		if !permitted {
			statusMenuItem.title = "Status: Blocked — screen recording permission needed"
			toggleMenuItem.title = "Start Capturing"
			currentSymbolName = "camera.badge.ellipsis"
		} else if capturing {
			statusMenuItem.title = "Status: Capturing (\(count) screenshots today)"
			toggleMenuItem.title = "Stop Capturing"
			currentSymbolName = "camera.fill"
		} else {
			statusMenuItem.title = "Status: Idle (\(count) screenshots today)"
			toggleMenuItem.title = "Start Capturing"
			currentSymbolName = "camera"
		}

		applyStatusImage(lensCoverage: 0)
	}

	/// Sets the menu bar glyph. `lensCoverage` 0 = open iris (normal template);
	/// 1 = shutter fully closed (lens cutout solid white).
	private func applyStatusImage(lensCoverage: CGFloat) {
		if lensCoverage <= 0 {
			cancelShutterAnimation()
		}
		guard let button = statusItem.button else { return }
		button.image = makeStatusImage(
			symbol: currentSymbolName,
			lensCoverage: lensCoverage
		)
	}

	private func makeStatusImage(symbol: String, lensCoverage: CGFloat) -> NSImage? {
		guard let base = NSImage(
			systemSymbolName: symbol,
			accessibilityDescription: "CCTV"
		) else {
			return nil
		}

		let coverage = min(1, max(0, lensCoverage))
		guard coverage > 0.001 else {
			base.isTemplate = true
			return base
		}

		let pointSize: CGFloat = 16
		let config = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .regular)
		guard let symbolImage = base.withSymbolConfiguration(config) else {
			base.isTemplate = true
			return base
		}

		let bodyColor = menuBarGlyphColor()
		let glyphSize = symbolImage.size
		let canvas = NSSize(
			width: max(glyphSize.width, pointSize),
			height: max(glyphSize.height, pointSize)
		)

		// Tint the glyph first so the shutter fill is not re-coloured.
		let tinted = NSImage(size: glyphSize, flipped: false) { rect in
			symbolImage.draw(in: rect)
			bodyColor.set()
			rect.fill(using: .sourceAtop)
			return true
		}

		let shuttered = NSImage(size: canvas, flipped: false) { bounds in
			// Iris behind the lens cutout: white blades close from the rim inward,
			// then the open aperture grows again on the way out.
			// Nudged down slightly: SF camera glyphs have a viewfinder hump on top.
			let maxDiameter = pointSize * 0.36
			let center = NSPoint(
				x: bounds.midX,
				y: bounds.midY - pointSize * 0.06
			)
			let lensRect = NSRect(
				x: center.x - maxDiameter / 2,
				y: center.y - maxDiameter / 2,
				width: maxDiameter,
				height: maxDiameter
			)

			NSColor.white.setFill()
			NSBezierPath(ovalIn: lensRect).fill()

			let openDiameter = maxDiameter * (1 - coverage)
			if openDiameter > 0.75 {
				let openRect = NSRect(
					x: center.x - openDiameter / 2,
					y: center.y - openDiameter / 2,
					width: openDiameter,
					height: openDiameter
				)
				NSGraphicsContext.saveGraphicsState()
				NSGraphicsContext.current?.compositingOperation = .destinationOut
				NSColor.black.setFill()
				NSBezierPath(ovalIn: openRect).fill()
				NSGraphicsContext.restoreGraphicsState()
			}

			let glyphRect = NSRect(
				x: (bounds.width - glyphSize.width) / 2,
				y: (bounds.height - glyphSize.height) / 2,
				width: glyphSize.width,
				height: glyphSize.height
			)
			tinted.draw(in: glyphRect)
			return true
		}
		shuttered.isTemplate = false
		return shuttered
	}

	/// Menu bar extras are black on a light bar and white on a dark bar.
	private func menuBarGlyphColor() -> NSColor {
		let appearance = statusItem.button?.effectiveAppearance ?? NSApp.effectiveAppearance
		let match = appearance.bestMatch(from: [.darkAqua, .aqua])
		return match == .darkAqua ? .white : .black
	}

	private func cancelShutterAnimation() {
		for item in shutterWorkItems {
			item.cancel()
		}
		shutterWorkItems.removeAll()
	}

	/// Close then open — a real shutter fires by closing over the exposure, then opening.
	private func playShutterAnimation() {
		guard AppPresence.current.showsMenuBarIcon else { return }

		cancelShutterAnimation()

		// ~140ms total: snappy close, brief fully-shut beat, snappy open.
		let frameDuration: TimeInterval = 0.018
		let closeFrames = 4
		let holdFrames = 2
		let openFrames = 4

		var coverages: [CGFloat] = []
		for i in 1...closeFrames {
			let t = CGFloat(i) / CGFloat(closeFrames)
			// Ease-in so it gathers then snaps shut.
			coverages.append(t * t)
		}
		for _ in 0..<holdFrames {
			coverages.append(1)
		}
		for i in 1...openFrames {
			let t = CGFloat(i) / CGFloat(openFrames)
			// Ease-out so it pops open, then settles.
			let opened = 1 - (1 - t) * (1 - t)
			coverages.append(1 - opened)
		}

		for (index, coverage) in coverages.enumerated() {
			let work = DispatchWorkItem { [weak self] in
				guard let self else { return }
				// Don't route through applyStatusImage(0) mid-sequence — that cancels us.
				guard let button = self.statusItem.button else { return }
				button.image = self.makeStatusImage(
					symbol: self.currentSymbolName,
					lensCoverage: coverage
				)
			}
			shutterWorkItems.append(work)
			DispatchQueue.main.asyncAfter(
				deadline: .now() + frameDuration * Double(index),
				execute: work
			)
		}

		let restore = DispatchWorkItem { [weak self] in
			self?.applyStatusImage(lensCoverage: 0)
		}
		shutterWorkItems.append(restore)
		DispatchQueue.main.asyncAfter(
			deadline: .now() + frameDuration * Double(coverages.count),
			execute: restore
		)
	}

	private func refreshPresenceMenuChecks() {
		let current = AppPresence.current
		for (presence, item) in presenceMenuItems {
			item.state = presence == current ? .on : .off
		}
	}

	@objc private func selectPresence(_ sender: NSMenuItem) {
		guard
			let raw = sender.representedObject as? String,
			let presence = AppPresence(rawValue: raw)
		else {
			return
		}

		AppPresence.current = presence
		AppPresence.applyActivationPolicy()
		applyPresence()

		if presence.showsDockIcon {
			NSApp.activate(ignoringOtherApps: true)
		}
	}

	/// Lets the app react when a permission is granted or revoked while running.
	func permissionsDidChange() {
		if !PermissionsManager.shared.allGranted && scheduleController.isRunning {
			scheduleController.stop()
		}
		updateStatus()
	}

	@objc private func toggleCapture() {
		guard PermissionsManager.shared.allGranted else {
			showPermissions()
			return
		}

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

	@objc private func showPermissions() {
		PermissionsWindowController.shared.present()
	}

	private func captureScreenshot() {
		guard PermissionsManager.shared.allGranted else {
			updateStatus()
			showPermissions()
			return
		}

		Task {
			do {
				try await screenshotCapture.capture()
				await MainActor.run {
					updateStatus()
					playShutterAnimation()
				}
			} catch {
				await MainActor.run { handleCaptureFailure(error) }
			}
		}
	}

	/// Capture can also fail because access was revoked, or because a grant made
	/// while CCTV was running hasn't reached this process yet.
	private func handleCaptureFailure(_ error: Error) {
		Task { @MainActor in
			let works = await PermissionsManager.shared.verifyScreenRecordingWorks()
			if works {
				statusMenuItem.title = "Status: Error — \(error.localizedDescription)"
			} else {
				scheduleController.stop()
				updateStatus()
				showPermissions()
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

	/// The folder is only created when the first screenshot is saved, and NSWorkspace
	/// silently does nothing when asked to open a path that isn't there yet.
	@objc private func openStorageFolder() {
		let url = StorageManager.shared.baseURL

		do {
			try StorageManager.shared.ensureDirectory(url)
		} catch {
			statusMenuItem.title = "Status: Couldn't create the storage folder — \(error.localizedDescription)"
			return
		}

		if !NSWorkspace.shared.open(url) {
			statusMenuItem.title = "Status: Couldn't open the storage folder"
		}
	}

	@objc private func showAbout() {
		let alert = NSAlert()
		let info = Bundle.main.infoDictionary
		let version = info?["CFBundleShortVersionString"] as? String ?? "0.3.0"
		let build = info?["CFBundleVersion"] as? String ?? "?"
		alert.messageText = "CCTV v\(version) (\(build))"
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
