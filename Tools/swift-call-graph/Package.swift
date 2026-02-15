// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "swift-call-graph",
    platforms: [.macOS(.v14)],
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
        .executableTarget(
            name: "swift-call-graph",
            dependencies: ["IndexStoreWrapper"],
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
    ]
)
