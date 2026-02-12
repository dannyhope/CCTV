// swift-tools-version: 5.10

import PackageDescription

let package = Package(
	name: "CCTV",
	platforms: [
		.macOS(.v14)
	],
	targets: [
		.executableTarget(
			name: "CCTV",
			path: "Sources/CCTV",
			swiftSettings: [
				.unsafeFlags(["-strict-concurrency=targeted"])
			]
		)
	]
)
