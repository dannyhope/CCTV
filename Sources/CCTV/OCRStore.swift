import Foundation

/// Persists OCR output as verbatim per-capture records and an inverted term→times index.
actor OCRStore {
	static let shared = OCRStore()

	private struct VerbatimRecord: Encodable {
		let timestamp: String
		let displayIndex: Int
		let text: String
	}

	private let isoFormatter: ISO8601DateFormatter = {
		let formatter = ISO8601DateFormatter()
		formatter.formatOptions = [.withInternetDateTime]
		return formatter
	}()

	private let encoder: JSONEncoder = {
		let encoder = JSONEncoder()
		encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
		return encoder
	}()

	func store(text: String, displayIndex: Int, date: Date) throws {
		let timestamp = isoFormatter.string(from: date)
		try writeVerbatim(
			text: text,
			displayIndex: displayIndex,
			date: date,
			timestamp: timestamp
		)
		try updateIndex(text: text, timestamp: timestamp)
	}

	private func writeVerbatim(
		text: String,
		displayIndex: Int,
		date: Date,
		timestamp: String
	) throws {
		let directory = StorageManager.shared.ocrVerbatimDirectory(for: date)
		try StorageManager.shared.ensureDirectory(directory)

		let filename = StorageManager.shared.ocrVerbatimFilename(
			displayIndex: displayIndex,
			date: date
		)
		let record = VerbatimRecord(
			timestamp: timestamp,
			displayIndex: displayIndex,
			text: text
		)
		let data = try encoder.encode(record)
		try data.write(
			to: directory.appendingPathComponent(filename),
			options: .atomic
		)
	}

	private func updateIndex(text: String, timestamp: String) throws {
		let terms = Self.tokenize(text)
		guard !terms.isEmpty else { return }

		let indexURL = StorageManager.shared.ocrIndexURL
		try StorageManager.shared.ensureDirectory(
			indexURL.deletingLastPathComponent()
		)

		var index = loadIndex(from: indexURL)
		for term in terms {
			var times = index[term] ?? []
			if !times.contains(timestamp) {
				times.append(timestamp)
				index[term] = times
			}
		}

		let data = try JSONSerialization.data(
			withJSONObject: index,
			options: [.prettyPrinted, .sortedKeys]
		)
		try data.write(to: indexURL, options: .atomic)
	}

	private func loadIndex(from url: URL) -> [String: [String]] {
		guard let data = try? Data(contentsOf: url),
			  let object = try? JSONSerialization.jsonObject(with: data),
			  let parsed = object as? [String: [String]] else {
			return [:]
		}
		return parsed
	}

	/// Lowercased tokens of length ≥ 2 matching `[a-z0-9][a-z0-9_-]*`.
	static func tokenize(_ text: String) -> Set<String> {
		let lowered = text.lowercased()
		guard let regex = try? NSRegularExpression(
			pattern: "[a-z0-9][a-z0-9_-]*"
		) else {
			return []
		}

		let range = NSRange(lowered.startIndex..<lowered.endIndex, in: lowered)
		let matches = regex.matches(in: lowered, range: range)

		var terms = Set<String>()
		for match in matches {
			guard let matchRange = Range(match.range, in: lowered) else { continue }
			let term = String(lowered[matchRange])
			if term.count >= 2 {
				terms.insert(term)
			}
		}
		return terms
	}
}
