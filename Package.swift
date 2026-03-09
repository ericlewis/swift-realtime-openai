// swift-tools-version: 6.2

import PackageDescription

let package = Package(
	name: "RealtimeAPI",
	platforms: [
		.iOS(.v17),
		.tvOS(.v17),
		.macOS(.v14),
		.visionOS(.v1),
		.macCatalyst(.v17),
	],
	products: [
		.library(name: "RealtimeAPI", targets: ["RealtimeAPI"]),
	],
	dependencies: [
		.package(url: "https://github.com/livekit/webrtc-xcframework.git", branch: "main"),
		.package(url: "https://github.com/apple/swift-testing.git", from: "6.2.4"),
	],
	targets: [
		.target(name: "Core"),
		.target(name: "WebSocket", dependencies: ["Core"]),
		.target(name: "UI", dependencies: ["Core", "WebRTC"]),
		.target(name: "RealtimeAPI", dependencies: ["Core", "WebSocket", "WebRTC", "UI"]),
		.target(name: "WebRTC", dependencies: ["Core", .product(name: "LiveKitWebRTC", package: "webrtc-xcframework")]),
		.testTarget(
			name: "RealtimeAPITests",
			dependencies: [
				"Core",
				"UI",
				.product(name: "Testing", package: "swift-testing"),
			]
		),
	]
)
