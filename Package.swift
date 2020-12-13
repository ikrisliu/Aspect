// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Aspect",
    platforms: [.macOS(.v10_12), .iOS(.v10), .tvOS(.v10), .watchOS(.v3)],
    products: [
    	.library(name: "Aspect", targets: ["Aspect"]),
    ],
    targets: [
        .target(name: "Aspect", exclude: ["Aspect.swift", "Info.plist"], publicHeadersPath: "include"),
        .testTarget(name: "AspectTests", dependencies: ["Aspect"], exclude: ["Aspect.m", "Info.plist"]),
    ]
)
