// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "FFmpeg-iOS",
    platforms: [.iOS(.v14)],
    products: [
        .library(
            name: "FFmpeg-iOS",
            targets: [
                "avcodec", "avutil", "avformat", "avfilter", "avdevice", "swscale", "swresample", "Depend"]),
        .executable(name: "ffmpeg-ios", targets: ["Tool"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "0.3.0"),
    ],
    targets: [
        .binaryTarget(name: "avcodec", url: "https://github.daumkakao.com/baker-kim/FFmpeg-iOS/releases/download/5.1.2/avcodec.zip", checksum: "75b734831414a0ee83b54f6e9848938f145469b2acbd93ac79be56e5427c6d74"),
        .binaryTarget(name: "avutil", url: "https://github.daumkakao.com/baker-kim/FFmpeg-iOS/releases/download/5.1.2/avutil.zip", checksum: "df04279753a9f6906be0c8d08ec296fc7cd975404d2727396996cba227b0d96b"),
        .binaryTarget(name: "avformat", url: "https://github.daumkakao.com/baker-kim/FFmpeg-iOS/releases/download/5.1.2/avformat.zip", checksum: "815f0ff5cfffce31aa32959b7767788a1414567cf1243a1d83605cf010107508"),
        .binaryTarget(name: "avfilter", url: "https://github.daumkakao.com/baker-kim/FFmpeg-iOS/releases/download/5.1.2/avfilter.zip", checksum: "f590c8aaa92a181d56f5b1025711de83ff7c3d586cf59d440dd73626b0ad8eae"),
        .binaryTarget(name: "avdevice", url: "https://github.daumkakao.com/baker-kim/FFmpeg-iOS/releases/download/5.1.2/avdevice.zip", checksum: "13959c10e19d820dba4bdd0a474ac82ff4bf382f969875fba51ecac596a34d2f"),
        .binaryTarget(name: "swscale", url: "https://github.daumkakao.com/baker-kim/FFmpeg-iOS/releases/download/5.1.2/swscale.zip", checksum: "5bc6ada0ea5afdb741fc8886c65a4ec8964a3ed0b6cbe9b6dafb07dd33ffe49b"),
        .binaryTarget(name: "swresample", url: "https://github.daumkakao.com/baker-kim/FFmpeg-iOS/releases/download/5.1.2/swresample.zip", checksum: "2b070c69ed857fe203d5e086b82f593f0cac461787fa59d0cdc6125606487ada"),
        .target(name: "Tool", dependencies: [
            .product(name: "ArgumentParser", package: "swift-argument-parser"),
        ]),
        .target(name: "Depend",
                linkerSettings: [
                    .linkedLibrary("z"),
                    .linkedLibrary("bz2"),
                    .linkedLibrary("iconv"),
                ]
        ),
    ]
)
