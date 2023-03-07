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
        .binaryTarget(name: "avcodec", url: "https://github.daumkakao.com/videotech/FFmpeg-iOS/releases/download/5.1.2/avcodec.zip", checksum: "40e84669e0cf655acc1b3090629238c25444b8e5134f102d278f379c01e22457"),
        .binaryTarget(name: "avutil", url: "https://github.daumkakao.com/videotech/FFmpeg-iOS/releases/download/5.1.2/avutil.zip", checksum: "3eee7fddee7272a028c1a1f8f9f895c3611866e295d7cea967a2fe1963da203b"),
        .binaryTarget(name: "avformat", url: "https://github.daumkakao.com/videotech/FFmpeg-iOS/releases/download/5.1.2/avformat.zip", checksum: "e4cc242f133340311cea986a76fb2203c4457a43b87122a27990e22abf4c02ae"),
        .binaryTarget(name: "avfilter", url: "https://github.daumkakao.com/videotech/FFmpeg-iOS/releases/download/5.1.2/avfilter.zip", checksum: "f8fe52f87ac9b18307dea0a02844ab96421b95b16d1b5bdcd71fdd84604d2671"),
        .binaryTarget(name: "avdevice", url: "https://github.daumkakao.com/videotech/FFmpeg-iOS/releases/download/5.1.2/avdevice.zip", checksum: "fd7b4a837714d5b0ca59cc1f6d47702872ff6b3a92cb643377e6df56c8bb38e6"),
        .binaryTarget(name: "swscale", url: "https://github.daumkakao.com/videotech/FFmpeg-iOS/releases/download/5.1.2/swscale.zip", checksum: "fbbc1dad73a006b9f6accd238c0d385d69316596feeb5b1dee62b77f04462843"),
        .binaryTarget(name: "swresample", url: "https://github.daumkakao.com/videotech/FFmpeg-iOS/releases/download/5.1.2/swresample.zip", checksum: "95c23cba79cbe6361e7f78d18e69e3a2d8ac08cb15e025ebe7054ae19aab072c"),
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
