import AppKit
import Foundation
import Synchronization
import Core

@MainActor
struct ProbeHarness {
    let subject: String

    var flag: String { "--\(subject)-probe" }

    var name: String { "\(subject) probe" }

    var isRequested: Bool { CommandLine.arguments.contains(flag) }

    var outputPath: String {
        Self.value(for: flag) ?? (NSTemporaryDirectory() + "unifieddev-\(subject)-probe.json")
    }

    static func value(for flag: String) -> String? {
        let arguments = CommandLine.arguments
        guard let index = arguments.firstIndex(of: flag), index + 1 < arguments.count else {
            return nil
        }
        return arguments[index + 1]
    }

    static func text(_ flag: String, or fallback: String) -> String {
        value(for: flag) ?? fallback
    }

    static func count(_ flag: String, or fallback: Int) -> Int {
        Int(value(for: flag) ?? "") ?? fallback
    }

    static func points(_ flag: String, or fallback: CGFloat) -> CGFloat {
        CGFloat(Double(value(for: flag) ?? "") ?? Double(fallback))
    }

    static func isPresent(_ flag: String) -> Bool {
        CommandLine.arguments.contains(flag)
    }

    func settle() async {
        try? await Task.sleep(for: .seconds(3))
    }

    private func hideWindowsAsTheyOpen() async {
        guard Self.isPresent("--window-hidden") else { return }
        for _ in 0..<300 {
            for window in NSApp.windows where window.alphaValue > 0 { window.alphaValue = 0 }
            try? await Task.sleep(for: .milliseconds(10))
        }
    }

    func window() async -> (window: NSWindow, content: NSView) {
        async let hiding: Void = hideWindowsAsTheyOpen()
        await settle()
        await hiding
        for _ in 0..<240 {
            let candidate = NSApp.windows.first {
                $0.isVisible && $0.contentView != nil && $0.parent == nil
                    && $0.styleMask.contains(.titled)
            }
            if let candidate, let content = candidate.contentView {
                if Self.isPresent("--window-hidden") { candidate.alphaValue = 0 }
                await resize(candidate)
                return (candidate, content)
            }
            if NSApp.windows.isEmpty, let delegate = NSApp.delegate {
                _ = delegate.applicationShouldHandleReopen?(NSApp, hasVisibleWindows: false)
            }
            try? await Task.sleep(for: .milliseconds(250))
        }
        let all = NSApp.windows.map {
            "\($0.title)|\(type(of: $0))|vis=\($0.isVisible)|titled=\($0.styleMask.contains(.titled))|parent=\($0.parent != nil)"
        }
        FileHandle.standardError.write(Data("all windows: \(all)\n".utf8))
        fail("no window to probe")
    }

    private func resize(_ window: NSWindow) async {
        guard let raw = Self.value(for: "--window-size") else { return }
        guard let size = ProbeStats.windowSize(raw) else {
            fail("--window-size wants WxH, as in 1440x900, and was given \(raw)")
        }
        window.setContentSize(size)
        window.layoutIfNeeded()
        try? await Task.sleep(for: .seconds(1))
    }

    private static weak var attached: AppModel?

    static func attach(_ model: AppModel) {
        attached = model
    }

    static var appModel: AppModel? { attached ?? AppModel.probeInstance }

    nonisolated static func post(_ type: CGEventType, at point: CGPoint, pid: pid_t) {
        guard let event = CGEvent(
            mouseEventSource: nil, mouseType: type, mouseCursorPosition: point, mouseButton: .left
        ) else { return }
        event.postToPid(pid)
    }

    func onEventThread(polling: Duration, _ work: @escaping @Sendable () -> Void) async {
        let done = Mutex(false)
        Thread.detachNewThread {
            work()
            done.withLock { $0 = true }
        }
        while !done.withLock({ $0 }) {
            await Task.yield()
            try? await Task.sleep(for: polling)
        }
    }

    static func transcriptScrollView(in root: NSView) -> NSScrollView? {
        var found: [NSScrollView] = []
        func walk(_ view: NSView) {
            if let scroll = view as? NSScrollView { found.append(scroll) }
            for subview in view.subviews { walk(subview) }
        }
        walk(root)
        return found.max { $0.endOffset < $1.endOffset }
    }

    static func scrollPlace(_ scroll: NSScrollView?) -> [String: JSONValue] {
        guard let scroll else { return ["found": .bool(false)] }
        let offset = Double(scroll.contentView.bounds.origin.y)
        let content = Double(scroll.documentView?.frame.height ?? 0)
        let viewport = Double(scroll.contentView.bounds.height)
        let reach = Double(scroll.distanceFromEnd)
        return [
            "found": .bool(true),
            "offset": .number(offset),
            "contentHeight": .number(content),
            "viewportHeight": .number(viewport),
            "reachToEnd": .number(reach),
            "atEnd": .bool(reach <= 4),
        ]
    }

    static func wheel(_ view: NSView, by points: CGFloat, steps: Int = 1) {
        for _ in 0..<max(1, steps) {
            guard let scroll = CGEvent(
                scrollWheelEvent2Source: nil,
                units: .pixel,
                wheelCount: 1,
                wheel1: Int32(points),
                wheel2: 0,
                wheel3: 0
            ), let event = NSEvent(cgEvent: scroll) else { return }
            view.scrollWheel(with: event)
        }
    }

    func conditions(window: NSWindow?) -> [String: JSONValue] {
        var conditions: [String: JSONValue] = [
            "configuration": .string(Self.buildConfiguration),
            "loadAverage": .number(Self.systemLoadAverage()),
        ]
        guard let window else { return conditions }
        conditions["windowSize"] = .object([
            "w": .number(window.frame.width), "h": .number(window.frame.height),
        ])
        conditions["displayHz"] = .number(Double(window.screen?.maximumFramesPerSecond ?? 60))
        return conditions
    }

    static func frameTimings(_ intervals: [Double]) -> [String: JSONValue] {
        let ms = intervals.sorted()
        let median = ProbeStats.percentile(0.5, of: ms)
        let dropped = ms.filter { $0 > (ms.isEmpty ? 8.3 : median) * 1.8 }.count
        return [
            "frames": .integer(ms.count),
            "medianMs": .number(median),
            "medianFps": .number(median > 0 ? 1000 / median : 0),
            "p95Ms": .number(ProbeStats.percentile(0.95, of: ms)),
            "p99Ms": .number(ProbeStats.percentile(0.99, of: ms)),
            "worstMs": .number(ms.last ?? 0),
            "droppedFrames": .integer(dropped),
            "droppedShare": .number(ms.isEmpty ? 0 : Double(dropped) / Double(ms.count)),
        ]
    }

    static var buildConfiguration: String {
        #if DEBUG
        "debug"
        #else
        "release"
        #endif
    }

    static func systemLoadAverage() -> Double {
        var loads = [Double](repeating: 0, count: 3)
        guard getloadavg(&loads, 3) > 0 else { return 0 }
        return loads[0]
    }

    static func mainThreadCPUSeconds() -> Double {
        Double(clock_gettime_nsec_np(CLOCK_THREAD_CPUTIME_ID)) / 1_000_000_000
    }

    func markStarted() {
        try? Data("\(ProcessInfo.processInfo.processIdentifier)".utf8)
            .write(to: URL(fileURLWithPath: outputPath + ".started"))
    }

    func write(_ report: JSONValue, echo: Bool = false) {
        guard let data = Self.encoded(report) else {
            fail("the report could not be encoded")
        }
        try? data.write(to: URL(fileURLWithPath: outputPath))
        if echo {
            FileHandle.standardError.write(data)
            FileHandle.standardError.write(Data("\n".utf8))
        }
        FileHandle.standardError.write(Data("\(name) wrote \(outputPath)\n".utf8))
    }

    func fail(_ message: String) -> Never {
        FileHandle.standardError.write(Data("\(name): \(message)\n".utf8))
        let report = JSONValue.object([
            "probe": .string(name),
            "error": .string(message),
            "configuration": .string(Self.buildConfiguration),
        ])
        if let data = Self.encoded(report) {
            try? data.write(to: URL(fileURLWithPath: outputPath))
        }
        exit(1)
    }

    private static func encoded(_ report: JSONValue) -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try? encoder.encode(report)
    }
}

extension JSONValue {
    static func numbers(_ values: [Double]) -> JSONValue {
        .array(values.map { .number($0) })
    }

    static func numbers(_ values: [CGFloat]) -> JSONValue {
        .array(values.map { .number(Double($0)) })
    }

    static func numbers(_ rows: [[Double]]) -> JSONValue {
        .array(rows.map { numbers($0) })
    }

    static func strings(_ values: [String]) -> JSONValue {
        .array(values.map { .string($0) })
    }

    static func map(_ values: [String: Double]) -> JSONValue {
        .object(values.mapValues { .number($0) })
    }

    static func map(_ values: [String: [String: Double]]) -> JSONValue {
        .object(values.mapValues { map($0) })
    }

    static func map(_ values: [String: [[Double]]]) -> JSONValue {
        .object(values.mapValues { numbers($0) })
    }
}
