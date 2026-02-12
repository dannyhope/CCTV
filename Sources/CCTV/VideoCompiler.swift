import AVFoundation
import AppKit
import CoreVideo

final class VideoCompiler {
	private let fps: Int32 = 30

	func compileToday() async throws -> URL {
		return try await compile(for: Date())
	}

	func compile(for date: Date) async throws -> URL {
		let displayIndices = StorageManager.shared.displayIndices(for: date)
		guard !displayIndices.isEmpty else {
			throw CompileError.noScreenshots
		}

		let videosDir = StorageManager.shared.baseURL.appendingPathComponent("videos", isDirectory: true)
		try StorageManager.shared.ensureDirectory(videosDir)

		var outputURL: URL?

		for displayIndex in displayIndices {
			let screenshots = StorageManager.shared.sortedScreenshots(
				for: date,
				displayIndex: displayIndex
			)
			guard !screenshots.isEmpty else { continue }

			let url: URL
			if displayIndices.count == 1 {
				url = StorageManager.shared.videoURL(for: date)
			} else {
				let dateString = StorageManager.shared.videoURL(for: date)
					.deletingPathExtension().lastPathComponent
				url = videosDir.appendingPathComponent("\(dateString)-display-\(displayIndex).mp4")
			}

			if FileManager.default.fileExists(atPath: url.path) {
				try FileManager.default.removeItem(at: url)
			}

			try await writeVideo(from: screenshots, to: url)
			outputURL = url
		}

		guard let result = outputURL else {
			throw CompileError.noScreenshots
		}

		return result
	}

	private func writeVideo(from imagePaths: [URL], to outputURL: URL) async throws {
		guard let firstImage = NSImage(contentsOf: imagePaths[0]),
			  let firstCGImage = firstImage.cgImage(
				forProposedRect: nil,
				context: nil,
				hints: nil
			  ) else {
			throw CompileError.invalidImage
		}

		let width = firstCGImage.width
		let height = firstCGImage.height

		let writer = try AVAssetWriter(url: outputURL, fileType: .mp4)

		let settings: [String: Any] = [
			AVVideoCodecKey: AVVideoCodecType.h264,
			AVVideoWidthKey: width,
			AVVideoHeightKey: height,
		]

		let writerInput = AVAssetWriterInput(
			mediaType: .video,
			outputSettings: settings
		)
		writerInput.expectsMediaDataInRealTime = false

		let adaptorAttributes: [String: Any] = [
			kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
			kCVPixelBufferWidthKey as String: width,
			kCVPixelBufferHeightKey as String: height,
		]

		let adaptor = AVAssetWriterInputPixelBufferAdaptor(
			assetWriterInput: writerInput,
			sourcePixelBufferAttributes: adaptorAttributes
		)

		writer.add(writerInput)
		guard writer.startWriting() else {
			throw CompileError.writerFailed(writer.error?.localizedDescription ?? "Unknown error")
		}
		writer.startSession(atSourceTime: .zero)

		for (frameIndex, imagePath) in imagePaths.enumerated() {
			try autoreleasepool {
				guard let image = NSImage(contentsOf: imagePath),
					  let cgImage = image.cgImage(
						forProposedRect: nil,
						context: nil,
						hints: nil
					  ) else {
					throw CompileError.invalidImage
				}

				let presentationTime = CMTime(
					value: CMTimeValue(frameIndex),
					timescale: fps
				)

				while !writerInput.isReadyForMoreMediaData {
					Thread.sleep(forTimeInterval: 0.01)
				}

				guard let pixelBufferPool = adaptor.pixelBufferPool else {
					throw CompileError.noPixelBufferPool
				}

				var pixelBuffer: CVPixelBuffer?
				let status = CVPixelBufferPoolCreatePixelBuffer(
					nil,
					pixelBufferPool,
					&pixelBuffer
				)
				guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
					throw CompileError.pixelBufferFailed
				}

				CVPixelBufferLockBaseAddress(buffer, [])
				let context = CGContext(
					data: CVPixelBufferGetBaseAddress(buffer),
					width: width,
					height: height,
					bitsPerComponent: 8,
					bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
					space: CGColorSpaceCreateDeviceRGB(),
					bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
				)
				context?.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
				CVPixelBufferUnlockBaseAddress(buffer, [])

				adaptor.append(buffer, withPresentationTime: presentationTime)
			}
		}

		writerInput.markAsFinished()
		await writer.finishWriting()

		if writer.status == .failed {
			throw CompileError.writerFailed(writer.error?.localizedDescription ?? "Unknown error")
		}
	}
}

enum CompileError: LocalizedError {
	case noScreenshots
	case invalidImage
	case writerFailed(String)
	case noPixelBufferPool
	case pixelBufferFailed

	var errorDescription: String? {
		switch self {
		case .noScreenshots:
			return "No screenshots found to compile"
		case .invalidImage:
			return "Could not load screenshot image"
		case .writerFailed(let reason):
			return "Video writer failed: \(reason)"
		case .noPixelBufferPool:
			return "Could not create pixel buffer pool"
		case .pixelBufferFailed:
			return "Could not create pixel buffer"
		}
	}
}
