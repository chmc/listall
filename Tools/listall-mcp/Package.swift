// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "listall-mcp",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "listall-mcp", targets: ["listall-mcp"]),
    ],
    dependencies: [
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk", from: "0.10.2"),
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
                .unsafeFlags([
                    "-L", "/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib",
                    "-Xlinker", "-rpath",
                    "-Xlinker", "/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib",
                ])
            ]
        ),
        .testTarget(
            name: "MCPHelpersTests",
            dependencies: ["MCPHelpers"],
            path: "Tests/MCPHelpersTests"
        ),
    ]
)
