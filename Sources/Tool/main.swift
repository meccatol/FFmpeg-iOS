//
//  main.swift
//
//
//  Created by 안창범 on 2020/12/01.
//

import ArgumentParser
import Foundation

/// for av1 decoder dav1d
var isDav1dBuildIncluded: Bool = true

/// dynamic library build
var isDynamic: Bool = true

struct Tool: ParsableCommand {
    
    static var configuration = CommandConfiguration(
        commandName: "ffmpeg",
        abstract: "Build FFmpeg libraries for iOS & MacOS as xcframeworks",
        subcommands: [
            DepCommand.self,
            BuildCommand.self,
            RPathCommand.self,
            XCFrameworkCommand.self,
            ModuleCommand.self,
            SourceCommand.self,
            TeslaPatchCommmand.self,
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

    @Argument(help: "FFmpeg, dav1d")
    var lib = "FFmpeg"
    
    var includePrefix: String {
        if lib == "FFmpeg" { return "lib" }
        else { return "" }
    }
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
    
    func installURL(with lib: String) -> URL {
        URL(fileURLWithPath: self.buildDirectory)
            .appendingPathComponent("install")
            .appendingPathComponent(lib)
    }
    
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
        
        @OptionGroup var sourceOptions: SourceOptions
        @OptionGroup var buildOptions: BuildOptions
        @OptionGroup var libraryOptions: LibraryOptions
        @OptionGroup var configureOptions: ConfigureOptions
        @OptionGroup var downloadOptions: DownloadOptions
        @OptionGroup var xcframeworkOptions: XCFrameworkOptions

        mutating func run() throws {
            try DepCommand().run()
            
            func _build() throws {
                for archx in self.buildOptions.arch {
                    
                    var additionalEnvironment: [String: String] = [:]
                    
                    if isDav1dBuildIncluded {
                        // build dav1d
                        let dav1dPackageConfigPath = try buildDav1dAndGetPackageConfigPath(archx: archx)
                        print("dav1dPackageConfigPath = \(dav1dPackageConfigPath)")
                        additionalEnvironment["PKG_CONFIG_PATH"] = "\(dav1dPackageConfigPath):$PKG_CONFIG_PATH"
                    }
                    
                    // build FFmpeg
                    try buildFFmpeg(archx: archx, additionalEnvironment: additionalEnvironment)
                    
                    if isDynamic {
                        var rPathCommand = RPathCommand()
                        rPathCommand.buildOptions = buildOptions
                        rPathCommand.libraryOptions = libraryOptions
                        rPathCommand.sourceOptions = sourceOptions
                        try rPathCommand.run(archx)
                    }
                }
            }
            // ************************ ios build ************************
            
            print("building target = ios...")
            self.buildOptions.buildTarget = .ios
            self.configureOptions.configurationTarget = .ios

            try _build()
            
            // ************************ mac build ************************
            
            print("building target = mac...")

            self.buildOptions.buildTarget = .macos
            self.configureOptions.configurationTarget = .macos

            try _build()
            
            print("make xcframeworks...")
            var createXcframeworks = XCFrameworkCommand()
            createXcframeworks.buildOptions = buildOptions
            createXcframeworks.sourceOptions = sourceOptions
            createXcframeworks.libraryOptions = libraryOptions
            createXcframeworks.xcframeworkOptions = xcframeworkOptions
            try createXcframeworks.run()
            
            print("modularizing...")
            var modularize = ModuleCommand()
            modularize.buildOptions = buildOptions
            modularize.libraryOptions = libraryOptions
            modularize.xcframeworkOptions = xcframeworkOptions
            modularize.sourceOptions = sourceOptions
            try modularize.run()
            
            print("Done! Bye!")
        }
        
        mutating func checkSource(lib: String) throws {
            sourceOptions.lib = lib
            let sourceDirectory = sourceOptions.sourceURL.path
            
            if !FileManager.default.fileExists(atPath: sourceDirectory) {
                print("\(lib) source not found. Trying to download...")
                var downloadSource = SourceCommand()
                downloadSource.sourceOptions = sourceOptions
                downloadSource.sourceOptions.sourceDirectory = sourceDirectory
                downloadSource.downloadOptions = downloadOptions
                try downloadSource.run()
            }
        }
        
        mutating func buildDav1dAndGetPackageConfigPath(archx: String) throws -> String {
            let libName = "dav1d"
            try checkSource(lib: libName)
            let sourceDirectory = sourceOptions.sourceURL.path
            
            print("buildDav1d")
            
            let dav1dBuildDir = URL(fileURLWithPath: sourceDirectory)
            print("dav1dBuildDir = \(dav1dBuildDir.path)")
            
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
            
            let crossCompileDir = URL(fileURLWithPath: ".")
                .appendingPathComponent("Resources")
                .appendingPathComponent("dav1d_crossfiles")
            let crossCompileOptionPath = crossCompileDir.appendingPathComponent("\(sdkArchName).txt").path
            
            try launch(launchPath: try executeCommand("which meson"),
                       arguments: ["setup", "--cross-file=\(crossCompileOptionPath)", "--debug", "--buildtype", "release"],
                       currentDirectoryPath: sdkArchBuildDir.path,
                       environment: nil)
            
            try launch(launchPath: try executeCommand("which ninja"),
                       arguments: [],
                       currentDirectoryPath: sdkArchBuildDir.path,
                       environment: nil)
            
            let versionPattern = #"version:\s*'([\d.]+)'"#
            let regex = try NSRegularExpression(pattern: versionPattern)
            let mesonBuildText = try readFile(dav1dBuildDir.appendingPathComponent("meson.build").path)
            
            let range = NSRange(mesonBuildText.startIndex..<mesonBuildText.endIndex, in: mesonBuildText)
            
            guard let match = regex.firstMatch(in: mesonBuildText, options: [], range: range),
                  let versionRange = Range(match.range(at: 1), in: mesonBuildText) else {
                throw ExitCode.failure
            }
            
            let dav1dVersionString = String(mesonBuildText[versionRange])
            
            let install_for_ffmpeg = buildOptions.installURL(with: sourceOptions.lib)
                .appendingPathComponent(archx)
            
            try removeItem(at: install_for_ffmpeg.path)
            try createDirectory(at: install_for_ffmpeg.path)
            
            let include = install_for_ffmpeg.appendingPathComponent("include").appendingPathComponent(libName)
            let lib = install_for_ffmpeg.appendingPathComponent("lib")
            try createDirectory(at: include.path)
            try createDirectory(at: lib.path)
            
            let pcFileString = """
            prefix=\(install_for_ffmpeg.path)
            includedir=${prefix}/include
            libdir=${prefix}/lib
            
            Name: libdav1d
            Description: AV1 decoding library
            Version: \(dav1dVersionString)
            Libs: -L${libdir} -ldav1d
            Cflags: -I${includedir}
            """
            let pcFileURL = install_for_ffmpeg.appendingPathComponent("dav1d.pc")
            try pcFileString.write(to: pcFileURL, atomically: true, encoding: .utf8)
            
            let src = sdkArchBuildDir.appendingPathComponent("src")
            let dylibName = try executeCommand("ls -lSr \(src.path) | tail -n 1 | awk '{print $NF}'")
            let dylibNameWithoutVersion = try executeCommand("echo \(dylibName) | sed 's/\\(.*\\)\\..*\\.dylib$/\\1.dylib/'")
            print("dylibName = \(dylibName)")
            print("dylibNameWithoutVersion = \(dylibNameWithoutVersion)")
            
            try system("""
                    cp \(dav1dBuildDir.appendingPathComponent("include").appendingPathComponent("dav1d").appendingPathComponent("common.h").path) \(include.appendingPathComponent("common.h").path)
                    cp \(dav1dBuildDir.appendingPathComponent("include").appendingPathComponent("dav1d").appendingPathComponent("data.h").path) \(include.appendingPathComponent("data.h").path)
                    cp \(dav1dBuildDir.appendingPathComponent("include").appendingPathComponent("dav1d").appendingPathComponent("dav1d.h").path) \(include.appendingPathComponent("dav1d.h").path)
                    cp \(dav1dBuildDir.appendingPathComponent("include").appendingPathComponent("dav1d").appendingPathComponent("headers.h").path) \(include.appendingPathComponent("headers.h").path)
                    cp \(dav1dBuildDir.appendingPathComponent("include").appendingPathComponent("dav1d").appendingPathComponent("picture.h").path) \(include.appendingPathComponent("picture.h").path)
                    cp \(sdkArchBuildDir.appendingPathComponent("include").appendingPathComponent("dav1d").appendingPathComponent("version.h").path) \(include.appendingPathComponent("version.h").path)
                    
                    cp \(src.appendingPathComponent(dylibName).path) \(lib.appendingPathComponent(dylibNameWithoutVersion).path)
                    """)
//            ln -sf \(lib.appendingPathComponent(dylibName).path) \(lib.appendingPathComponent(dylibNameWithoutVersion).path)
            
            // change shared library identification name
            try system("install_name_tool -id @rpath/\(dylibNameWithoutVersion) \(lib.appendingPathComponent(dylibNameWithoutVersion).path)")
            
            return install_for_ffmpeg.path
        }
        
        mutating func buildFFmpeg(archx: String, additionalEnvironment: [String : String]? = nil) throws {
            print("buildFFmpeg")
            
            try checkSource(lib: "FFmpeg")
            
            // Patch tesla's avcodec patch
            try TeslaPatchCommmand().run()
            
            let sourceDirectory = sourceOptions.sourceURL.path
            
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
                        
                        "--enable-filter=atempo,aresample",
                        "--enable-cross-compile",
                        
                        "--target-os=darwin",
                        "--arch=\(arch)",
                        "--cc=\(cc)",
                        "--as=\(`as`)",
                        "--extra-cflags=\(cFlags) -I\(installPrefix)/include",
                        "--extra-ldflags=\(ldFlags) -L\(installPrefix)/lib",
                    ]
                }
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
                
                if isDav1dBuildIncluded {
                    configureOptions.extraOptions = configureOptions.extraOptions + ["--enable-libdav1d", "--disable-xlib"]
                }
                
                configureOptions.extraOptions = configureOptions.extraOptions + (isDynamic ? ["--disable-static", "--enable-shared"] : [])
                
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
            
            let prefix = buildOptions.installURL(with: sourceOptions.lib)
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
            
            if isDav1dBuildIncluded {
                // for dav1d
                try installWithHomebrew("meson")
                try installWithHomebrew("ninja")
            }

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

        mutating func run(_ archx: String) throws {
            let lib = buildOptions.installURL(with: sourceOptions.lib)
            
            let libContentPath = lib.appendingPathComponent(archx).appendingPathComponent("lib").path
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
    
    struct XCFrameworkCommand: ParsableCommand {
        static var configuration = CommandConfiguration(commandName: "framework", abstract: "Create .xcframework")
        
        @OptionGroup var libraryOptions: LibraryOptions
        
        @OptionGroup var buildOptions: BuildOptions
        
        @OptionGroup var sourceOptions: SourceOptions
        
        @OptionGroup var xcframeworkOptions: XCFrameworkOptions
        
        mutating func run() throws {
            
            func getMedules() throws -> [String] {
                print("getMedules, buildOptions.arch = \(buildOptions.arch)")
                let lib = buildOptions.installURL(with: sourceOptions.lib)
                let contents = try FileManager.default.contentsOfDirectory(at: lib.appendingPathComponent(buildOptions.arch[0]).appendingPathComponent("lib"), includingPropertiesForKeys: nil, options: [])
                print("contents = \(contents)")
                
                var contentsStringSet = Set<String>()
                contents
                    .filter { $0.pathExtension == "dylib" }
                    .map { $0.resolvingSymlinksInPath() }
                    .map { $0.deletingPathExtension().lastPathComponent.replacingOccurrences(of: "lib", with: "") }
                    .forEach { contentsStringSet.insert($0) }
                
                let modules: [String] = Array<String>(contentsStringSet)
                
                print("modules = \(modules)")
                return modules
            }
            
            func setArgsByArchx(with module: String, args: inout [String]) throws {
                print("setArgsByArchx \(module)..")
                
                if buildOptions.arch.count == 1 {
                    print("single arch..")
                    let archx = buildOptions.arch[0]
                    print("when \(archx)...")
                    let array = archx.split(separator: "-")
                    
                    // ex) x86_64-MacOSX
                    guard array.count == 2 else {
                        throw ExitCode.failure
                    }
                    let platform = String(array[1]).lowercased()
                    
                    let output = buildOptions.installURL(with: sourceOptions.lib)
                        .appendingPathComponent(archx)
                    
                    let lib = output.appendingPathComponent("lib")
                    let include = output.appendingPathComponent("include")
                        .appendingPathComponent(sourceOptions.includePrefix + module)
                    
                    let xcf = URL(fileURLWithPath: buildOptions.buildDirectory)
                        .appendingPathComponent("xcf")
                        .appendingPathComponent(platform)
                    
                    try createDirectory(at: xcf.path)
                    
                    let xcfInclude = xcf
                        .appendingPathComponent("\(module)_include")
                    
                    try createDirectory(at: xcfInclude.path)
                    
                    try system("""
                            cp -r \(include.path) \(xcfInclude.path)
                            """)
                    
                    args += [
                        "-library", lib.appendingPathComponent("lib\(module).dylib").path,
                        "-headers", xcfInclude.path
                    ]
                } else {
                    print("multi arch..")
                    
                    var platform: String = ""
                    var archs: [String] = []
                    
                    for archx in buildOptions.arch {
                        print("when \(archx)...")
                        let array = archx.split(separator: "-")
                        
                        // ex) x86_64-MacOSX
                        guard array.count == 2 else {
                            throw ExitCode.failure
                        }
                        let _platform = String(array[1]).lowercased()
                        if platform.isEmpty { platform = _platform }
                        else if platform != _platform { throw ExitCode.validationFailure }
                        archs.append(archx)
                    }
                    
                    let output = buildOptions.installURL(with: sourceOptions.lib)
                    
                    let include = output
                        .appendingPathComponent(archs[0])
                        .appendingPathComponent("include")
                        .appendingPathComponent(sourceOptions.includePrefix + module)
                    
                    let xcf = URL(fileURLWithPath: buildOptions.buildDirectory)
                        .appendingPathComponent("xcf")
                        .appendingPathComponent(platform)
                    
                    try createDirectory(at: xcf.path)
                    
                    let fat = xcf.appendingPathComponent("lib\(module).dylib")
                    let fatArgs = archs.map {
                        output
                            .appendingPathComponent($0)
                            .appendingPathComponent("lib")
                            .appendingPathComponent("lib\(module).dylib").path
                    }
                    let xcfInclude = xcf
                        .appendingPathComponent("\(module)_include")
                    
                    try createDirectory(at: xcfInclude.path)
                    
                    try system("""
                            cp -r \(include.path) \(xcfInclude.path)
                            """)
                    
                    try launch(launchPath: "/usr/bin/lipo",
                               arguments:
                                fatArgs
                               + [
                                "-create",
                                "-output",
                                fat.path,
                               ])
                    
                    args += [
                        "-library", fat.path,
                        "-headers", xcfInclude.path,
                    ]
                }
            }
            
            func createXCFrameworks(_ module: String, args: [String]) throws {
                print("createXCFrameworks, module = [\(module)], args = \(args)")
                let output = "\(xcframeworkOptions.frameworks)/\(module).xcframework"
                
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
                let items = try fileManager.contentsOfDirectory(atPath: output)
                
                for item in items {
                    var isDirectory: ObjCBool = false
                    let itemPath = "\(output)/\(item)"
                    if fileManager.fileExists(atPath: itemPath, isDirectory: &isDirectory) {
                        if isDirectory.boolValue {
                            let source = "\(output)/\(item)/lib\(module).dylib"
                            try launch(launchPath: "/usr/bin/xcrun",
                                       arguments: ["dsymutil"]
                                       + ["\(source)"]
                                       + ["-o", "\(output)/\(item)/dSYMs/lib\(module).dylib.dSYM"])
                            try launch(launchPath: "/usr/bin/xcrun",
                                       arguments: ["strip"]
                                       + ["-S", "\(source)"])
                        }
                    }
                }
            }
            
            // ************************ crate ffmpeg xcframeworks ************************
            sourceOptions.lib = "FFmpeg"
            self.buildOptions.buildTarget = .ios
            let modules = try getMedules()
            
            try modules.forEach {
                print("target module = \($0)")
                var args: [String] = []
                
                // ************************ ios dylib ************************
                print("target = ios...")
                self.buildOptions.buildTarget = .ios
                try setArgsByArchx(with: $0, args: &args)
                
                // ************************ mac dylib ************************
                print("target = mac...")
                self.buildOptions.buildTarget = .macos
                try setArgsByArchx(with: $0, args: &args)
                
                try createXCFrameworks($0, args: args)
            }
            
            if isDav1dBuildIncluded {
                // ************************ crate dav1d xcframeworks ************************
                sourceOptions.lib = "dav1d"
                
                var args: [String] = []
                
                self.buildOptions.buildTarget = .ios
                try setArgsByArchx(with: sourceOptions.lib, args: &args)
                
                self.buildOptions.buildTarget = .macos
                try setArgsByArchx(with: sourceOptions.lib, args: &args)
                
                try createXCFrameworks(sourceOptions.lib, args: args)
            }
        }
    }
    
    struct ModuleCommand: ParsableCommand {
        static var configuration = CommandConfiguration(commandName: "module", abstract: "Enable modules to allow import from Swift")
        
        @OptionGroup var libraryOptions: LibraryOptions
        
        @OptionGroup var buildOptions: BuildOptions
        
        @OptionGroup var xcframeworkOptions: XCFrameworkOptions
        
        @OptionGroup var sourceOptions: SourceOptions
        
        mutating func run() throws {
            print("ModuleCommand...")
            
            func getMedules() throws -> [String] {
                print("getMedules, buildOptions.arch = \(buildOptions.arch)")
                let lib = buildOptions.installURL(with: sourceOptions.lib)
                let contents = try FileManager.default.contentsOfDirectory(at: lib.appendingPathComponent(buildOptions.arch[0]).appendingPathComponent("lib"), includingPropertiesForKeys: nil, options: [])
                print("contents = \(contents)")
                
                var contentsStringSet = Set<String>()
                contents
                    .filter { $0.pathExtension == "dylib" }
                    .map { $0.resolvingSymlinksInPath() }
                    .map { $0.deletingPathExtension().lastPathComponent.replacingOccurrences(of: "lib", with: "") }
                    .forEach { contentsStringSet.insert($0) }
                
                let modules: [String] = Array<String>(contentsStringSet)
                
                print("modules = \(modules)")
                return modules
            }
            
            func createModuleMap(_ module: String) throws {
                let path = "\(xcframeworkOptions.frameworks)/\(module).xcframework"
                let data = try Data(contentsOf: URL(fileURLWithPath: "\(path)/Info.plist"))
                guard let info = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
                      let libraries = info["AvailableLibraries"] as? [[String: Any]] else {
                    throw ExitCode.failure
                }
                
                for dict in libraries {
                    guard let headersPath = dict["HeadersPath"] as? String,
                          let libraryIdentifier = dict["LibraryIdentifier"] as? String else {
                        throw ExitCode.failure
                    }
                    
                    let to = URL(fileURLWithPath: "\(path)/\(libraryIdentifier)/\(headersPath)/lib\(module)/module.modulemap")
                    
                    try createDirectory(at: to.deletingLastPathComponent().path)
                    
                    try removeItem(at: to.path)
                    
                    do {
                        try copyItem(at: "ModuleMaps/\(module)/module.modulemap",
                                     to: to.path)
                    }
                    catch {
                        let nserror = error as NSError
                        guard let posixError = nserror.userInfo[NSUnderlyingErrorKey] as? POSIXError,
                              posixError.code == .ENOENT
                        else {
                            print(#line, error)
                            throw error
                        }
                        
                        let content = """
                            module \(module) {
                                umbrella "."
                                export *
                            }
                            """
                        try content.write(to: to, atomically: false, encoding: .utf8)
                    }
                }
            }
            
            // ************************ ffmpeg ************************
            sourceOptions.lib = "FFmpeg"
            self.buildOptions.buildTarget = .ios
            let modules = try getMedules()
            
            try modules.forEach {
                print("target module = \($0)")
                
                print("target = ios...")
                self.buildOptions.buildTarget = .ios
                try createModuleMap($0)
                
                print("target = mac...")
                self.buildOptions.buildTarget = .macos
                try createModuleMap($0)
            }
            
            if isDav1dBuildIncluded {
                // ************************ dav1d ************************
                sourceOptions.lib = "dav1d"
                
                self.buildOptions.buildTarget = .ios
                try createModuleMap(sourceOptions.lib)
                
                self.buildOptions.buildTarget = .macos
                try createModuleMap(sourceOptions.lib)
            }
        }
    }
    
    struct TeslaPatchCommmand: ParsableCommand {
        func run() throws {
            do {
                let teslaPatch = "Resources/avcodec.c.patch"
                let sourceFile = "FFmpeg/libavcodec/avcodec.c"
                let patch   = try readCurrentDirectoryFile(fileName: teslaPatch)
                let source  = try readCurrentDirectoryFile(fileName: sourceFile)
                let patched = try appendIfNotAlreadyAppended(a: source, b: patch)
                try writeStringToFile(string: patched, relativePath: sourceFile)
            }
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

func readCurrentDirectoryFile(fileName: String) throws -> String {
    let currentDirectoryURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let fileURL = currentDirectoryURL.appendingPathComponent(fileName)
    return try readFile(fileURL.path)
}

func readFile(_ path: String) throws -> String {
    return try String(contentsOfFile: path, encoding: .utf8)
}

func appendIfNotAlreadyAppended(a: String, b: String) throws -> String {
    if a.hasSuffix(b) {
        return a
    } else {
        return a + b
    }
}

func writeStringToFile(string: String, relativePath: String) throws {
    let fileURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(relativePath)
    try string.write(to: fileURL, atomically: true, encoding: .utf8)
}

func executeCommand(_ command: String) throws -> String {
    let task = Process()
    task.launchPath = "/bin/zsh"
    task.arguments = ["-c", command]

    let pipe = Pipe()
    task.standardOutput = pipe

    task.launch()
    task.waitUntilExit()

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    guard let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .newlines) else {
        throw ExitCode.failure
    }
    return output
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
