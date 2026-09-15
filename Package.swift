// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SystemDataCleaner",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "SystemDataCleaner",
            path: "SystemDataCleaner",
            exclude: [
                "Info.plist"
            ]
        )
    ]
)
