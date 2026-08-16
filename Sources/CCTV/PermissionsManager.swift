import AppKit
import CoreGraphics
import ScreenCaptureKit

struct Permission: Sendable {
	enum Kind: String, Sendable {
		case screenRecording
	}

	let id: Kind
	let title: String
	let reason: String
	let instructions: String
	let settingsURL: URL?
	/// Fast TCC preflight. Can disagree with reality after an ad-hoc re-sign.
	let isPreflightGranted: @Sendable () -> Bool
	/// The system's own prompt, where the permission has one.
	let request: (@Sendable () -> Void)?
}

extension Permission {
	/// Set CCTV_FORCE_PERMISSION_DENIED=1 to rehearse the onboarding flow without
	/// revoking real access in System Settings.
	static let isForcedDenied = ProcessInfo.processInfo
		.environment["CCTV_FORCE_PERMISSION_DENIED"] == "1"

	static let screenRecording = Permission(
		id: .screenRecording,
		title: "Screen & System Audio Recording",
		reason: "CCTV takes a screenshot of every display once a minute. Without this it cannot see your screen, so there is nothing to record.",
		instructions: "Switch CCTV on under Privacy & Security › Screen & System Audio Recording. If CCTV isn't in the list, click + and pick it. If it already looks on, turn it off and on again — a rebuild can leave a stale entry.",
		settingsURL: URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"),
		isPreflightGranted: { !Permission.isForcedDenied && CGPreflightScreenCaptureAccess() },
		request: { _ = CGRequestScreenCaptureAccess() }
	)
}

enum AccessResolution: Equatable {
	/// ScreenCaptureKit can see displays in this process.
	case working
	/// TCC says granted, but this process still can't capture — restart needed.
	case grantedNeedsRelaunch
	/// Not available to this process.
	case denied
}

@MainActor
final class PermissionsManager {
	static let shared = PermissionsManager()

	private static let didRequestScreenRecordingKey = "didRequestScreenRecording"

	let all: [Permission] = [.screenRecording]

	/// Fires when the granted state of any permission changes.
	var onChange: (() -> Void)?

	private var pollTimer: Timer?
	private var promptedKinds: Set<Permission.Kind> = []
	private var lastSeenGranted: Set<Permission.Kind> = []
	/// Set when a live ScreenCaptureKit probe succeeds. Preflight alone can stay
	/// false while Settings still shows an older CCTV build as allowed.
	private var captureVerifiedKinds: Set<Permission.Kind> = []
	/// Avoid hammering ScreenCaptureKit — each probe can re-surface the system dialog.
	private var lastCaptureProbeAt: Date?
	private var lastPolledPreflight = false
	private let captureProbeMinimumInterval: TimeInterval = 5

	private init() {
		lastSeenGranted = grantedKinds()
		lastPolledPreflight = Permission.screenRecording.isPreflightGranted()
	}

	var missing: [Permission] {
		all.filter { !isGranted($0) }
	}

	var allGranted: Bool {
		missing.isEmpty
	}

	/// True once we've fired the native prompt (or the user has been through setup).
	/// Used to stop re-stacking the system dialog on every launch.
	var hasRequestedScreenRecording: Bool {
		UserDefaults.standard.bool(forKey: Self.didRequestScreenRecordingKey)
	}

	func isGranted(_ permission: Permission) -> Bool {
		if captureVerifiedKinds.contains(permission.id) { return true }
		return permission.isPreflightGranted()
	}

	/// Triggers the system prompt for anything missing, at most once ever so
	/// relaunches (and stale Settings toggles after rebuilds) don't pester.
	func requestMissing() {
		for permission in missing where !promptedKinds.contains(permission.id) {
			promptedKinds.insert(permission.id)
			guard permission.id == .screenRecording else {
				permission.request?()
				continue
			}
			guard !hasRequestedScreenRecording else { continue }
			UserDefaults.standard.set(true, forKey: Self.didRequestScreenRecordingKey)
			permission.request?()
		}
	}

	func openSettings(for permission: Permission) {
		guard let url = permission.settingsURL else { return }
		// Opening Settings counts as having asked — don't also fire the system dialog later.
		if permission.id == .screenRecording {
			UserDefaults.standard.set(true, forKey: Self.didRequestScreenRecordingKey)
		}
		NSWorkspace.shared.open(url)
	}

	/// Adding CCTV by hand in System Settings needs the bundle in Finder.
	func revealAppInFinder() {
		NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL])
	}

	/// macOS sends no notification when a privacy setting is toggled, so poll instead.
	/// Preflight is checked every second; ScreenCaptureKit only on a slow cadence,
	/// because a live probe can re-trigger the system dialog.
	func startPolling() {
		guard pollTimer == nil else { return }
		lastPolledPreflight = Permission.screenRecording.isPreflightGranted()
		let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
			Task { @MainActor in
				guard let self else { return }
				let preflight = Permission.screenRecording.isPreflightGranted()
				let preflightFlipped = preflight != self.lastPolledPreflight
				self.lastPolledPreflight = preflight
				self.checkForChanges()
				_ = await self.resolveEffectiveAccess(forceProbe: preflightFlipped)
			}
		}
		RunLoop.main.add(timer, forMode: .common)
		pollTimer = timer
	}

	func stopPolling() {
		pollTimer?.invalidate()
		pollTimer = nil
	}

	func checkForChanges() {
		let granted = grantedKinds()
		guard granted != lastSeenGranted else { return }
		lastSeenGranted = granted
		onChange?()
	}

	/// Probe with ScreenCaptureKit and treat success as granted even when preflight
	/// still says no.
	@discardableResult
	func resolveEffectiveAccess(forceProbe: Bool = true) async -> AccessResolution {
		let shouldProbe = forceProbe || shouldProbeCapture()
		let works = shouldProbe ? await verifyScreenRecordingWorks() : captureVerifiedKinds.contains(.screenRecording)

		if shouldProbe {
			lastCaptureProbeAt = Date()
		}

		let resolution: AccessResolution

		if works {
			captureVerifiedKinds.insert(.screenRecording)
			resolution = .working
		} else if Permission.screenRecording.isPreflightGranted() {
			resolution = .grantedNeedsRelaunch
		} else {
			captureVerifiedKinds.remove(.screenRecording)
			resolution = .denied
		}

		let granted = grantedKinds()
		if granted != lastSeenGranted {
			lastSeenGranted = granted
			onChange?()
		}
		return resolution
	}

	/// Confirms capture works in this process rather than trusting the preflight
	/// check, which can flip before the running process can use the access — or
	/// stay false after a rebuild while System Settings still looks granted.
	func verifyScreenRecordingWorks() async -> Bool {
		guard !Permission.isForcedDenied else { return false }

		do {
			_ = try await SCShareableContent.excludingDesktopWindows(
				false,
				onScreenWindowsOnly: true
			)
			return true
		} catch {
			return false
		}
	}

	func relaunch() {
		let configuration = NSWorkspace.OpenConfiguration()
		configuration.createsNewApplicationInstance = true
		NSWorkspace.shared.openApplication(
			at: Bundle.main.bundleURL,
			configuration: configuration
		) { _, _ in
			Task { @MainActor in NSApp.terminate(nil) }
		}
	}

	private func shouldProbeCapture() -> Bool {
		guard let lastCaptureProbeAt else { return true }
		return Date().timeIntervalSince(lastCaptureProbeAt) >= captureProbeMinimumInterval
	}

	private func grantedKinds() -> Set<Permission.Kind> {
		Set(all.filter { isGranted($0) }.map(\.id))
	}
}
