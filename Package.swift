// swift-tools-version:5.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Aspect",
    products: [
        .library(
            name: "Aspect",
            targets: ["Aspect"])
    ],
    targets: [
        .target(
            name: "Aspect",
            path: "Aspect")
    ]
)
