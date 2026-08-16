import AppKit

/// Where CCTV surfaces itself on the Mac.
enum AppPresence: String, CaseIterable {
	case menuBar
	case dock
	case both

	static let defaultsKey = "appPresence"

	var title: String {
		switch self {
		case .menuBar: return "Menu Bar"
		case .dock: return "Dock"
		case .both: return "Both"
		}
	}

	var activationPolicy: NSApplication.ActivationPolicy {
		switch self {
		case .menuBar: return .accessory
		case .dock, .both: return .regular
		}
	}

	var showsMenuBarIcon: Bool {
		self != .dock
	}

	var showsDockIcon: Bool {
		self != .menuBar
	}

	static var current: AppPresence {
		get {
			guard
				let raw = UserDefaults.standard.string(forKey: defaultsKey),
				let value = AppPresence(rawValue: raw)
			else {
				return .menuBar
			}
			return value
		}
		set {
			UserDefaults.standard.set(newValue.rawValue, forKey: defaultsKey)
		}
	}

	/// Applies Dock visibility. Menu bar icon visibility is handled by the status item.
	@MainActor
	static func applyActivationPolicy() {
		NSApp.setActivationPolicy(current.activationPolicy)
	}
}
