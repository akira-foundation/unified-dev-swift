import CoreGraphics
import Darwin
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import Core

@Suite("Which picture files a canvas will decode")
struct CanvasImageFileTests {
    private let folder: URL

    init() throws {
        folder = FileManager.default.temporaryDirectory.appending(path: "canvas-image-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    private func png(_ name: String, side: Int) throws -> String {
        let url = folder.appending(path: name)
        let context = try #require(CGContext(
            data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        let image = try #require(context.makeImage())
        let destination = try #require(CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination))
        return url.path
    }

    @Test func aPictureOfOrdinarySizeIsAdmitted() throws {
        #expect(CanvasImageFile.admits(try png("a.png", side: 20)))
    }

    @Test func aFIFOIsRefusedWithoutBlocking() {
        let path = folder.appending(path: "a.png").path
        #expect(mkfifo(path, 0o644) == 0)
        #expect(!CanvasImageFile.admits(path))
    }

    @Test func aFolderIsRefused() throws {
        let path = folder.appending(path: "b.png")
        try FileManager.default.createDirectory(at: path, withIntermediateDirectories: true)
        #expect(!CanvasImageFile.admits(path.path))
    }

    @Test func aMissingFileIsRefused() {
        #expect(!CanvasImageFile.admits(folder.appending(path: "gone.png").path))
    }

    @Test func aFileOverTheByteLimitIsRefused() throws {
        let path = try png("a.png", side: 20)
        #expect(!CanvasImageFile.admits(path, maximumBytes: 8))
    }

    @Test func aPictureOverThePixelLimitIsRefusedBeforeDecoding() throws {
        let path = try png("a.png", side: 20)
        #expect(!CanvasImageFile.admits(path, maximumPixels: 399))
        #expect(CanvasImageFile.admits(path, maximumPixels: 400))
    }

    @Test func aFileThatSaysItIsAPictureAndIsNotIsRefused() throws {
        let url = folder.appending(path: "junk.png")
        try Data("not a picture".utf8).write(to: url)
        #expect(!CanvasImageFile.admits(url.path))
    }

    @Test(arguments: ["a.svg", "a.pdf", "A.SVG"])
    func aVectorFileIsAdmittedOnItsBytesAlone(name: String) throws {
        let url = folder.appending(path: name)
        try Data("<svg xmlns=\"http://www.w3.org/2000/svg\"/>".utf8).write(to: url)
        #expect(CanvasImageFile.admits(url.path))
        #expect(!CanvasImageFile.admits(url.path, maximumBytes: 2))
    }
}
