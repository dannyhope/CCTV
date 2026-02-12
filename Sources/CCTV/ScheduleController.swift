import AppKit

@MainActor
final class ScheduleController {
	private var captureTimer: DispatchSourceTimer?
	private var compilationTimer: DispatchSourceTimer?
	private(set) var isRunning = false

	var onCapture: (() -> Void)?
	var onStatusChange: (() -> Void)?

	private let videoCompiler = VideoCompiler()
	private var lastCompilationCheck = Date()

	func start() {
		guard !isRunning else { return }
		isRunning = true

		let timer = DispatchSource.makeTimerSource(queue: .global())
		timer.schedule(deadline: .now() + 60, repeating: 60)
		timer.setEventHandler { [weak self] in
			Task { @MainActor in
				self?.onCapture?()
			}
		}
		timer.resume()
		captureTimer = timer

		startCompilationTimer()
		setupSleepWakeHandlers()

		onCapture?()
		onStatusChange?()
	}

	func stop() {
		captureTimer?.cancel()
		captureTimer = nil
		compilationTimer?.cancel()
		compilationTimer = nil
		isRunning = false
		onStatusChange?()
	}

	private func startCompilationTimer() {
		let timer = DispatchSource.makeTimerSource(queue: .global())
		timer.schedule(deadline: .now() + 300, repeating: 300)
		timer.setEventHandler { [weak self] in
			Task { @MainActor in
				self?.checkForMissedCompilations()
			}
		}
		timer.resume()
		compilationTimer = timer
	}

	private func checkForMissedCompilations() {
		let calendar = Calendar.current
		let now = Date()

		guard let hour = calendar.dateComponents([.hour, .minute], from: now).hour,
			  let minute = calendar.dateComponents([.hour, .minute], from: now).minute else {
			return
		}

		guard hour == 0 && minute >= 5 && minute <= 10 else { return }

		guard let yesterday = calendar.date(byAdding: .day, value: -1, to: now) else { return }

		let videoURL = StorageManager.shared.videoURL(for: yesterday)
		guard !FileManager.default.fileExists(atPath: videoURL.path) else { return }

		let screenshots = StorageManager.shared.sortedScreenshots(for: yesterday)
		guard !screenshots.isEmpty else { return }

		Task {
			do {
				_ = try await videoCompiler.compile(for: yesterday)
				try StorageManager.shared.deleteScreenshots(for: yesterday)
			} catch {
				// Compilation failed, will retry next check
			}
		}
	}

	private func setupSleepWakeHandlers() {
		let center = NSWorkspace.shared.notificationCenter

		center.addObserver(
			forName: NSWorkspace.didWakeNotification,
			object: nil,
			queue: .main
		) { [weak self] _ in
			Task { @MainActor in
				self?.handleWake()
			}
		}
	}

	private func handleWake() {
		guard isRunning else { return }

		onCapture?()

		let calendar = Calendar.current
		let now = Date()

		var checkDate = calendar.date(byAdding: .day, value: -1, to: now)!
		let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: now)!

		while checkDate > sevenDaysAgo {
			let videoURL = StorageManager.shared.videoURL(for: checkDate)
			let screenshots = StorageManager.shared.sortedScreenshots(for: checkDate)

			if !screenshots.isEmpty && !FileManager.default.fileExists(atPath: videoURL.path) {
				let dateToCompile = checkDate
				Task {
					do {
						_ = try await videoCompiler.compile(for: dateToCompile)
						try StorageManager.shared.deleteScreenshots(for: dateToCompile)
					} catch {
						// Will retry on next wake
					}
				}
			}

			checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate)!
		}
	}
}
