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
        .executableTarget(
            name: "listall-mcp",
            dependencies: [
                .product(name: "MCP", package: "swift-sdk"),
            ],
            swiftSettings: [
                .unsafeFlags(["-parse-as-library"])
            ]
        ),
    ]
)
