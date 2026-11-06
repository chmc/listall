// swift-tools-version:6.0
import PackageDescription
import Foundation

// Keep the libIndexStore lookup below in sync with Tools/swift-call-graph/Package.swift (manifests cannot share code)
let fallbackToolchainLib = "/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib"

/// Toolchain lib directory that holds libIndexStore.dylib.
/// Prefers the selected Xcode (DEVELOPER_DIR, then xcode-select) and falls back to
/// /Applications/Xcode.app when the selection has no Xcode toolchain (e.g. Command Line Tools).
func selectedToolchainLib() -> String {
    var developerDir = Context.environment["DEVELOPER_DIR"]
    if developerDir?.isEmpty ?? true {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcode-select")
        process.arguments = ["-p"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        if (try? process.run()) != nil {
            process.waitUntilExit()
            developerDir = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
    guard let developerDir, !developerDir.isEmpty else { return fallbackToolchainLib }
    let lib = developerDir + "/Toolchains/XcodeDefault.xctoolchain/usr/lib"
    return FileManager.default.fileExists(atPath: lib + "/libIndexStore.dylib") ? lib : fallbackToolchainLib
}

let toolchainLib = selectedToolchainLib()

/// Link against the selected toolchain; keep /Applications/Xcode.app as a second rpath
/// so the binary still loads libIndexStore after the selected Xcode is removed.
let indexStoreRpaths = toolchainLib == fallbackToolchainLib ? [toolchainLib] : [toolchainLib, fallbackToolchainLib]
let indexStoreLinkerFlags = ["-L", toolchainLib] + indexStoreRpaths.flatMap { ["-Xlinker", "-rpath", "-Xlinker", $0] }

let package = Package(
    name: "listall-mcp",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "listall-mcp", targets: ["listall-mcp"]),
    ],
    dependencies: [
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk", .upToNextMinor(from: "0.12.1")),
    ],
    targets: [
        .systemLibrary(
            name: "CIndexStore",
            pkgConfig: nil
        ),
        .target(
            name: "IndexStoreWrapper",
            dependencies: ["CIndexStore"],
            path: "Sources/IndexStoreWrapper"
        ),
        .target(
            name: "MCPHelpers",
            dependencies: [
                .product(name: "MCP", package: "swift-sdk"),
            ],
            path: "Sources/MCPHelpers"
        ),
        .executableTarget(
            name: "listall-mcp",
            dependencies: [
                .product(name: "MCP", package: "swift-sdk"),
                "IndexStoreWrapper",
                "MCPHelpers",
            ],
            swiftSettings: [
                .unsafeFlags(["-parse-as-library"])
            ],
            linkerSettings: [
                .unsafeFlags(indexStoreLinkerFlags)
            ]
        ),
        .testTarget(
            name: "MCPHelpersTests",
            dependencies: [
                "MCPHelpers",
                .product(name: "MCP", package: "swift-sdk"),
            ],
            path: "Tests/MCPHelpersTests"
        ),
    ]
)
