import Testing
import Foundation
@testable import Core

@Suite("Finding a project's own icon", .scratchDirectory)
struct RepoIconDetectorTests {
    @discardableResult
    private func repository(_ files: [String: Data]) throws -> String {
        let root = TestScratch.unique("unifieddev-icon")
        for (relative, contents) in files {
            let full = (root as NSString).appendingPathComponent(relative)
            try FileManager.default.createDirectory(
                atPath: (full as NSString).deletingLastPathComponent,
                withIntermediateDirectories: true
            )
            try contents.write(to: URL(fileURLWithPath: full))
        }
        try FileManager.default.createDirectory(atPath: root, withIntermediateDirectories: true)
        return root
    }

    private func png(_ width: Int, _ height: Int) -> Data {
        var data = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        var header = Data("IHDR".utf8)
        header.append(contentsOf: be32(UInt32(width)))
        header.append(contentsOf: be32(UInt32(height)))
        header.append(contentsOf: [8, 6, 0, 0, 0])
        data.append(contentsOf: be32(UInt32(header.count - 4)))
        data.append(header)
        data.append(contentsOf: be32(crc32(header)))
        data.append(contentsOf: be32(0))
        data.append(Data("IEND".utf8))
        data.append(contentsOf: be32(crc32(Data("IEND".utf8))))
        return data
    }

    private func ico(_ sizes: [Int]) -> Data {
        var data = Data()
        data.append(contentsOf: le16(0))
        data.append(contentsOf: le16(1))
        data.append(contentsOf: le16(UInt16(sizes.count)))
        for (index, size) in sizes.enumerated() {
            let byte = UInt8(size == 256 ? 0 : size)
            data.append(contentsOf: [byte, byte, 0, 0])
            data.append(contentsOf: le16(1))
            data.append(contentsOf: le16(32))
            data.append(contentsOf: be32(0))
            data.append(contentsOf: be32(UInt32(6 + 16 * sizes.count + index)))
        }
        return data
    }

    private func icns(_ types: [String]) -> Data {
        var body = Data()
        for type in types {
            body.append(Data(type.utf8))
            body.append(contentsOf: be32(9))
            body.append(0)
        }
        var data = Data("icns".utf8)
        data.append(contentsOf: be32(UInt32(body.count + 8)))
        data.append(body)
        return data
    }

    private func jpeg(_ width: Int, _ height: Int) -> Data {
        var data = Data([0xFF, 0xD8])
        data.append(contentsOf: [0xFF, 0xE0, 0x00, 0x10])
        data.append(Data("JFIF".utf8))
        data.append(contentsOf: [0x00, 0x01, 0x01, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00])
        data.append(contentsOf: [0xFF, 0xC0, 0x00, 0x0B, 0x08])
        data.append(contentsOf: [UInt8(height >> 8 & 0xFF), UInt8(height & 0xFF)])
        data.append(contentsOf: [UInt8(width >> 8 & 0xFF), UInt8(width & 0xFF)])
        data.append(contentsOf: [0x01, 0x01, 0x11, 0x00])
        data.append(contentsOf: [0xFF, 0xD9])
        return data
    }

    private func svgData(_ body: String = "<rect/>") -> Data {
        Data("<?xml version=\"1.0\"?>\n<svg xmlns=\"http://www.w3.org/2000/svg\">\(body)</svg>".utf8)
    }

    private func be32(_ value: UInt32) -> [UInt8] {
        [UInt8(value >> 24 & 0xFF), UInt8(value >> 16 & 0xFF), UInt8(value >> 8 & 0xFF), UInt8(value & 0xFF)]
    }

    private func le16(_ value: UInt16) -> [UInt8] {
        [UInt8(value & 0xFF), UInt8(value >> 8 & 0xFF)]
    }

    private func crc32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFF_FFFF
        for byte in data {
            crc ^= UInt32(byte)
            for _ in 0..<8 {
                crc = (crc & 1) == 1 ? (crc >> 1) ^ 0xEDB8_8320 : crc >> 1
            }
        }
        return crc ^ 0xFFFF_FFFF
    }

    private func name(of candidate: RepoIconCandidate?) -> String? {
        candidate.map { ($0.path as NSString).lastPathComponent }
    }

    @Test("the small artwork a site drew for a tab wins over its big marketing mark")
    func favouriteAmongMany() throws {
        let root = try repository([
            "public/favicon.svg": svgData(),
            "public/favicon.ico": ico([16, 32, 48]),
            "public/brand/mark.svg": svgData(),
            "public/brand/icon-512.png": png(512, 512),
            "public/brand/apple-touch-icon-180.png": png(180, 180),
            "public/brand/favicon-32.png": png(32, 32),
            "README.md": Data("hello".utf8),
        ])

        let best = RepoIconDetector.detect(in: root)
        #expect(name(of: best) == "favicon.svg")
        #expect(best?.origin == .favicon)
        #expect(best?.format == .svg)

        let all = RepoIconDetector.candidates(in: root).map { ($0.path as NSString).lastPathComponent }
        #expect(all == [
            "favicon.svg",
            "apple-touch-icon-180.png",
            "favicon.ico",
            "favicon-32.png",
            "mark.svg",
            "icon-512.png",
        ])
    }

    @Test("a raster beats a smaller raster, and vector beats both")
    func rankingWithinAKind() throws {
        let small = try repository(["public/favicon-64.png": png(64, 64)])
        #expect(RepoIconDetector.detect(in: small)?.pixels == 64)

        let bigger = try repository([
            "public/favicon-64.png": png(64, 64),
            "public/favicon-256.png": png(256, 256),
        ])
        #expect(name(of: RepoIconDetector.detect(in: bigger)) == "favicon-256.png")

        let vector = try repository([
            "public/favicon-1024.png": png(1024, 1024),
            "public/favicon.svg": svgData(),
        ])
        #expect(name(of: RepoIconDetector.detect(in: vector)) == "favicon.svg")
    }

    @Test("a wordmark is not a mark, however large it is")
    func wordmarks() throws {
        let wide = try repository(["public/logo.png": png(600, 40)])
        #expect(RepoIconDetector.detect(in: wide) == nil)

        let svg = try repository([
            "assets/logo.svg": Data("<svg viewBox=\"0 0 480 64\"><rect/></svg>".utf8),
        ])
        #expect(RepoIconDetector.detect(in: svg) == nil)

        let nearlySquare = try repository(["public/logo.png": png(200, 160)])
        #expect(RepoIconDetector.detect(in: nearlySquare)?.pixels == 200)

        let unstated = try repository(["assets/logo.svg": svgData()])
        #expect(RepoIconDetector.detect(in: unstated) != nil)
    }

    @Test("the plain name beats the one drawn for one theme")
    func themeVariants() throws {
        let root = try repository([
            "assets/logo-dark.svg": svgData(),
            "assets/logo.svg": svgData(),
        ])
        #expect(name(of: RepoIconDetector.detect(in: root)) == "logo.svg")

        let onlyDark = try repository(["assets/logo-dark.svg": svgData()])
        #expect(name(of: RepoIconDetector.detect(in: onlyDark)) == "logo-dark.svg")
    }

    @Test("the plain favicon beats the ones with an unread count drawn on them")
    func badgedVariants() throws {
        var files: [String: Data] = [
            "public/favicon.svg": svgData(),
            "public/favicon.ico": ico([16, 32, 48]),
            "public/favicon-96x96.png": png(96, 96),
            "public/apple-touch-icon.png": png(180, 180),
        ]
        files["public/favicon-unread.svg"] = svgData()
        files["public/favicon-unread.ico"] = ico([16, 32, 48])
        for count in 1...9 {
            files["public/favicon-unread-\(count).svg"] = svgData()
            files["public/favicon-unread-\(count).ico"] = ico([16, 32, 48])
        }
        let root = try repository(files)

        #expect(name(of: RepoIconDetector.detect(in: root)) == "favicon.svg")

        let invented = try repository([
            "public/favicon.svg": svgData(),
            "public/favicon-notification.svg": svgData(),
            "public/favicon-hover.svg": svgData(),
            "public/favicon-alert-2.svg": svgData(),
        ])
        #expect(name(of: RepoIconDetector.detect(in: invented)) == "favicon.svg")

        let onlyBadged = try repository(["public/favicon-unread-1.svg": svgData()])
        #expect(name(of: RepoIconDetector.detect(in: onlyBadged)) == "favicon-unread-1.svg")
    }

    @Test("a size in a name is not a word added to it")
    func sizesAreNotDecoration() throws {
        #expect(RepoIconDetector.decoration(ofFileNamed: "favicon.svg") == 0)
        #expect(RepoIconDetector.decoration(ofFileNamed: "favicon-96x96.png") == 0)
        #expect(RepoIconDetector.decoration(ofFileNamed: "icon-512.png") == 0)
        #expect(RepoIconDetector.decoration(ofFileNamed: "Icon-60@2x.png") == 0)
        #expect(RepoIconDetector.decoration(ofFileNamed: "favicon-unread-1.svg") == 1)
        #expect(RepoIconDetector.decoration(ofFileNamed: "logo-dark.svg") == 1)
        #expect(RepoIconDetector.decoration(ofFileNamed: "logo-icon-dark.svg") == 2)

        #expect(RepoIconDetector.decoration(ofFileNamed: "apple-touch-icon.png") == 0)
        #expect(RepoIconDetector.decoration(ofFileNamed: "apple-touch-icon-180.png") == 0)
        #expect(RepoIconDetector.decoration(ofFileNamed: "web-app-manifest-512x512.png") == 0)

        let sized = try repository([
            "public/favicon.png": png(32, 32),
            "public/favicon-512x512.png": png(512, 512),
        ])
        #expect(name(of: RepoIconDetector.detect(in: sized)) == "favicon-512x512.png")

        let both = try repository([
            "public/favicon.png": png(32, 32),
            "public/favicon-unread-512.png": png(512, 512),
        ])
        #expect(name(of: RepoIconDetector.detect(in: both)) == "favicon.png")

        let touch = try repository(["public/apple-touch-icon.png": png(180, 180)])
        #expect(name(of: RepoIconDetector.detect(in: touch)) == "apple-touch-icon.png")
    }

    @Test("a site whose identity is a photograph is answered with the square crop of it")
    func personalSite() throws {
        let root = try repository([
            "public/favicon.ico": ico([16]),
            "public/images/avatar.jpg": jpeg(1400, 934),
            "public/images/avatar-boxed.jpg": jpeg(934, 934),
            "public/images/404.png": png(600, 400),
            "public/images/algolia.svg": svgData(),
        ])

        let best = RepoIconDetector.detect(in: root)
        #expect(name(of: best) == "avatar-boxed.jpg")
        #expect(best?.format == .jpeg)

        #expect(
            RepoIconDetector.candidates(in: root).map { ($0.path as NSString).lastPathComponent }
                == ["avatar-boxed.jpg", "avatar.jpg"]
        )

        let both = try repository([
            "public/favicon.svg": svgData(),
            "public/images/avatar-boxed.jpg": jpeg(934, 934),
        ])
        #expect(name(of: RepoIconDetector.detect(in: both)) == "favicon.svg")
    }

    @Test("the squarer of two pieces of the same artwork wins")
    func squareness() throws {
        let root = try repository([
            "public/logo.png": png(1400, 934),
            "public/logo-square.png": png(512, 512),
        ])
        #expect(name(of: RepoIconDetector.detect(in: root)) == "logo-square.png")

        let formats = try repository([
            "public/logo.svg": Data("<svg viewBox=\"0 0 300 200\"><rect/></svg>".utf8),
            "public/logo-square.png": png(512, 512),
        ])
        #expect(name(of: RepoIconDetector.detect(in: formats)) == "logo.svg")

        let hair = try repository([
            "public/icon.png": png(500, 496),
            "public/icon-dark.png": png(500, 500),
        ])
        #expect(name(of: RepoIconDetector.detect(in: hair)) == "icon.png")
    }

    @Test("a photograph is measured from its frame header, however much is in front of it")
    func jpegHeaders() throws {
        let root = try repository(["public/avatar.jpg": jpeg(934, 934)])
        #expect(RepoIconDetector.detect(in: root)?.pixels == 934)

        let long = try repository(["public/avatar.jpeg": jpeg(934, 934)])
        #expect(name(of: RepoIconDetector.detect(in: long)) == "avatar.jpeg")

        let truncated = try repository(["public/avatar.jpg": Data([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10])])
        #expect(RepoIconDetector.detect(in: truncated) == nil)

        let small = try repository(["public/avatar.jpg": jpeg(24, 24)])
        #expect(RepoIconDetector.detect(in: small) == nil)
        let banner = try repository(["public/logo.jpg": jpeg(1200, 400)])
        #expect(RepoIconDetector.detect(in: banner) == nil)
    }

    @Test("a repository with nothing in it keeps its monogram")
    func nothingToFind() throws {
        let root = try repository([
            "README.md": Data("hello".utf8),
            "src/main.swift": Data("print(1)".utf8),
            "public/index.php": Data("<?php".utf8),
            "public/images/screenshot.png": png(1600, 900),
            "public/brand/wordmark.svg": svgData(),
        ])
        #expect(RepoIconDetector.detect(in: root) == nil)
    }

    @Test("a sixteen pixel favicon loses to the monogram rather than being blown up")
    func tinyIco() throws {
        let root = try repository(["public/favicon.ico": ico([16])])
        #expect(RepoIconDetector.detect(in: root) == nil)

        let atTheFloor = try repository(["public/favicon.ico": ico([16, 32])])
        #expect(RepoIconDetector.detect(in: atTheFloor)?.pixels == 32)

        let tinyPNG = try repository(["public/favicon-16.png": png(16, 16)])
        #expect(RepoIconDetector.detect(in: tinyPNG) == nil)
    }

    @Test("a file that is not the image it is named as is refused, and the next one wins")
    func corruptCandidates() throws {
        let root = try repository([
            "public/favicon.svg": Data("<!doctype html><html>404 Not Found</html>".utf8),
            "public/favicon.ico": Data(),
            "public/apple-touch-icon.png": Data("this is not a png".utf8),
            "public/brand/icon-256.png": png(256, 256),
        ])

        let all = RepoIconDetector.candidates(in: root)
        #expect(all.count == 1)
        #expect(name(of: all.first) == "icon-256.png")
    }

    @Test("a broken file that is the only candidate leaves the monogram alone")
    func onlyCandidateIsBroken() throws {
        let root = try repository(["public/favicon.png": Data("nope".utf8)])
        #expect(RepoIconDetector.detect(in: root) == nil)
    }

    @Test("an icns whose stated length runs past the end of the file is refused")
    func truncatedICNS() throws {
        var data = icns(["ic10", "ic09"])
        data = data.prefix(12)
        let root = try repository(["Resources/AppIcon.icns": data])
        #expect(RepoIconDetector.detect(in: root) == nil)
    }

    @Test("an icns with nothing but bookkeeping chunks in it holds no artwork")
    func icnsWithoutArtwork() throws {
        let root = try repository(["Resources/AppIcon.icns": icns(["TOC ", "info"])])
        #expect(RepoIconDetector.detect(in: root) == nil)
    }

    @Test("an app's own icon outranks the favicon of the site in the same checkout")
    func appIconWins() throws {
        let root = try repository([
            "Resources/AppIcon.icns": icns(["ic11", "ic09", "ic10"]),
            "docs/public/favicon.svg": svgData(),
        ])
        let best = RepoIconDetector.detect(in: root)
        #expect(name(of: best) == "AppIcon.icns")
        #expect(best?.origin == .appIcon)
        #expect(best?.pixels == 1024)
    }

    @Test("the flattened icns outranks the layered document beside it")
    func icnsBeatsIconBundle() throws {
        let root = try repository([
            "Resources/AppIcon.icns": icns(["ic10"]),
            "Resources/UnifiedDev.icon/icon.json": Data("""
            {"groups": [{"layers": [{"image-name": "mark.svg"}]},
                        {"layers": [{"image-name": "ground.svg"}]}]}
            """.utf8),
            "Resources/UnifiedDev.icon/Assets/mark.svg": svgData(),
            "Resources/UnifiedDev.icon/Assets/ground.svg": svgData(),
        ])

        let all = RepoIconDetector.candidates(in: root)
        #expect(all.map { ($0.path as NSString).lastPathComponent } == ["AppIcon.icns", "UnifiedDev.icon"])
        #expect(all.last?.format == .layered)
    }

    @Test("a layered document is drawn back to front, and needs the assets it names")
    func iconBundleLayers() throws {
        let root = try repository([
            "UnifiedDev.icon/icon.json": Data("""
            {"groups": [{"layers": [{"image-name": "mark.svg"}]},
                        {"layers": [{"image-name": "panel.svg"}]},
                        {"layers": [{"image-name": "ground.svg"}]}]}
            """.utf8),
            "UnifiedDev.icon/Assets/mark.svg": svgData(),
            "UnifiedDev.icon/Assets/panel.svg": svgData(),
            "UnifiedDev.icon/Assets/ground.svg": svgData(),
        ])

        let bundle = (root as NSString).appendingPathComponent("UnifiedDev.icon")
        let layers = RepoIconFile.layers(ofIconBundle: bundle)
            .map { ($0.path as NSString).lastPathComponent }
        #expect(layers == ["ground.svg", "panel.svg", "mark.svg"])
        #expect(RepoIconDetector.detect(in: root)?.format == .layered)

        let empty = try repository([
            "UnifiedDev.icon/icon.json": Data("""
            {"groups": [{"layers": [{"image-name": "mark.svg"}]}]}
            """.utf8),
        ])
        #expect(RepoIconDetector.detect(in: empty) == nil)
    }

    @Test("a layer's colour comes from icon.json, because the artwork under it is a silhouette")
    func iconBundleFills() throws {
        let root = try repository([
            "App.icon/icon.json": Data("""
            {"fill": "automatic", "groups": [
              {"layers": [
                {"image-name": "mark.svg", "name": "Mark",
                 "fill": {"linear-gradient": ["srgb:0.6627,0.9255,0.8824,1.000",
                                              "srgb:0.5412,0.8118,0.7686,0.500"],
                          "orientation": {"start": {"x": 0.25, "y": 0.4},
                                          "stop": {"x": 0.75, "y": 0.7}}},
                 "opacity": 0.5}
              ]},
              {"layers": [
                {"image-name": "hidden.svg", "hidden": true},
                {"image-name": "flat.svg", "fill": "#2196F3"}
              ]},
              {"layers": [{"image-name": "ground.svg"}]}
            ]}
            """.utf8),
            "App.icon/Assets/mark.svg": svgData(),
            "App.icon/Assets/hidden.svg": svgData(),
            "App.icon/Assets/flat.svg": svgData(),
            "App.icon/Assets/ground.svg": svgData(),
        ])

        let bundle = (root as NSString).appendingPathComponent("App.icon")
        let layers = RepoIconFile.layers(ofIconBundle: bundle)

        #expect(layers.map { ($0.path as NSString).lastPathComponent }
                == ["ground.svg", "flat.svg", "mark.svg"])

        #expect(layers[0].fill == .artwork)
        #expect(layers[0].opacity == 1)

        #expect(layers[1].fill == .solid(RepoIconColour(red: 33 / 255, green: 150 / 255, blue: 243 / 255)))

        #expect(layers[2].opacity == 0.5)
        #expect(layers[2].fill == .linearGradient(
            from: RepoIconColour(red: 0.6627, green: 0.9255, blue: 0.8824, alpha: 1),
            to: RepoIconColour(red: 0.5412, green: 0.8118, blue: 0.7686, alpha: 0.5),
            start: RepoIconLayerPoint(x: 0.25, y: 0.4),
            stop: RepoIconLayerPoint(x: 0.75, y: 0.7)
        ))
    }

    @Test("a gradient with no orientation runs down the canvas, which is the case the file omits")
    func iconBundleDefaultOrientation() throws {
        let root = try repository([
            "App.icon/icon.json": Data("""
            {"groups": [{"layers": [{"image-name": "a.svg",
              "fill": {"linear-gradient": ["srgb:1,0,0,1", "srgb:0,0,1,1"]}}]}]}
            """.utf8),
            "App.icon/Assets/a.svg": svgData(),
        ])

        let bundle = (root as NSString).appendingPathComponent("App.icon")
        #expect(RepoIconFile.layers(ofIconBundle: bundle)[0].fill == .linearGradient(
            from: RepoIconColour(red: 1, green: 0, blue: 0, alpha: 1),
            to: RepoIconColour(red: 0, green: 0, blue: 1, alpha: 1),
            start: RepoIconLayerPoint(x: 0.5, y: 0),
            stop: RepoIconLayerPoint(x: 0.5, y: 1)
        ))
    }

    @Test("the colour space a fill names is read and dropped, and nonsense is refused")
    func iconBundleColours() {
        #expect(RepoIconFile.colour("srgb:0.5,0.25,0.125,0.75")
                == RepoIconColour(red: 0.5, green: 0.25, blue: 0.125, alpha: 0.75))
        #expect(RepoIconFile.colour("display-p3:1,0,0,1")
                == RepoIconColour(red: 1, green: 0, blue: 0, alpha: 1))
        #expect(RepoIconFile.colour("srgb:0,0,0")?.alpha == 1)
        #expect(RepoIconFile.colour("#fff") == RepoIconColour(red: 1, green: 1, blue: 1, alpha: 1))
        #expect(RepoIconFile.colour("automatic") == nil)
        #expect(RepoIconFile.colour("srgb:1,2") == nil)
        #expect(RepoIconFile.colour("") == nil)
    }

    @Test("an asset catalogue's app icon set is answered with its largest image")
    func appIconSet() throws {
        let root = try repository([
            "MyApp/Assets.xcassets/AppIcon.appiconset/Contents.json": Data("{}".utf8),
            "MyApp/Assets.xcassets/AppIcon.appiconset/icon-32.png": png(32, 32),
            "MyApp/Assets.xcassets/AppIcon.appiconset/icon-1024.png": png(1024, 1024),
            "MyApp/Assets.xcassets/AppIcon.appiconset/icon-512.png": png(512, 512),
        ])

        let all = RepoIconDetector.candidates(in: root)
        #expect(all.count == 1)
        #expect(name(of: all.first) == "icon-1024.png")
        #expect(all.first?.origin == .appIcon)
    }

    @Test("an icon inside a dependency, a build folder or a bundled app is not this project's")
    func skippedDirectories() throws {
        let root = try repository([
            "node_modules/some-package/icon.png": png(512, 512),
            "vendor/other/public/favicon.svg": svgData(),
            ".build/debug/UnifiedDev.app/Contents/Resources/AppIcon.icns": icns(["ic10"]),
            "Pods/Thing/Assets.xcassets/AppIcon.appiconset/icon-1024.png": png(1024, 1024),
            ".git/hooks/logo.svg": svgData(),
            "public/vendor/horizon/favicon.png": png(512, 512),
            "public/vendor/horizon/manifest.json": Data(
                #"{"icons":[{"src":"/vendor/horizon/img/horizon.svg"}]}"#.utf8
            ),
            "public/vendor/horizon/img/horizon.svg": svgData(),
            "public/storage/uploads/avatar.jpg": jpeg(1024, 1024),
        ])
        #expect(RepoIconDetector.candidates(in: root).isEmpty)
    }

    @Test("a manifest's icons are read, and resolved from the manifest's own directory")
    func webManifest() throws {
        let root = try repository([
            "public/site.webmanifest": Data("""
            {"name": "Thing", "icons": [
                {"src": "/brand/icon-192.png", "sizes": "192x192"},
                {"src": "brand/icon-512.png", "sizes": "512x512"}
            ]}
            """.utf8),
            "public/brand/icon-192.png": png(192, 192),
            "public/brand/icon-512.png": png(512, 512),
        ])

        let all = RepoIconDetector.candidates(in: root)
        #expect(all.count == 2)
        #expect(name(of: all.first) == "icon-512.png")
        #expect(all.first?.origin == .manifest)
    }

    @Test("a manifest.json that is a build manifest states no icons and is left alone")
    func buildManifestIsNotAWebManifest() throws {
        let root = try repository([
            "public/build/manifest.json": Data("""
            {"resources/js/app.js": {"file": "assets/app-CQSmo0f.js", "isEntry": true}}
            """.utf8),
            "public/build/assets/icon-512.png": png(512, 512),
        ])
        #expect(RepoIconDetector.detect(in: root) == nil)
    }

    @Test("a manifest naming a remote icon or an escape from the repository is ignored")
    func hostileManifest() throws {
        let root = try repository([
            "public/manifest.json": Data("""
            {"icons": [{"src": "https://example.com/icon.png"}, {"src": ""}]}
            """.utf8),
        ])
        #expect(RepoIconDetector.detect(in: root) == nil)
    }

    @Test("the ranking is a total order, so the answer never depends on the file system")
    func rankingIsTotal() {
        let candidates = [
            RepoIconCandidate(path: "/a/favicon.svg", format: .svg, origin: .favicon, pixels: 0),
            RepoIconCandidate(path: "/a/icon.png", format: .png, origin: .brand, pixels: 512),
            RepoIconCandidate(path: "/a/AppIcon.icns", format: .icns, origin: .appIcon, pixels: 1024),
            RepoIconCandidate(path: "/b/favicon.png", format: .png, origin: .favicon, pixels: 512),
            RepoIconCandidate(path: "/c/favicon.png", format: .png, origin: .favicon, pixels: 512),
        ]
        for first in candidates {
            #expect(first.isBetter(than: first) == false)
            for second in candidates where first != second {
                #expect(first.isBetter(than: second) != second.isBetter(than: first))
            }
        }
        #expect(candidates.sorted { $0.isBetter(than: $1) }.map(\.path) == [
            "/a/AppIcon.icns", "/a/favicon.svg", "/b/favicon.png", "/c/favicon.png", "/a/icon.png",
        ])
    }

    @Test("Unified Dev's own checkout answers with the icon it ships")
    func unifieddevItself() throws {
        let root = URL(fileURLWithPath: #filePath)
            .resolvingSymlinksInPath()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .path
        try #require(FileManager.default.fileExists(atPath: root + "/Resources/UnifiedDev.icon"))
        #expect(!FileManager.default.fileExists(atPath: root + "/Resources/AppIcon.icns"))

        let best = RepoIconDetector.detect(in: root)
        #expect(name(of: best) == "UnifiedDev.icon")
        #expect(best?.format == .layered)
    }
}

@Suite("Storing a project's icon", .tags(.persistence), .scratchDirectory)
struct RepoIconStorageTests {
    @Test("a found icon and where it came from survive a round trip")
    func roundTrip() async throws {
        let store = try makeTestStore("repo-icon")
        let repo = try await store.upsert(Repo(
            name: "unifieddev",
            path: "/tmp/unifieddev",
            iconPath: "/tmp/unifieddev/public/favicon.svg",
            iconSource: .detected
        ))

        let read = try #require(try await store.repo(id: repo.id))
        #expect(read.iconPath == "/tmp/unifieddev/public/favicon.svg")
        #expect(read.iconSource == .detected)
        #expect(read.hasIcon)
    }

    @Test("asking for the monogram back clears the path rather than hiding it")
    func backToTheMonogram() async throws {
        let store = try makeTestStore("repo-icon")
        var repo = try await store.upsert(Repo(
            name: "unifieddev", path: "/tmp/unifieddev",
            iconPath: "/tmp/x.png", iconSource: .detected
        ))

        repo.iconPath = nil
        repo.iconSource = .monogram
        _ = try await store.upsert(repo)

        let read = try #require(try await store.repo(id: repo.id))
        #expect(read.iconPath == nil)
        #expect(read.iconSource == .monogram)
        #expect(read.hasIcon == false)
    }

    @Test("a project added before Unified Dev looked for icons is not silently redrawn")
    func existingProjectsKeepTheirMonogram() async throws {
        let path = TestScratch.unique("unifieddev-icon-migrate") + ".sqlite"
        let id: String
        do {
            let db = try SQLiteDatabase(path: path)
            try db.execute("""
                CREATE TABLE repos (
                    id TEXT PRIMARY KEY,
                    name TEXT NOT NULL,
                    path TEXT NOT NULL UNIQUE,
                    default_branch TEXT NOT NULL DEFAULT 'main',
                    accent TEXT NOT NULL DEFAULT '4C8DF6',
                    sort_order INTEGER NOT NULL DEFAULT 0,
                    collapsed INTEGER NOT NULL DEFAULT 0,
                    created_at REAL NOT NULL
                );
                """)
            id = newID()
            try db.run(
                "INSERT INTO repos (id, name, path, created_at) VALUES (?, ?, ?, ?)",
                [.text(id), .text("there-there"), .text("/tmp/there-there"), .double(0)]
            )
        }

        let store = try Store(path: path)
        let repo = try #require(try await store.repos().first { $0.id == RepoID(id) })
        #expect(repo.iconSource == .undetected)
        #expect(repo.iconPath == nil)
        #expect(repo.hasIcon == false)
    }
}
