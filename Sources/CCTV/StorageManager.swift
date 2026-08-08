import Foundation

final class StorageManager {
	static let shared = StorageManager()

	let baseURL: URL

	private let dateFormatter: DateFormatter = {
		let f = DateFormatter()
		f.dateFormat = "yyyy-MM-dd"
		return f
	}()

	private let timestampFormatter: DateFormatter = {
		let f = DateFormatter()
		f.dateFormat = "HH-mm-ss"
		return f
	}()

	private init() {
		let appSupport = FileManager.default.urls(
			for: .applicationSupportDirectory,
			in: .userDomainMask
		).first!
		baseURL = appSupport.appendingPathComponent("CCTV", isDirectory: true)
	}

	func screenshotsDirectory(for date: Date = Date()) -> URL {
		let dateString = dateFormatter.string(from: date)
		return baseURL
			.appendingPathComponent("screenshots", isDirectory: true)
			.appendingPathComponent(dateString, isDirectory: true)
	}

	func videoURL(for date: Date = Date()) -> URL {
		let dateString = dateFormatter.string(from: date)
		return baseURL
			.appendingPathComponent("videos", isDirectory: true)
			.appendingPathComponent("\(dateString).mp4")
	}

	func ocrVerbatimDirectory(for date: Date = Date()) -> URL {
		let dateString = dateFormatter.string(from: date)
		return baseURL
			.appendingPathComponent("ocr", isDirectory: true)
			.appendingPathComponent("verbatim", isDirectory: true)
			.appendingPathComponent(dateString, isDirectory: true)
	}

	var ocrIndexURL: URL {
		baseURL
			.appendingPathComponent("ocr", isDirectory: true)
			.appendingPathComponent("index.json")
	}

	func ensureDirectory(_ url: URL) throws {
		try FileManager.default.createDirectory(
			at: url,
			withIntermediateDirectories: true
		)
	}

	func screenshotFilename(displayIndex: Int, date: Date = Date()) -> String {
		let timestamp = timestampFormatter.string(from: date)
		return "display-\(displayIndex)_\(timestamp).jpg"
	}

	func ocrVerbatimFilename(displayIndex: Int, date: Date = Date()) -> String {
		let timestamp = timestampFormatter.string(from: date)
		return "display-\(displayIndex)_\(timestamp).json"
	}

	func screenshotCountToday() -> Int {
		let dir = screenshotsDirectory()
		guard let contents = try? FileManager.default.contentsOfDirectory(
			at: dir,
			includingPropertiesForKeys: nil
		) else {
			return 0
		}
		return contents.filter { $0.pathExtension == "jpg" }.count
	}

	func sortedScreenshots(for date: Date = Date(), displayIndex: Int? = nil) -> [URL] {
		let dir = screenshotsDirectory(for: date)
		guard let contents = try? FileManager.default.contentsOfDirectory(
			at: dir,
			includingPropertiesForKeys: nil
		) else {
			return []
		}

		var jpgs = contents.filter { $0.pathExtension == "jpg" }

		if let displayIndex = displayIndex {
			jpgs = jpgs.filter { $0.lastPathComponent.hasPrefix("display-\(displayIndex)_") }
		}

		return jpgs.sorted { $0.lastPathComponent < $1.lastPathComponent }
	}

	func displayIndices(for date: Date = Date()) -> [Int] {
		let dir = screenshotsDirectory(for: date)
		guard let contents = try? FileManager.default.contentsOfDirectory(
			at: dir,
			includingPropertiesForKeys: nil
		) else {
			return []
		}

		var indices = Set<Int>()
		for url in contents where url.pathExtension == "jpg" {
			let name = url.lastPathComponent
			if let range = name.range(of: "display-"),
			   let endRange = name.range(of: "_", range: range.upperBound..<name.endIndex) {
				let indexStr = String(name[range.upperBound..<endRange.lowerBound])
				if let idx = Int(indexStr) {
					indices.insert(idx)
				}
			}
		}
		return indices.sorted()
	}

	func deleteScreenshots(for date: Date) throws {
		let dir = screenshotsDirectory(for: date)
		if FileManager.default.fileExists(atPath: dir.path) {
			try FileManager.default.removeItem(at: dir)
		}
	}
}
