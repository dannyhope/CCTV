import Foundation
import AppKit
import XCTest
@testable import CCTV

final class OCRStoreTests: XCTestCase {
	func testOCRProcessorRecognizesScreenshotText() async throws {
		let image = NSImage(size: NSSize(width: 900, height: 180))
		image.lockFocus()
		NSColor.white.setFill()
		NSRect(origin: .zero, size: image.size).fill()
		"Invoice NETLIFY".draw(
			at: NSPoint(x: 40, y: 65),
			withAttributes: [
				.font: NSFont.systemFont(ofSize: 64),
				.foregroundColor: NSColor.black
			]
		)
		image.unlockFocus()

		var proposedRect = NSRect.zero
		let cgImage = try XCTUnwrap(image.cgImage(forProposedRect: &proposedRect, context: nil, hints: nil))
		let text = try await OCRProcessor().recognizeText(in: cgImage)

		XCTAssertTrue(text.lowercased().contains("invoice"))
		XCTAssertTrue(text.lowercased().contains("netlify"))
	}

	func testTokenizeNormalizesAndDeduplicatesTerms() {
		let terms = OCRStore.tokenize("Invoice invoice NET-LIFY x _hidden a 2026-09")

		XCTAssertEqual(terms, ["invoice", "net-lify", "hidden", "2026-09"])
	}

	func testStoreWritesVerbatimRecordAndTermIndex() async throws {
		let storageURL = FileManager.default.temporaryDirectory
			.appendingPathComponent("CCTVTests-\(UUID().uuidString)", isDirectory: true)
		defer { try? FileManager.default.removeItem(at: storageURL) }

		let storageManager = StorageManager(baseURL: storageURL)
		let store = OCRStore(storageManager: storageManager)
		let date = ISO8601DateFormatter().date(from: "2026-01-04T15:31:00Z")!

		try await store.store(
			text: "Invoice NETLIFY invoice",
			displayIndex: 1,
			date: date
		)
		try await store.store(
			text: "Netlify dashboard",
			displayIndex: 0,
			date: date
		)

		let recordURL = storageManager
			.ocrVerbatimDirectory(for: date)
			.appendingPathComponent(
				storageManager.ocrVerbatimFilename(displayIndex: 1, date: date)
			)
		let record = try JSONDecoder().decode(
			VerbatimRecord.self,
			from: Data(contentsOf: recordURL)
		)
		XCTAssertEqual(record.timestamp, "2026-01-04T15:31:00Z")
		XCTAssertEqual(record.displayIndex, 1)
		XCTAssertEqual(record.text, "Invoice NETLIFY invoice")

		let indexURL = storageURL.appendingPathComponent("ocr/index.json")
		let index = try XCTUnwrap(
			JSONSerialization.jsonObject(with: Data(contentsOf: indexURL))
				as? [String: [String]]
		)
		XCTAssertEqual(index["invoice"], ["2026-01-04T15:31:00Z"])
		XCTAssertEqual(index["netlify"], ["2026-01-04T15:31:00Z"])
		XCTAssertEqual(index["dashboard"], ["2026-01-04T15:31:00Z"])
	}

	private struct VerbatimRecord: Decodable {
		let timestamp: String
		let displayIndex: Int
		let text: String
	}
}
