// swift-tools-version:5.9
import PackageDescription
import Foundation

// GRDB 默认从 GitHub 拉取（from 6.29.3，与上游 macOS 版的 Package.resolved 一致）。
// 网络到不了 GitHub 时，可以先把 GRDB 克隆到同级目录：
//     git clone --depth 1 --branch v6.29.3 https://github.com/groue/GRDB.swift.git ../vendor/GRDB.swift
// 再带 BIANDAN_VENDOR_GRDB=1 构建；Tools 里的两个脚本会自动识别并设置这个变量。
let packageRoot = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let vendorPath = packageRoot.appendingPathComponent("../vendor/GRDB.swift").standardizedFileURL.path
let useVendoredGRDB = ProcessInfo.processInfo.environment["BIANDAN_VENDOR_GRDB"] == "1"
    && FileManager.default.fileExists(atPath: vendorPath)

let grdb: Package.Dependency = useVendoredGRDB
    ? .package(path: "../vendor/GRDB.swift")
    : .package(url: "https://github.com/groue/GRDB.swift.git", from: "6.29.3")

let package = Package(
    name: "BiandanPad",
    defaultLocalization: "zh-Hans",
    platforms: [.iOS(.v17)],
    products: [
        .executable(name: "BiandanPad", targets: ["BiandanPad"]),
    ],
    dependencies: [grdb],
    targets: [
        .executableTarget(
            name: "BiandanPad",
            dependencies: [.product(name: "GRDB", package: "GRDB.swift")],
            path: "Sources/BiandanPad"
        ),
    ]
)
