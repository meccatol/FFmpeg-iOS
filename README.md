# FFmpeg for Apple Platform (iOS & MacOS)

This swift package enables you to use FFmpeg libraries in your iOS, Mac apps.

## Usage

```
import avformat

var ifmt_ctx: UnsafeMutablePointer<AVFormatContext>?
var ret = avformat_open_input(&ifmt_ctx, filename, nil, nil)
```

See https://github.com/kewlbear/YoutubeDL-iOS.

## Building Libraries(FFmpeg xcframeworks)

```
$ swift run ffmpeg
// this will be making ios & mac xcframework
// also dav1d is included
```
