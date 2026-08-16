import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
	private var statusBarController: StatusBarController?

	func applicationDidFinishLaunching(_ notification: Notification) {
		AppPresence.applyActivationPolicy()

		let statusBar = StatusBarController()
		statusBarController = statusBar

		let permissions = PermissionsManager.shared
		permissions.onChange = { [weak statusBar] in
			statusBar?.permissionsDidChange()
			PermissionsWindowController.shared.refresh()
		}

		PermissionsWindowController.shared.onResolved = { [weak statusBar] in
			statusBar?.permissionsDidChange()
		}

		Task { @MainActor in
			// Preflight alone is not enough: after an ad-hoc rebuild, Settings can
			// still show CCTV as allowed while CGPreflight stays false. Probe with
			// ScreenCaptureKit before deciding to show setup.
			let resolution = await permissions.resolveEffectiveAccess()
			statusBar.permissionsDidChange()

			switch resolution {
			case .working:
				return
			case .grantedNeedsRelaunch:
				PermissionsWindowController.shared.present()
			case .denied:
				permissions.requestMissing()
				PermissionsWindowController.shared.present()
			}
		}
	}

	func applicationDidBecomeActive(_ notification: Notification) {
		// Cheap check only — a ScreenCaptureKit probe here can re-show the system
		// dialog every time the user flips between CCTV and System Settings.
		PermissionsManager.shared.checkForChanges()
	}

	func applicationShouldHandleReopen(
		_ sender: NSApplication,
		hasVisibleWindows flag: Bool
	) -> Bool {
		// Dock-only: no menu bar icon, so a Dock click must surface the controls.
		if AppPresence.current == .dock {
			statusBarController?.popUpMenuNearCursor()
		}
		return true
	}

	func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
		guard AppPresence.current.showsDockIcon else { return nil }
		// Copy so the Dock doesn't steal the status item's menu instance.
		return statusBarController?.appMenu.copy() as? NSMenu
	}
}
