// swift-tools-version: 5.9

import PackageDescription

let package = Package(
	name: "swiftui-reluxrouter",
	platforms: [
		.iOS(.v16),
		.macOS(.v14),
		.watchOS(.v10),
		.tvOS(.v17),
		.macCatalyst(.v17)
	],
	products: [
		.library(
			name: "ReluxRouter",
			targets: ["ReluxRouter"]
		),
	],
	dependencies:      [
		.package(url: "https://github.com/ivalx1s/darwin-relux.git", from: "4.2.0"),
	],
	targets: [
		.target(
			name: "ReluxRouter",
			dependencies:  [
				.product(name: "Relux", package: "darwin-relux"),
			],
			path: "Sources"
		),
	]
)
