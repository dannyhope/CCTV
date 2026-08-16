import AppKit

@MainActor
final class PermissionsWindowController: NSObject, NSWindowDelegate {
	static let shared = PermissionsWindowController()

	/// Called once every permission is granted and confirmed working.
	var onResolved: (() -> Void)?

	private let manager = PermissionsManager.shared
	private static let contentWidth: CGFloat = 340

	private var window: NSWindow?
	private var contentStack: NSStackView?
	private var titleLabel = NSTextField(labelWithString: "")
	private var subtitleLabel = NSTextField(wrappingLabelWithString: "")
	private var statusIcon = NSImageView()
	private var statusLabel = NSTextField(labelWithString: "")
	private var actionStack = NSStackView()
	private let footerLabel = NSTextField(wrappingLabelWithString: "")
	private let relaunchButton = NSButton()
	private var isVerifying = false

	private override init() {
		super.init()
	}

	func present() {
		if window == nil {
			window = makeWindow()
		}
		refresh()
		centreOnScreen()
		window?.makeKeyAndOrderFront(nil)
		NSApp.activate()
		manager.startPolling()
		// Re-probe on open: preflight can lag behind a grant that already works.
		Task { @MainActor in
			_ = await manager.resolveEffectiveAccess()
			refresh()
		}
	}

	/// The window grows and shrinks as guidance appears, so track its content.
	private func resizeToFit() {
		guard let window, let contentStack else { return }
		contentStack.layoutSubtreeIfNeeded()
		window.setContentSize(contentStack.fittingSize)
	}

	/// `NSWindow.center` measures against the whole screen, which can leave the
	/// window under the menu bar or past an edge. Place it inside the usable area.
	private func centreOnScreen() {
		guard let window, let screen = NSScreen.main else { return }
		let area = screen.visibleFrame
		let size = window.frame.size
		window.setFrameOrigin(
			NSPoint(
				x: area.midX - size.width / 2,
				y: area.midY - size.height / 2
			)
		)
	}

	func refresh() {
		guard window != nil else { return }

		let granted = manager.allGranted
		updateCopy(isGranted: granted)
		updateStatus(isGranted: granted)

		guard granted else {
			actionStack.isHidden = false
			relaunchButton.isHidden = true
			footerLabel.stringValue = manager.hasRequestedScreenRecording
				? "If it’s already on, switch it off and on again."
				: "This updates when you switch it on."
			resizeToFit()
			return
		}

		actionStack.isHidden = true
		footerLabel.stringValue = "Checking capture…"
		resizeToFit()
		verifyAndFinish()
	}

	func windowWillClose(_ notification: Notification) {
		manager.stopPolling()
		window = nil
		contentStack = nil
	}

	/// A granted permission doesn't always reach the running process, so confirm a
	/// real capture works and offer a relaunch when it doesn't.
	private func verifyAndFinish() {
		guard !isVerifying else { return }
		isVerifying = true

		Task { @MainActor in
			let resolution = await manager.resolveEffectiveAccess()
			isVerifying = false

			updateStatus(isGranted: manager.allGranted)

			switch resolution {
			case .working:
				actionStack.isHidden = true
				footerLabel.stringValue = "All set."
				relaunchButton.isHidden = true
				manager.stopPolling()
				onResolved?()
			case .grantedNeedsRelaunch:
				actionStack.isHidden = true
				footerLabel.stringValue = "macOS needs a restart to hand over access."
				relaunchButton.isHidden = false
			case .denied:
				actionStack.isHidden = false
				footerLabel.stringValue = "This updates when you switch it on."
				relaunchButton.isHidden = true
			}
			resizeToFit()
		}
	}

	private func makeWindow() -> NSWindow {
		let stack = NSStackView()
		stack.orientation = .vertical
		stack.alignment = .centerX
		stack.spacing = 20
		stack.edgeInsets = NSEdgeInsets(top: 36, left: 32, bottom: 28, right: 32)
		stack.translatesAutoresizingMaskIntoConstraints = false

		stack.addView(makeHero(), in: .center)
		stack.addView(makeStatusRow(), in: .center)
		stack.addView(makeActions(), in: .center)

		footerLabel.font = .systemFont(ofSize: 11)
		footerLabel.textColor = .tertiaryLabelColor
		footerLabel.alignment = .center
		footerLabel.preferredMaxLayoutWidth = Self.contentWidth
		stack.addView(footerLabel, in: .center)

		relaunchButton.title = "Restart CCTV"
		relaunchButton.bezelStyle = .rounded
		relaunchButton.controlSize = .large
		relaunchButton.keyEquivalent = "\r"
		relaunchButton.target = self
		relaunchButton.action = #selector(relaunch)
		relaunchButton.isHidden = true
		stack.addView(relaunchButton, in: .center)

		contentStack = stack

		let window = NSWindow(
			contentRect: NSRect(x: 0, y: 0, width: Self.contentWidth + 64, height: 320),
			styleMask: [.titled, .closable],
			backing: .buffered,
			defer: false
		)
		window.title = "CCTV"
		window.delegate = self
		window.isReleasedWhenClosed = false
		window.level = .floating

		let contentView = NSView()
		contentView.addSubview(stack)
		NSLayoutConstraint.activate([
			stack.topAnchor.constraint(equalTo: contentView.topAnchor),
			stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
			stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
			stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
			stack.widthAnchor.constraint(equalToConstant: Self.contentWidth + 64)
		])
		window.contentView = contentView

		return window
	}

	private func makeHero() -> NSView {
		let icon = NSImageView()
		icon.image = NSImage(
			systemSymbolName: "lock.shield.fill",
			accessibilityDescription: nil
		)?.withSymbolConfiguration(.init(pointSize: 44, weight: .medium))
		icon.contentTintColor = .controlAccentColor
		icon.translatesAutoresizingMaskIntoConstraints = false

		titleLabel.stringValue = "Allow screen recording"
		titleLabel.font = .systemFont(ofSize: 20, weight: .semibold)
		titleLabel.alignment = .center

		subtitleLabel.stringValue = "CCTV photographs every display once a minute."
		subtitleLabel.font = .systemFont(ofSize: 13)
		subtitleLabel.textColor = .secondaryLabelColor
		subtitleLabel.alignment = .center
		subtitleLabel.preferredMaxLayoutWidth = Self.contentWidth

		let hero = NSStackView(views: [icon, titleLabel, subtitleLabel])
		hero.orientation = .vertical
		hero.alignment = .centerX
		hero.spacing = 10
		hero.setCustomSpacing(16, after: icon)
		return hero
	}

	private func updateCopy(isGranted: Bool) {
		guard !isGranted else {
			titleLabel.stringValue = "Allow screen recording"
			subtitleLabel.stringValue = "CCTV photographs every display once a minute."
			return
		}

		if manager.hasRequestedScreenRecording {
			titleLabel.stringValue = "Turn screen recording off and on"
			subtitleLabel.stringValue =
				"Settings can still show CCTV as allowed after a rebuild. Switch the CCTV toggle off, then on again."
		} else {
			titleLabel.stringValue = "Allow screen recording"
			subtitleLabel.stringValue = "CCTV photographs every display once a minute."
		}
	}

	private func makeStatusRow() -> NSView {
		statusIcon.translatesAutoresizingMaskIntoConstraints = false
		statusLabel.font = .systemFont(ofSize: 12, weight: .medium)

		let row = NSStackView(views: [statusIcon, statusLabel])
		row.orientation = .horizontal
		row.alignment = .centerY
		row.spacing = 6
		return row
	}

	private func makeActions() -> NSView {
		let openButton = NSButton(
			title: "Open Settings",
			target: self,
			action: #selector(openSettings)
		)
		openButton.bezelStyle = .rounded
		openButton.controlSize = .large
		openButton.keyEquivalent = "\r"
		openButton.setContentHuggingPriority(.defaultLow, for: .horizontal)

		let revealButton = NSButton(
			title: "Show in Finder",
			target: self,
			action: #selector(reveal)
		)
		revealButton.bezelStyle = .recessed
		revealButton.isBordered = false
		revealButton.contentTintColor = .controlAccentColor
		revealButton.toolTip = "If CCTV isn’t listed, add it with +. If it already looks on after a rebuild, turn it off and on again."

		actionStack.setViews([openButton, revealButton], in: .center)
		actionStack.orientation = .vertical
		actionStack.alignment = .centerX
		actionStack.spacing = 10
		actionStack.translatesAutoresizingMaskIntoConstraints = false
		NSLayoutConstraint.activate([
			openButton.widthAnchor.constraint(equalToConstant: 200)
		])
		return actionStack
	}

	private func updateStatus(isGranted: Bool) {
		let symbol = isGranted ? "checkmark.circle.fill" : "circle.dotted"
		statusIcon.image = NSImage(
			systemSymbolName: symbol,
			accessibilityDescription: isGranted ? "Granted" : "Required"
		)?.withSymbolConfiguration(.init(pointSize: 12, weight: .semibold))
		statusIcon.contentTintColor = isGranted ? .systemGreen : .secondaryLabelColor
		statusLabel.stringValue = isGranted ? "Granted" : "Required"
		statusLabel.textColor = isGranted ? .systemGreen : .secondaryLabelColor
	}

	@objc private func openSettings() {
		guard let permission = manager.missing.first ?? manager.all.first else { return }
		manager.openSettings(for: permission)
	}

	@objc private func reveal() {
		manager.revealAppInFinder()
	}

	@objc private func relaunch() {
		manager.relaunch()
	}
}
