// swift-tools-version: 6.0
import PackageDescription

let package = Package(
	name: "swiftui-reluxrouter",
	platforms: [
		.iOS(.v16),
		.macOS(.v13),
		.watchOS(.v9),
		.tvOS(.v16),
		.macCatalyst(.v16),
	],
	products: [
		.library(
			name: "ReluxRouter",
			targets: ["ReluxRouter"]
		),
	],
	dependencies: [
		.package(url: "https://github.com/relux-works/swift-relux.git", from: "8.4.0"),
	],
	targets: [
		.target(
			name: "ReluxRouter",
			dependencies:  [
				.product(name: "Relux", package: "swift-relux"),
			],
			path: "Sources"
		),
	]
)
