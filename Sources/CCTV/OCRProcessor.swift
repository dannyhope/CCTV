import CoreGraphics
import Vision

final class OCRProcessor {
	/// Extracts readable text from a screenshot using macOS Vision OCR.
	func recognizeText(in image: CGImage) async throws -> String {
		let request = VNRecognizeTextRequest()
		request.recognitionLevel = .accurate
		request.usesLanguageCorrection = true

		let handler = VNImageRequestHandler(cgImage: image, options: [:])
		try handler.perform([request])

		let observations = request.results ?? []
		let lines = observations.compactMap { observation in
			observation.topCandidates(1).first?.string
		}
		return lines.joined(separator: "\n")
	}
}
