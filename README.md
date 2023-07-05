# FFmpeg-iOS

This swift package enables you to use FFmpeg libraries in your iOS, Mac Catalyst and tvOS apps.

## Installation

```
.package(url: "https://github.com/kewlbear/FFmpeg-iOS.git", from: "0.0.1")
```

## Usage

```
import avformat

var ifmt_ctx: UnsafeMutablePointer<AVFormatContext>?
var ret = avformat_open_input(&ifmt_ctx, filename, nil, nil)
```

See https://github.com/kewlbear/YoutubeDL-iOS.

## Building Libraries

```
$ swift run ffmpeg-ios
```

To build fat libraries:

```
$ swift run ffmpeg-ios --disable-xcframework 
```

## cf

### dav1d build

```
// av1 decoder dav1d source
https://github.com/validvoid/dav1d
https://code.videolan.org/videolan/dav1d

// cross compile 은 이거 살짝 수정
https://github.com/mesonbuild/meson/blob/master/cross/iphone.txt

// setup
meson .. --cross-file=../package/crossfiles/iphone.txt --debug --buildtype release

// ninja
ninja

// ninja install
sudo ninja install

// install시 설치되는 header, library를 이용하여,,
xcodebuild -create-xcframework -library ./libX11.6.dylib -headers ./include -output libX11.xcframework

// 생성된 xcframework를 프로젝트 내에서 사용
``` 
