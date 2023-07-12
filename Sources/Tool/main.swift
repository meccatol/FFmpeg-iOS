//
//  main.swift
//
//
//  Created by 안창범 on 2020/12/01.
//

import ArgumentParser
import Foundation

struct Tool: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "ffmpeg",
        abstract: "Build FFmpeg libraries for iOS & MacOS as xcframeworks",
        subcommands: [
            BuildCommand.self,
            RPathCommand.self,
            XCFrameworkCommand.self,
//            ModuleCommand.self,
//            FatCommand.self,
            DepCommand.self,
            SourceCommand.self,
//            ZipCommand.self,
//            Clean.self,
        ],
        defaultSubcommand: BuildCommand.self)
}

struct LibraryOptions: ParsableArguments {
}

struct SourceOptions: ParsableArguments {
    @Option(help: "Library source directory (default: ./<lib>)")
    var sourceDirectory: String?

    var sourceURL: URL { URL(fileURLWithPath: sourceDirectory ?? "./\(lib)") }

    var configureScriptExists: Bool {
        FileManager.default.fileExists(atPath: sourceURL.appendingPathComponent("configure").path)
    }

    @Argument(help: "ffmpeg, dav1d")
    var lib = "FFmpeg"
}

enum BuildTarget: String, ExpressibleByArgument, CaseIterable {
    case ios
    case macos
}

struct BuildOptions: ParsableArguments {
    
    @Option(help: "build target")
    var buildTarget: BuildTarget = .ios {
        didSet {
            switch buildTarget {
            case .ios:
                buildDirectory = "./build_ios"
                arch = ["arm64-iPhoneOS"]
            case .macos:
                buildDirectory = "./build_macos"
                arch = [
                    "arm64-MacOSX",
                    "x86_64-MacOSX"
                ]
            }
        }
    }
    
    @Option(help: "directory to contain build artifacts")
    var buildDirectory: String = ""
    
    @Option(help: "architectures to include")
    var arch: [String] = []
    
    var dav1d_install_prefix_path: String = "dav1d"
    
//    var arch = [
//        "arm64",
////        "arm64-iPhoneSimulator",
////        "x86_64",
////        "arm64-MacOSX",
////        "x86_64-MacOSX",
////        "arm64-AppleTVOS",
////        "arm64-AppleTVSimulator",
////        "x86_64-AppleTVSimulator",
//    ]
}

struct ConfigureOptions: ParsableArguments {
    @Option(help: "build target")
    var configurationTarget: BuildTarget = .ios {
        didSet {
            switch configurationTarget {
            case .ios:
                deploymentTarget = "14.0"
            case .macos:
                deploymentTarget = "11.0.0"
            }
        }
    }
    
    @Option
    var deploymentTarget: String = "14.0"

    @Option(help: "additional options for configure script")
    var extraOptions: [String] = []
}

struct FatLibraryOptions: ParsableArguments {
    @Option(help: "default: <lib>-fat")
    var output: String?
}

struct XCFrameworkOptions: ParsableArguments {
    @Option
    var frameworks = "./Frameworks"
}

struct DownloadOptions: ParsableArguments {
    @Option(help: "FFmpeg release")
    var release = "6.0"

    @Option(help: "dav1d version")
    var dav1d_version = "1.2.1"
    
    @Option
    var url: String?
}

extension Tool {
    struct BuildCommand: ParsableCommand {
        static var configuration = CommandConfiguration(commandName: "build", abstract: "Build framework module")
        
        var isDynamic: Bool = true
        
        @Flag(help: "Create fat library instead of .xcframework")
        var disableXcframework = false
        
//        @Flag
        var disableZip = true
        
        @OptionGroup var sourceOptions: SourceOptions
        @OptionGroup var buildOptions: BuildOptions
        @OptionGroup var libraryOptions: LibraryOptions
        @OptionGroup var configureOptions: ConfigureOptions
        @OptionGroup var downloadOptions: DownloadOptions
        @OptionGroup var xcframeworkOptions: XCFrameworkOptions

        mutating func run() throws {
            try DepCommand().run()
            
//            for buildTarget in BuildTarget.allCases {
//
//                self.buildOptions.buildTarget = buildTarget
//                self.configureOptions.configurationTarget = buildTarget
//
//                print("building target = \(buildTarget)...")
//                // build FFmpeg
//                try build(lib: sourceOptions.lib, sourceDirectory: sourceOptions.sourceURL.path)
//
//                if isDynamic {
//                    var rPathCommand = RPathCommand()
//                    rPathCommand.buildOptions = buildOptions
//                    rPathCommand.libraryOptions = libraryOptions
//                    rPathCommand.sourceOptions = sourceOptions
//                    try rPathCommand.run()
//                }
//            }
            
            // ************************ ios build ************************
            // ios - arm64
//            print("building target = ios_arm64...")
//            self.buildOptions.buildTarget = .ios
//            self.configureOptions.configurationTarget = .ios
//
//            // build dav1d
////            try build(lib: "dav1d", sourceDirectory: "./dav1d")
//
//            // build FFmpeg
//            try build(lib: sourceOptions.lib, sourceDirectory: sourceOptions.sourceURL.path)
//
//            if isDynamic {
//                var rPathCommand = RPathCommand()
//                rPathCommand.buildOptions = buildOptions
//                rPathCommand.libraryOptions = libraryOptions
//                rPathCommand.sourceOptions = sourceOptions
//                try rPathCommand.run()
//            }
            // mac - arm64
            
            // ************************ mac build ************************
            
            print("building target = x86_64...")
            
            self.buildOptions.buildTarget = .macos
            self.buildOptions.arch = ["x86_64-MacOSX"]
            self.configureOptions.configurationTarget = .macos
            
            for archx in self.buildOptions.arch {
                // build dav1d
                let dav1dPackageConfigPath = try buildDav1dAndGetPackageConfigPath(sourceDirectory: "./dav1d", archx: archx)
                
                // build FFmpeg
//                try buildFFmpeg(sourceDirectory: sourceOptions.sourceURL.path, additionalEnvironment: ["PKG_CONFIG_PATH": "\(URL(fileURLWithPath: ".").path)/dav1d/build_mac_x86/ff_build:$PKG_CONFIG_PATH"])
                
//                if isDynamic {
//                    var rPathCommand = RPathCommand()
//                    rPathCommand.buildOptions = buildOptions
//                    rPathCommand.libraryOptions = libraryOptions
//                    rPathCommand.sourceOptions = sourceOptions
//                    try rPathCommand.run()
//                }
            }
            
//            print("building xcframeworks...")
//            var createXcframeworks = XCFrameworkCommand()
//            createXcframeworks.buildOptions = buildOptions
//            createXcframeworks.libraryOptions = libraryOptions
//            createXcframeworks.xcframeworkOptions = xcframeworkOptions
//            createXcframeworks.sourceOptions = sourceOptions
//            try createXcframeworks.run()
            
            print("Done")
        }
        
        mutating func checkSource(lib: String, sourceDirectory: String) throws {
            sourceOptions.lib = lib
            
            if !FileManager.default.fileExists(atPath: sourceDirectory) {
                print("\(lib) source not found. Trying to download...")
                var downloadSource = SourceCommand()
                downloadSource.sourceOptions = sourceOptions
                downloadSource.sourceOptions.sourceDirectory = sourceDirectory
                downloadSource.downloadOptions = downloadOptions
                try downloadSource.run()
            }
        }
        
        mutating func buildDav1dAndGetPackageConfigPath(sourceDirectory: String, archx: String) throws -> String {
            let libName = "dav1d"
            try checkSource(lib: libName, sourceDirectory: sourceDirectory)
            
            print("buildDav1d")
            
            let crossCompileDir = URL(fileURLWithPath: ".")
                .appendingPathComponent("DependencyLibrary")
                .appendingPathComponent("dav1d_crossfiles")
            let dav1dBuildDir = URL(fileURLWithPath: ".").appendingPathComponent(libName)

            print("building \(archx)...")
            let array = archx.split(separator: "-")
            
            // ex) x86_64-MacOSX
            guard array.count == 2 else {
                throw ExitCode.failure
            }
            let _arch = String(array[0])
            let _platform = String(array[1]).lowercased()
            
            let sdkArchName = "\(_platform)_\(_arch)"
            let sdkArchBuildDir = dav1dBuildDir.appendingPathComponent("build_\(sdkArchName)")
            
            try removeItem(at: sdkArchBuildDir.path)
            try createDirectory(at: sdkArchBuildDir.path)
            
            let crossCompileOptionPath = crossCompileDir.appendingPathComponent("\(sdkArchName).txt").path
            
            try launch(launchPath: try whichPath("meson"),
                       arguments: ["setup", "--cross-file=\(escapeShellArgument(crossCompileOptionPath))", "--debug", "--buildtype release"],
                       currentDirectoryPath: sdkArchBuildDir.path,
                       environment: nil)
            
            try launch(launchPath: try whichPath("ninja"),
                       arguments: [],
                       currentDirectoryPath: sdkArchBuildDir.path,
                       environment: nil)
            
            let versionPattern = #"version:\s*'([\d.]+)'"#
            let regex = try NSRegularExpression(pattern: versionPattern)
            
            
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
                
            if let match = regex.firstMatch(in: text, options: [], range: range),
               let versionRange = Range(match.range(at: 1), in: text) {
                let versionString = String(text[versionRange])
                return versionString
            }
            
            return nil
            
            let install_for_ffmpeg = dav1dBuildDir.appendingPathComponent("install_for_ffmpeg")
            try removeItem(at: install_for_ffmpeg.path)
            try createDirectory(at: install_for_ffmpeg.path)
            
            let include = install_for_ffmpeg.appendingPathComponent("include").path
            let lib = install_for_ffmpeg.appendingPathComponent("lib").path
            try createDirectory(at: include)
            try createDirectory(at: lib)
            
            
            let pcFile = """
            prefix=\(install_for_ffmpeg.path)
            includedir=${prefix}/include
            libdir=${prefix}/lib

            Name: libdav1d
            Description: AV1 decoding library
            Version: 1.2.1
            Libs: -L${libdir} -ldav1d
            Cflags: -I${includedir}
            """
            try system("""
                    ln -sf \(prefix.path)/include/* \(include)
                    ln -sf \(prefix.path)/lib/* \(lib)
                    """)
        }
        
        mutating func buildFFmpeg(sourceDirectory: String, archx: String, additionalEnvironment: [String : String]? = nil) throws {
            print("buildFFmpeg")
            
            try checkSource(lib: "FFmpeg", sourceDirectory: sourceDirectory)
            
            class FFmpegConfiguration: ConfigurationHelper, Configuration {
                override var `as`: String { "gas-preprocessor.pl \(host) -- \(cc)" }
                
                var options: [String] {
                    [
                        "--prefix=\(installPrefix)",
                        
                        "--disable-doc",
                        // to generate dSYM files
                        "--enable-debug",
                        "--disable-programs",
                        "--disable-audiotoolbox",
                        
                        // AOS와 통일
                        "--disable-static",
                        "--disable-ffprobe",
                        "--disable-ffplay",
                        "--disable-ffmpeg",
                        "--disable-symver",
                        "--disable-stripping",
                        "--disable-vulkan",
                        "--disable-muxers",
                        "--disable-encoders",
                        "--disable-avdevice",
                        "--disable-filters",
                        "--disable-xlib",
                        
                        "--enable-filter=atempo,aresample",
                        "--enable-cross-compile",
                        "--enable-libdav1d",
                        
                        "--target-os=darwin",
                        "--arch=\(arch)",
                        "--cc=\(cc)",
                        "--as=\(`as`)",
                        "--extra-cflags=\(cFlags) -I\(installPrefix)/include",
                        "--extra-ldflags=\(ldFlags) -L\(installPrefix)/lib",
                    ]
                }
                
//                override var environment: [String : String]? {
//                    additionalEnvironment
//                    ["PKG_CONFIG_PATH": "\(URL(fileURLWithPath: ".").path)/dav1d/build_mac_x86/ff_build:$PKG_CONFIG_PATH"]
//                }
            }
            
            try buildLibrary(name: "FFmpeg", sourceDirectory: sourceDirectory, archx: archx, deploymentTarget: configureOptions.deploymentTarget, buildDirectory: buildOptions.buildDirectory, configuration: FFmpegConfiguration.self) {
                $0.environment = ($0.environment ?? [:]).merging(additionalEnvironment ?? [:]) { (_, new) in new }
                
                let platformOptions: [String]
                switch $0.platform {
                case "MacOSX":
                    platformOptions = [
                        "--disable-coreimage",
                        "--disable-securetransport",
                        "--disable-videotoolbox",
                    ]
                case "AppleTVOS", "AppleTVSimulator":
                    platformOptions = [
                        "--disable-avfoundation",
                    ]
                default:
                    platformOptions = []
                }
                if isDynamic {
                    configureOptions.extraOptions = configureOptions.extraOptions + (isDynamic ? ["--disable-static", "--enable-shared"] : [])
                }
                return $0.options
                    + configureOptions.extraOptions
                    + platformOptions
            }
        }
        
        func buildLibrary<T>(name: String, sourceDirectory: String, archx: String, deploymentTarget: String, buildDirectory: String, configuration: T.Type, customize: (T) -> [String] = { $0.options }) throws where T: Configuration {
            let buildDir = URL(fileURLWithPath: buildDirectory)
                .appendingPathComponent(name)
            
            print("building \(archx)...")
            let archDir = buildDir.appendingPathComponent(archx)
            try createDirectory(at: archDir.path)
            
            let prefix = buildDir
                .deletingLastPathComponent()
                .appendingPathComponent("install")
                .appendingPathComponent(name)
                .appendingPathComponent(archx)
            
            let array = archx.split(separator: "-")
            let platform: String?
            if array.count > 1 {
                platform = String(array[1])
            } else {
                platform = nil
            }
            
            let conf = T(sourceDirectory: sourceDirectory, arch: String(array[0]), platform: platform, deploymentTarget: deploymentTarget, installPrefix: prefix.path)
            
            let options = customize(conf)
            try launch(launchPath: "\(sourceDirectory)/configure",
                       arguments: options,
                       currentDirectoryPath: archDir.path,
                       environment: conf.environment)
            
            try launch(launchPath: "/usr/bin/make",
                       arguments: [
                        "-j3",
                        "install",
                       ], // FIXME: GASPP_FIX_XCODE5=1 ?
                       currentDirectoryPath: archDir.path)
            
            let all = buildDir
                .deletingLastPathComponent()
                .appendingPathComponent("install")
                .appendingPathComponent(archx)
            let include = all.appendingPathComponent("include").path
            let lib = all.appendingPathComponent("lib").path
            try createDirectory(at: include)
            try createDirectory(at: lib)
            try system("""
                    ln -sf \(prefix.path)/include/* \(include)
                    ln -sf \(prefix.path)/lib/* \(lib)
                    """)
        }
    }

    struct DepCommand: ParsableCommand {
        static var configuration = CommandConfiguration(commandName: "dep", abstract: "Install build dependency")

        func run() throws {
            func installHomebrewIfNeeded() throws {
                if !which("brew") {
                    print("'brew' not found. Trying to install...")
                    try system(#"/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)""#)
                }
            }

            func installWithHomebrew(_ command: String) throws {
                if !which(command) {
                    print("'\(command)' not found")

                    try installHomebrewIfNeeded()

                    print("Trying to install '\(command)'...")
//                    try system("arch -x86_64 brew install \(command)")
                    try system("brew install \(command)")
                }
            }

            try installWithHomebrew("yasm")
            try installWithHomebrew("nasm")

            if !which("gas-preprocessor.pl") {
                print("'gas-preprocessor.pl' not found. Trying to install...")
                try system("""
                    curl -L https://github.com/libav/gas-preprocessor/raw/master/gas-preprocessor.pl \
                    -o /usr/local/bin/gas-preprocessor.pl \
                    && chmod +x /usr/local/bin/gas-preprocessor.pl
                    """)
            }
        }
    }

    struct SourceCommand: ParsableCommand {
        static var configuration = CommandConfiguration(commandName: "source", abstract: "Download library source code")

        @OptionGroup var downloadOptions: DownloadOptions

        @OptionGroup var sourceOptions: SourceOptions

        var defaultURL: String {
            switch sourceOptions.lib {
            case "FFmpeg":
                return "http://www.ffmpeg.org/releases/ffmpeg-\(downloadOptions.release).tar.bz2"
            case "dav1d":
                return "https://github.com/videolan/dav1d/archive/refs/tags/\(downloadOptions.dav1d_version).tar.gz"
            case "fdk-aac":
                return "https://sourceforge.net/projects/opencore-amr/files/latest/download"
            case "lame":
                return "https://sourceforge.net/projects/lame/files/latest/download"
            case "x264":
                return "https://code.videolan.org/videolan/x264/-/archive/master/x264-master.tar.bz2"
            default:
                fatalError("unknown library: \(sourceOptions.lib)")
            }
        }
        
        func run() throws {
            let url = downloadOptions.url ?? defaultURL
            let t = "/tmp/\(sourceOptions.lib)"
            // FIXME: J for .xz
            try system("""
                mkdir \(t)
                curl -L \(url) | tar xjC \(t)
                mv \(t)/* \(sourceOptions.sourceURL.path)
                rmdir \(t)
                """)
        }
    }

    struct RPathCommand: ParsableCommand {
        static var configuration = CommandConfiguration(commandName: "rpath", abstract: "rename rpath")

        @OptionGroup var libraryOptions: LibraryOptions

        @OptionGroup var buildOptions: BuildOptions

        @OptionGroup var sourceOptions: SourceOptions

        mutating func run() throws {
            let lib = URL(fileURLWithPath: buildOptions.buildDirectory).appendingPathComponent("install").appendingPathComponent(sourceOptions.lib)

            for arch in buildOptions.arch {
                let libContentPath = lib.appendingPathComponent(arch).appendingPathComponent("lib").absoluteString.replacingOccurrences(of: "file://", with: "")
                print("libContentPath = \(libContentPath)")

                // replacement DYLIB to @rpath
                try system("""
                        DYLIBS=$(find \(libContentPath) -name "*.dylib")

                        for dylib in $DYLIBS; do
                          if [ -L $dylib ]; then
                            continue
                          fi

                          dylibName=$(basename $dylib | cut -f 1 -d '.')
                          echo "target dylibName = $dylibName"

                          install_name_tool -id "@rpath/$dylibName.dylib" "$(otool -D $dylib | awk 'NR>1 {print $1}')"

                          DEPENDENCIES=$(otool -L $dylib | awk 'NR>1 {print $1}' | grep -v "^@")

                          for dep in $DEPENDENCIES; do
                            if echo "$dep" | grep -q \(libContentPath); then
                                DEP_NAME=$(basename $dep | cut -f 1 -d '.')

                                NEW_PATH="@rpath/$DEP_NAME.dylib"
                                install_name_tool -change $dep $NEW_PATH $dylib
                                echo "Changed $dep to $NEW_PATH in $dylib"
                            else
                                echo "It's not ffmpeg dependency, $(basename $dep)"
                            fi
                          done
                        done
                        """)

                // flatting, rm symlink and removing version string from lib name
                try system("""
                DYLIBS=$(find \(libContentPath) -name "*.dylib")

                for dylib in $DYLIBS; do
                  if [ -L $dylib ]; then
                    rm $dylib
                    echo "Removed symlink: $dylib"
                  else
                    LIBRARY_NAME=$(echo $(basename $dylib) | sed -E 's/\\.[0-9]+\\.[0-9]+\\.[0-9]+\\.dylib/.dylib/')
                    mv $dylib ${dylib%/*}/$LIBRARY_NAME
                    echo "Renamed $dylib to $LIBRARY_NAME"
                  fi
                done
                """)
            }
        }
    }

    struct XCFrameworkCommand: ParsableCommand {
        static var configuration = CommandConfiguration(commandName: "framework", abstract: "Create .xcframework")
        
        var isDynamic: Bool = false
        
        @OptionGroup var libraryOptions: LibraryOptions
        
        @OptionGroup var buildOptions: BuildOptions
        
        @OptionGroup var xcframeworkOptions: XCFrameworkOptions
        
        @OptionGroup var sourceOptions: SourceOptions
        
        func run() throws {
            let lib = URL(fileURLWithPath: buildOptions.buildDirectory).appendingPathComponent("install").appendingPathComponent(sourceOptions.lib)
            let contents = try FileManager.default.contentsOfDirectory(at: lib.appendingPathComponent(buildOptions.arch[0]).appendingPathComponent("lib"), includingPropertiesForKeys: nil, options: [])
            //            print("contents = \(contents)")
            
            var contentsStringSet = Set<String>()
            contents
                .filter { $0.pathExtension == "dylib" }
                .map { $0.resolvingSymlinksInPath() }
                .map { $0.deletingPathExtension().lastPathComponent.replacingOccurrences(of: "lib", with: "") }
                .forEach { contentsStringSet.insert($0) }
            
            let modules: [String] = Array<String>(contentsStringSet)
            
            //            print("contentsStringSet = \(contentsStringSet)")
            //            print("nameResult = \(contentsStringSet.compactMap { $0.components(separatedBy: ".").first })")
            
            //            let predefinedModule = ["avcodec", "avdevice", "avfilter", "avformat", "avutil", "swresample", "swscale"]
            //            for pm in predefinedModule {
            //                if contentsStringSet.contains(pm) {
            //                    modules.append(pm)
            //                    continue
            //                }
            //            }
            
            print("modules = \(modules)")
            
            for library in modules {
                func convert(_ arch: String) -> String {
                    let array = arch.split(separator: "-")
                    if array.count > 1 {
                        return array[1].lowercased()
                    }
                    
                    switch arch {
                    case "arm64", "armv7":
                        return "iphoneos"
                    case "x86_64":
                        return "macos"
                    default:
                        fatalError()
                    }
                }
                
                var dict: [String: Set<String>] = [:]
                
                for arch in buildOptions.arch {
                    let sdk = convert(arch)
                    var set = dict[sdk] ?? []
                    set.insert(arch)
                    dict[sdk] = set
                }
                
                var args: [String] = []
                
                let libraryNameWithoutVersion = library.components(separatedBy: ".").first!
                
                for (sdk, set) in dict {
                    guard let arch = set.first else {
                        fatalError()
                    }
                    let dir = "\(lib.path)/\(arch)"
                    
                    let xcf = "\(buildOptions.buildDirectory)/xcf/\(sdk)"
                    try createDirectory(at: xcf)
                    
                    let fat = "\(xcf)/lib\(libraryNameWithoutVersion).dylib"
                    
                    try launch(launchPath: "/usr/bin/lipo",
                               arguments:
                                set.map { arch in "\(lib.path)/\(arch)/lib/lib\(library).dylib" }
                               + [
                                "-create",
                                "-output",
                                fat,
                               ])
                    
                    let include: String
                    if modules.count > 1 {
                        include = "\(xcf)/\(libraryNameWithoutVersion)/include"
                        try removeItem(at: include)
                        try createDirectory(at: include)
                        
                        let copy = "\(include)/lib\(libraryNameWithoutVersion)"
                        try removeItem(at: copy)
                        try copyItem(at: "\(dir)/include/lib\(libraryNameWithoutVersion)", to: copy)
                    } else {
                        include = "\(dir)/include"
                    }
                    
                    args += [
                        "-library", fat,
                        "-headers", include,
                    ]
                }
                
                let output = "\(xcframeworkOptions.frameworks)/\(libraryNameWithoutVersion).xcframework"
                
                try removeItem(at: output)
                
                try launch(launchPath: "/usr/bin/xcodebuild",
                           arguments:
                            ["-create-xcframework"]
                           + args
                           + [
                            "-output", output,
                           ])
                
                // Create dSYM files
                let fileManager = FileManager.default
                do {
                    let items = try fileManager.contentsOfDirectory(atPath: output)
                    
                    for item in items {
                        var isDirectory: ObjCBool = false
                        let itemPath = "\(output)/\(item)"
                        if fileManager.fileExists(atPath: itemPath, isDirectory: &isDirectory) {
                            if isDirectory.boolValue {
                                let source = "\(output)/\(item)/lib\(libraryNameWithoutVersion).dylib"
                                try launch(launchPath: "/usr/bin/xcrun",
                                           arguments: ["dsymutil"]
                                           + ["\(source)"]
                                           + ["-o", "\(output)/\(item)/dSYMs/lib\(libraryNameWithoutVersion).dylib.dSYM"])
                                try launch(launchPath: "/usr/bin/xcrun",
                                           arguments: ["strip"]
                                           + ["-S", "\(source)"])
                            }
                        }
                    }
                }
                catch {
                    print("failed to create dSYMs")
                }
            }
        }
    }
    
    struct Lipo: ParsableCommand {
        @Argument
        var input: String

        @Option
        var arch: String

        @Option
        var output: String

        func run() throws {
            try launch(launchPath: "/usr/bin/lipo",
                       arguments: [
                        input,
                        "-thin",
                        arch,
                        "-output",
                        output,
                       ])
        }
    }
}

func launch(launchPath: String, arguments: [String], currentDirectoryPath: String? = nil, environment: [String: String]? = nil) throws {
    let process = Process()

    if #available(OSX 10.13, *) {
        process.executableURL = URL(fileURLWithPath: launchPath)
    } else {
        process.launchPath = launchPath
    }

    process.arguments = arguments

    currentDirectoryPath.map { path in
        if #available(OSX 10.13, *) {
            process.currentDirectoryURL = URL(fileURLWithPath: path)
        } else {
            process.currentDirectoryPath = path
        }
        print("current directory:", path)
    }
    
    var currentEnv = ProcessInfo.processInfo.environment
//    print("current environment:", currentEnv)
    environment.map { environment in
        currentEnv.merge(environment) { (_, new) in new }
        process.environment = currentEnv
//        print("environment:", currentEnv)
    }

    print(launchPath, arguments)
    process.launch()

    process.waitUntilExit()
    if process.terminationStatus != 0 {
        print("'\(launchPath)' exit code: \(process.terminationStatus)")
        throw ExitCode(process.terminationStatus)
    }
}

func createDirectory(at path: String, withIntermediateDirectories: Bool = true, attributes: [FileAttributeKey: Any]? = nil) throws {
    try FileManager.default.createDirectory(at: URL(fileURLWithPath: path), withIntermediateDirectories: withIntermediateDirectories, attributes: attributes)
    print("created directory:", path)
}

func copyItem(at src: String, to dst: String) throws {
    try FileManager.default.copyItem(at: URL(fileURLWithPath: src),
                                     to: URL(fileURLWithPath: dst))
    print("copied:", src, "to", dst)
}

func removeItem(at path: String) throws {
    do {
        try FileManager.default.removeItem(at: URL(fileURLWithPath: path))
        print("removed:", path)
    }
    catch {
        let nserror = error as NSError
        guard let posixError = nserror.userInfo[NSUnderlyingErrorKey] as? POSIXError,
              posixError.code == .ENOENT
        else {
            print(#line, error)
            throw error
        }
    }
}

func escapeShellArgument(_ argument: String) -> String {
    var escapedArgument = ""
    let charactersToEscape: Set<Character> = [" ", "\t", "\n", "\"", "'", "$", "&", "`", "(", ")", "<", ">", "|", ";", "*", "?", "{", "}", "[", "]", "\\", "~", "#", "=", "%"]

    for char in argument {
        if charactersToEscape.contains(char) {
            escapedArgument.append("\\")
        }
        escapedArgument.append(char)
    }

    return escapedArgument
}

func whichPath(_ command: String) throws -> String {
    let task = Process()
    task.launchPath = "/bin/zsh"
    task.arguments = ["-c", "which \(command)"]

    let pipe = Pipe()
    task.standardOutput = pipe

    task.launch()
    task.waitUntilExit()

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    guard let launchPath = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .newlines) else {
        throw ExitCode.failure
    }
    return launchPath
}

func which(_ command: String) -> Bool {
    do {
        try system("which \(command)")
        return true
    }
    catch {
        return false
    }
}

func system(_ command: String) throws {
    try spawn(["sh", "-c", command])
}

func spawn(_ args: [String]) throws {
    var pid: pid_t = -1
    var argv = args.map { strdup($0) }
    argv.append(nil)

    print(#function, args)
    let errno = posix_spawnp(&pid, args.first, nil, nil, argv, environ)
    print(#function, "posix_spawn()=\(errno) pid=\(pid)")

    argv.dropLast().forEach { free($0) }

    guard errno == 0 else {
        throw ExitCode.failure
    }

    var status: Int32 = 0
    let ret = waitpid(pid, &status, 0)
    print(#function, "waitpid()=\(ret) status=\(status)")
    guard WIFEXITED(status) else {
        throw ExitCode.failure
    }
    status = WEXITSTATUS(status)
    if status != 0 {
        print(#function, "exit status:", status)
        throw ExitCode.failure
    }
}

func getHost(from arch: String) -> String {
    switch arch {
    case "armv7":
        return "arm"
    case "arm64":
        return "aarch64"
    default:
        return arch
    }
}

protocol Configuration {
    var options: [String] { get }

    var environment: [String: String]? { get set }

    init(sourceDirectory: String, arch: String, platform: String?, deploymentTarget: String, installPrefix: String)
}

class ConfigurationHelper {
    let sourceDirectory: String

    let arch: String

    let platform: String

    var sdk: String { platform.lowercased() }

    var cc: String { "xcrun -sdk \(sdk) clang -arch \(arch)" }

    var host: String { "-arch \(getHost(from: arch))" }

    var `as`: String { "\(sourceDirectory)/extras/gas-preprocessor.pl \(host) -- \(cc)" }

    var cFlags: String

    var ldFlags: String { cFlags }

    let installPrefix: String

    var environment: [String: String]?

    required init(sourceDirectory: String, arch: String, platform: String? = nil, deploymentTarget: String, installPrefix: String) {
        self.sourceDirectory = sourceDirectory
        self.arch = arch
        self.installPrefix = installPrefix

        cFlags = "-arch \(arch)"

        if let platform = platform {
            self.platform = platform
        } else {
            switch arch {
            case "x86_64", "i386":
                self.platform = "MacOS"
            default:
                self.platform = "iPhoneOS"
            }
        }

        switch self.platform {
        case "iPhoneSimulator":
            cFlags.append(" -mios-simulator-version-min=\(deploymentTarget)")
        case "iPhoneOS":
            cFlags.append(" -mios-version-min=\(deploymentTarget)")
        case "MacOSX":
            cFlags.append(" -mmacos-version-min=\(deploymentTarget)")
        case "AppleTVOS":
            cFlags.append(" -mtvos-version-min=\(deploymentTarget)")
        case "AppleTVSimulator":
            cFlags.append(" -mtvos-simulator-version-min=\(deploymentTarget)")
        default:
            fatalError("Unknown platform: \(self.platform)")
        }
    }
}

// https://github.com/aciidb0mb3r/Configuration/blob/master/Sources/POSIX/system.swift

private func _WSTATUS(_ status: CInt) -> CInt {
    return status & 0x7f
}

private func WIFEXITED(_ status: CInt) -> Bool {
    return _WSTATUS(status) == 0
}

private func WEXITSTATUS(_ status: CInt) -> CInt {
    return (status >> 8) & 0xff
}

Tool.main()
