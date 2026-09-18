import AppKit
import Core
import QuartzCore
import SwiftUI

struct TranscriptTableEntry: Identifiable {
    let id: TranscriptEntryID
    let contentKey: TranscriptContentKey
    var drawsNothing = false
    var shape: TranscriptRowShape = .other
    let content: @MainActor () -> AnyView
}

struct TranscriptTableGeometry: Equatable {
    var offset: CGFloat = 0
    var contentHeight: CGFloat = 0
    var viewportHeight: CGFloat = 0
    var viewportWidth: CGFloat = 0

    var isAtEnd: Bool {
        TranscriptAnchor.isAtEnd(
            offset: offset, contentHeight: contentHeight, viewportHeight: viewportHeight
        )
    }
}

@MainActor
final class TranscriptTableController {
    fileprivate weak var coordinator: TranscriptTable.Coordinator?

    var scrollView: NSScrollView? { coordinator?.scrollView }

    func goToEnd() { coordinator?.goToEnd() }

    func releaseEnd() { coordinator?.releaseEnd() }

    var holdsEnd: Bool { coordinator?.holdsEnd ?? false }

    func followerTookOver() -> Bool { coordinator?.followerTookOver() ?? false }

    func followerHandedBack() { coordinator?.followerHandedBack() }

    func scroll(to entryID: TranscriptEntryID, anchor: UnitPoint) {
        coordinator?.scroll(to: entryID, anchor: anchor)
    }

    func scroll(to entryID: TranscriptEntryID, delta: CGFloat) {
        coordinator?.scroll(to: entryID, delta: delta)
    }

    func scroll(toY y: CGFloat) { coordinator?.scroll(toY: y) }

    func willUnfold(_ entryID: TranscriptEntryID) { coordinator?.willUnfold(entryID) }

    func willChangeFoldRows(_ entryID: TranscriptEntryID) {
        coordinator?.willChangeFoldRows(entryID)
    }

    func arrived() { coordinator?.arrived() }

    var topmostPlace: (seq: Int, delta: CGFloat)? { coordinator?.topmostPlace }

    func isAboveViewport(_ entryID: TranscriptEntryID) -> Bool? {
        coordinator?.isAboveViewport(entryID)
    }

    var geometry: TranscriptTableGeometry {
        coordinator?.currentGeometry ?? TranscriptTableGeometry()
    }
}

final class TranscriptScrollView: NSScrollView {
    var willResizeViewport: (() -> Void)?
    var didResizeViewport: (() -> Void)?

    override func setFrameSize(_ newSize: NSSize) {
        let changed = newSize != frame.size
        if changed { willResizeViewport?() }
        super.setFrameSize(newSize)
        if changed { didResizeViewport?() }
    }

    override func wantsForwardedScrollEvents(for axis: NSEvent.GestureAxis) -> Bool {
        axis == .vertical
    }
}

struct TranscriptTable: NSViewRepresentable {
    let entries: [TranscriptTableEntry]
    let session: SessionID
    let controller: TranscriptTableController
    let scale: CGFloat
    let rowEnvironment: TranscriptRowEnvironment
    let onGeometryChange: @MainActor (TranscriptTableGeometry) -> Void
    let onSettled: @MainActor () -> Void
    let onLiveScrollChange: @MainActor (Bool) -> Void
    var topInset: CGFloat?

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> TranscriptHoldView {
        let table = TranscriptTableView()
        table.headerView = nil
        table.style = .plain
        table.rowSizeStyle = .custom
        table.usesAutomaticRowHeights = false
        table.usesAlternatingRowBackgroundColors = false
        table.selectionHighlightStyle = .none
        table.allowsEmptySelection = true
        table.allowsMultipleSelection = false
        table.gridStyleMask = []
        table.intercellSpacing = .zero
        table.backgroundColor = .clear
        table.columnAutoresizingStyle = .uniformColumnAutoresizingStyle

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("transcript"))
        column.resizingMask = .autoresizingMask
        table.addTableColumn(column)

        table.dataSource = context.coordinator
        table.delegate = context.coordinator

        let scroll = TranscriptScrollView()
        scroll.documentView = table
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = false
        scroll.drawsBackground = false
        scroll.backgroundColor = .clear
        scroll.automaticallyAdjustsContentInsets = topInset == nil

        context.coordinator.attach(table: table, scroll: scroll)
        controller.coordinator = context.coordinator

        let hold = TranscriptHoldView(scroll: scroll)
        hold.delegate = context.coordinator
        context.coordinator.holdView = hold
        return hold
    }

    func sizeThatFits(
        _ proposal: ProposedViewSize, nsView: TranscriptHoldView, context: Context
    ) -> CGSize? {
        CGSize(
            width: proposal.width ?? nsView.bounds.width,
            height: proposal.height ?? nsView.bounds.height
        )
    }

    func updateNSView(_ nsView: TranscriptHoldView, context: Context) {
        let coordinator = context.coordinator
        controller.coordinator = coordinator
        coordinator.onGeometry = onGeometryChange
        coordinator.onSettled = onSettled
        coordinator.onLiveScrollChange = onLiveScrollChange
        if let topInset, nsView.scroll.automaticallyAdjustsContentInsets || nsView.scroll.contentInsets.top != topInset {
            nsView.scroll.automaticallyAdjustsContentInsets = false
            nsView.scroll.contentInsets = NSEdgeInsets(top: topInset, left: 0, bottom: 0, right: 0)
        }
        coordinator.showing(session: session, in: nsView)
        coordinator.apply(entries: entries, scale: scale, environment: rowEnvironment)
    }

    @MainActor
    final class Coordinator:
        NSObject, NSTableViewDataSource, NSTableViewDelegate, TranscriptHoldDelegate {
        private(set) var entries: [TranscriptTableEntry] = []
        private var ids: [TranscriptEntryID] = []
        private var index: [TranscriptEntryID: Int] = [:]
        private var rowEnvironment: TranscriptRowEnvironment?
        var onGeometry: (@MainActor (TranscriptTableGeometry) -> Void)?
        var onSettled: (@MainActor () -> Void)?
        var onLiveScrollChange: (@MainActor (Bool) -> Void)?

        weak var tableView: NSTableView?
        weak var scrollView: NSScrollView?

        private var heights = TranscriptRowHeights()
        private var settleWork: Task<Void, Never>?
        private var warmWork: Task<Void, Never>?
        private var placeWork: Task<Void, Never>?
        private var resizeWork: Task<Void, Never>?
        private var viewportWork: Task<Void, Never>?
        private var viewportPlace: PlaceBeforeResize?
        private var endWork: Task<Void, Never>?
        private var reaimWork: Task<Void, Never>?
        private var owedHeights: Set<TranscriptEntryID> = []
        private var owedWork: Task<Void, Never>?

        fileprivate private(set) var holdsEnd = false
        private var isSettlingResizeAtEnd = false
        private var isPutting = false
        private var isLiveScrolling = false
        private var lastLiveScroll: CFTimeInterval = 0
        private var quietWork: Task<Void, Never>?
        private var isFollowerDriving = false
        private var pendingUnfolds: Set<TranscriptEntryID> = []
        private var pendingFoldRows = false
        private var pendingFoldAnchor: (id: TranscriptEntryID, delta: CGFloat)?

        private struct PlaceBeforeResize {
            var wasAtEnd: Bool
            var anchor: (id: TranscriptEntryID, delta: CGFloat)?
        }

        private var shownSession: SessionID?
        private var cellGeneration = 0
        weak var holdView: TranscriptHoldView?

        private var columnWidth: CGFloat {
            if let tableView, tableView.bounds.width > 1 { return tableView.bounds.width }
            return scrollView?.contentView.bounds.width ?? 0
        }

        func attach(table: NSTableView, scroll: NSScrollView) {
            tableView = table
            scrollView = scroll
            (table as? TranscriptTableView)?.didChangeWidth = { [weak self] in self?.widthChanged() }
            if let scroll = scroll as? TranscriptScrollView {
                scroll.willResizeViewport = { [weak self] in self?.viewportWillResize() }
                scroll.didResizeViewport = { [weak self] in self?.viewportDidResize() }
            }
            scroll.contentView.postsBoundsChangedNotifications = true
            scroll.postsFrameChangedNotifications = true
            let centre = NotificationCenter.default
            centre.addObserver(
                self, selector: #selector(clipMoved),
                name: NSView.boundsDidChangeNotification, object: scroll.contentView
            )
            centre.addObserver(
                self, selector: #selector(paneResized),
                name: NSView.frameDidChangeNotification, object: scroll
            )
            centre.addObserver(
                self, selector: #selector(liveScrollBegan),
                name: NSScrollView.willStartLiveScrollNotification, object: scroll
            )
            centre.addObserver(
                self, selector: #selector(liveScrolled),
                name: NSScrollView.didLiveScrollNotification, object: scroll
            )
            centre.addObserver(
                self, selector: #selector(liveScrollEnded),
                name: NSScrollView.didEndLiveScrollNotification, object: scroll
            )
        }

        deinit { NotificationCenter.default.removeObserver(self) }

        func apply(
            entries newEntries: [TranscriptTableEntry],
            scale: CGFloat,
            environment: TranscriptRowEnvironment
        ) {
            guard let tableView else { return }

            let previous = rowEnvironment
            rowEnvironment = environment
            let environmentMoved = previous != nil && previous != environment
            if environmentMoved { cellGeneration += 1 }
            let wrapsDifferently = previous?.wraps(differentlyFrom: environment) ?? false
            if wrapsDifferently { heights.forget() }

            let remeasured = heights.reset(
                width: heights.measure?.width ?? Double(columnWidth),
                scale: scale, leading: environment.lineHeight.ratio
            ) || wrapsDifferently

            let newIDs = newEntries.map(\.id)
            let change = TranscriptEntryChange.between(ids, newIDs)
            let changesFoldRows = pendingFoldRows && change.movesRows
            let foldAnchor = changesFoldRows ? pendingFoldAnchor : nil
            let fadesFoldRows = changesFoldRows
                && rowEnvironment?.reduceMotion != true
            if change.movesRows {
                pendingFoldRows = false
                pendingFoldAnchor = nil
            }

            var changed = IndexSet()
            var unfolding = IndexSet()
            func noteChange(old: Int, new: Int) {
                guard newEntries[new].contentKey != entries[old].contentKey else { return }
                changed.insert(new)
                if pendingUnfolds.contains(newEntries[new].id) { unfolding.insert(new) }
            }
            switch change {
            case .same:
                for offset in newEntries.indices { noteChange(old: offset, new: offset) }
            case .grew, .shrank:
                for offset in newEntries.indices {
                    guard let old = index[newEntries[offset].id] else { continue }
                    noteChange(old: old, new: offset)
                }
            case .rebuilt:
                break
            }
            pendingUnfolds.removeAll()

            if change == .same, changed.isEmpty, !remeasured, !environmentMoved {
                return
            }

            let wasAtEnd = changesFoldRows ? false : isFollowingAlong
            let anchor = foldAnchor ?? (change.movesRows ? anchorEntry() : nil)

            entries = newEntries
            ids = newIDs
            index = [:]
            for (offset, id) in newIDs.enumerated() { index[id] = offset }

            let plan = TranscriptTableUpdate.plan(change: change, environmentMoved: environmentMoved)
            switch plan {
            case .nothing:
                break
            case .rows(let rowChange):
                switch rowChange {
                case .grew(let head, let tail):
                    rowsArrived(head: head, tail: tail, fading: fadesFoldRows, in: tableView)
                case .shrank(let head, let tail):
                    rowsLeft(head: head, tail: tail, fading: fadesFoldRows, in: tableView)
                case .same, .rebuilt:
                    break
                }
            case .reload:
                tableView.reloadData()
            }

            if remeasured {
                measureExactly(visibleRows)
                noteHeights(IndexSet(integersIn: entries.indices))
            }
            if !remeasured, !changed.isEmpty {
                if plan != .reload {
                    tableView.reloadData(
                        forRowIndexes: changed, columnIndexes: IndexSet(integer: 0)
                    )
                }
                measureExactly(changed)
                noteHeights(changed.subtracting(unfolding))
                noteHeights(unfolding, over: unfoldSeconds)
            }

            keepPlace(wasAtEnd: wasAtEnd, anchor: anchor)
            Task { @MainActor [weak self] in self?.reportGeometry() }
        }

        func numberOfRows(in tableView: NSTableView) -> Int { entries.count }

        private static let hair: CGFloat = 0.01

        func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
            TranscriptHoldCensus.askedHeight()
            guard entries.indices.contains(row) else { return Self.hair }
            return max(Self.hair, height(of: entries[row]))
        }

        func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool { false }

        func tableView(
            _ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int
        ) -> NSView? {
            guard entries.indices.contains(row), let rowEnvironment else { return nil }
            let entry = entries[row]
            if !entry.id.redrawsItself, heights.measuredNothing(entry.contentKey) { return nil }
            let identifier = NSUserInterfaceItemIdentifier("unifieddev.transcript.cell")
            let cell = tableView.makeView(withIdentifier: identifier, owner: self)
                as? TranscriptTableCell ?? TranscriptTableCell(identifier: identifier)
            cell.setFrameSize(NSSize(width: columnWidth, height: max(Self.hair, height(of: entry))))
            cell.onMeasured = { [weak self] id, key, size in
                self?.noted(size: size, of: key, for: id)
            }
            let started = TranscriptHoldCensus.clock()
            let rebuilt = cell.apply(
                entry: entry, environment: rowEnvironment, generation: cellGeneration
            )
            TranscriptHoldCensus.askedCell(
                rebuilt: rebuilt, seconds: TranscriptHoldCensus.since(started)
            )
            return cell
        }

        private func height(of entry: TranscriptTableEntry) -> CGFloat {
            guard heights.isReady else { return Self.hair }
            return CGFloat(heights.assumed(
                for: entry.contentKey, shape: entry.shape, drawsNothing: entry.drawsNothing
            ))
        }

        private lazy var sizer = NSHostingController(rootView: AnyView(EmptyView()))

        private func measure(_ entry: TranscriptTableEntry, at width: CGFloat) -> CGFloat {
            guard let rowEnvironment else { return 0 }
            TranscriptHoldCensus.measured()
            sizer.rootView = AnyView(
                HostedRow(content: entry.content(), report: { _ in }, fills: false)
                    .id(entry.id)
                    .transcriptRowEnvironment(rowEnvironment)
            )
            let height = sizer.sizeThatFits(
                in: CGSize(width: width, height: .greatestFiniteMagnitude)
            ).height
            return height
        }

        private func noted(
            size: CGSize, of contentKey: TranscriptContentKey, for entryID: TranscriptEntryID
        ) {
            guard let row = index[entryID], entries.indices.contains(row),
                  entries[row].contentKey == contentKey else { return }
            let height = size.height
            if !TranscriptRowHeights.isEvidence(
                measuredAt: Double(size.width), forCacheAt: heights.measure?.width
            ) {
                TranscriptHoldCensus.reportedAtAnotherWidth(TranscriptHoldCensus.Mismatch(
                    row: row,
                    shape: String(describing: entries[row].shape),
                    reportedWidth: Double(size.width),
                    cacheWidth: heights.measure?.width ?? 0,
                    columnWidth: Double(columnWidth),
                    cellWidth: tableView?
                        .view(atColumn: 0, row: row, makeIfNecessary: false)
                        .map { Double($0.frame.width) } ?? -1,
                    reportedHeight: Double(height),
                    knownHeight: heights.height(for: contentKey) ?? -1
                ))
                return
            }
            if height == 0, !entries[row].drawsNothing, !entryID.redrawsItself {
                noteSilence(row: row, entry: entries[row], source: "drawn")
            }
            heights.note(
                height,
                for: contentKey,
                shape: entries[row].shape,
                measuredAt: Double(size.width)
            )
            let told = tableView?.rect(ofRow: row).height
            let drawn = max(Double(Self.hair), TranscriptRowHeights.rounded(Double(height)))
            if let told, TranscriptRowHeights.isSameHeight(Double(told), drawn) { return }
            owedHeights.insert(entryID)
            drainOwedHeights()
        }

        private func drainOwedHeights() {
            guard owedWork == nil, !owedHeights.isEmpty else { return }
            owedWork = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(16))
                guard !Task.isCancelled, let self else { return }
                owedWork = nil
                let owed = owedHeights
                owedHeights = []
                let rows = IndexSet(owed.compactMap(rowOf))
                guard !rows.isEmpty else { return }
                let wasAtEnd = isFollowingAlong
                let anchor = anchorEntry()
                noteHeights(rows)
                keepPlace(wasAtEnd: wasAtEnd, anchor: anchor)
                reportGeometry()
                await Task.yield()
                checkCorrected(owed)
            }
        }

        private func rowOf(_ entryID: TranscriptEntryID) -> Int? {
            guard let row = index[entryID], entries.indices.contains(row) else { return nil }
            return row
        }

        private func checkCorrected(_ owed: Set<TranscriptEntryID>) {
            guard let tableView else { return }
            var wrong = 0
            for id in owed where !owedHeights.contains(id) {
                guard let row = rowOf(id),
                      heights.height(for: entries[row].contentKey) != nil else { continue }
                let told = tableView.rect(ofRow: row).height
                let drawn = owedHeight(of: entries[row])
                guard !TranscriptRowHeights.isSameHeight(Double(told), drawn) else { continue }
                wrong += 1
                #if DEBUG
                FileHandle.standardError.write(Data(
                    "transcript: row \(row) drew at \(drawn), the table says \(told)\n".utf8
                ))
                #endif
            }
            TranscriptHoldCensus.corrected(rows: owed.count, uncorrected: wrong)
        }

        private func censusOfTheScreen(settled: Bool = false) {
            guard let tableView, heights.isReady else { return }
            var estimated = 0
            var wrong = 0
            for row in visibleRows where entries.indices.contains(row) {
                if isGuessed(entries[row]) { estimated += 1 }
                let told = Double(tableView.rect(ofRow: row).height)
                if !TranscriptRowHeights.isSameHeight(told, owedHeight(of: entries[row])) {
                    wrong += 1
                }
            }
            TranscriptHoldCensus.sawScreen(estimated: estimated, wrong: wrong, settled: settled)
            if settled, TranscriptRowHeights.needsRepair(guessed: estimated, wrong: wrong) {
                repairTheScreen()
            }
            #if DEBUG
            if settled, estimated > 0 {
                let named = visibleRows
                    .filter { entries.indices.contains($0) && isGuessed(entries[$0]) }
                    .map { entries[$0].id.description }
                FileHandle.standardError.write(Data(
                    "transcript: \(estimated) guessed rows on screen: \(named)\n".utf8
                ))
            }
            #endif
        }

        private func repairTheScreen() {
            let rows = IndexSet(visibleRows.filter { entries.indices.contains($0) })
            guard !rows.isEmpty else { return }
            let wasAtEnd = isFollowingAlong
            let anchor = anchorEntry()
            measureExactly(rows)
            noteHeights(rows)
            keepPlace(wasAtEnd: wasAtEnd, anchor: anchor)
            reportGeometry()
        }

        private func isGuessed(_ entry: TranscriptTableEntry) -> Bool {
            (heights.height(for: entry.contentKey) == nil || heights.isStale(entry.contentKey))
                && !entry.drawsNothing
        }

        private func owedHeight(of entry: TranscriptTableEntry) -> Double {
            max(
                Double(Self.hair),
                heights.assumed(
                    for: entry.contentKey, shape: entry.shape, drawsNothing: entry.drawsNothing
                )
            )
        }

        private func noteHeights(_ rows: IndexSet, over seconds: Double = 0) {
            guard let tableView, !rows.isEmpty else { return }
            (tableView as? TranscriptTableView)?.deferRowAlignment(for: seconds)
            if seconds > 0 {
                for row in rows {
                    let cell = tableView.view(atColumn: 0, row: row, makeIfNecessary: false)
                    (cell as? TranscriptTableCell)?.clips(whileGrowingFor: seconds)
                }
            }
            let started = TranscriptHoldCensus.clock()
            NSAnimationContext.beginGrouping()
            NSAnimationContext.current.duration = seconds
            if seconds > 0 {
                NSAnimationContext.current.timingFunction =
                    CAMediaTimingFunction(name: .easeOut)
            }
            tableView.noteHeightOfRows(withIndexesChanged: rows)
            NSAnimationContext.endGrouping()
            TranscriptHoldCensus.noted(
                rows: rows.count, seconds: TranscriptHoldCensus.since(started)
            )
        }

        func willUnfold(_ entryID: TranscriptEntryID) {
            pendingUnfolds.insert(entryID)
        }

        func willChangeFoldRows(_ entryID: TranscriptEntryID) {
            pendingFoldRows = true
            pendingFoldAnchor = anchorEntry(entryID)
            aimingElsewhere()
        }

        private var unfoldSeconds: Double {
            guard let rowEnvironment else { return 0 }
            return TranscriptMotion.disclosure(reduceMotion: rowEnvironment.reduceMotion) ?? 0
        }

        private func keepPlace(
            wasAtEnd: Bool, anchor: (id: TranscriptEntryID, delta: CGFloat)?
        ) {
            switch TranscriptAnchor.place(
                holdsEnd: holdsEnd,
                wasAtEnd: wasAtEnd,
                followerDriving: isFollowerDriving,
                hasAnchor: anchor != nil
            ) {
            case .end:
                putEnd()
            case .anchor:
                if let anchor { restore(anchor) }
            case .stay:
                break
            }
        }

        private var isFollowingAlong: Bool {
            let geometry = currentGeometry
            return ScrollEnd.isAtEnd(
                contentHeight: geometry.contentHeight,
                viewportHeight: geometry.viewportHeight,
                offset: geometry.offset
            )
        }

        var currentGeometry: TranscriptTableGeometry {
            guard let scrollView, let document = scrollView.documentView else {
                return TranscriptTableGeometry()
            }
            let clip = scrollView.contentView
            return TranscriptTableGeometry(
                offset: clip.bounds.origin.y,
                contentHeight: document.frame.height,
                viewportHeight: clip.bounds.height,
                viewportWidth: clip.bounds.width
            )
        }

        var topmostEntry: TranscriptEntryID? {
            guard let tableView, let scrollView else { return nil }
            let visible = scrollView.contentView.documentVisibleRect
            let range = tableView.rows(in: visible)
            guard range.length > 0, entries.indices.contains(range.location) else { return nil }
            return entries[range.location].id
        }

        var topmostPlace: (seq: Int, delta: CGFloat)? {
            guard let tableView, let scrollView else { return nil }
            let visible = scrollView.contentView.documentVisibleRect
            let range = tableView.rows(in: visible)
            guard range.length > 0 else { return nil }
            func place(_ row: Int) -> (seq: Int, delta: CGFloat)? {
                guard entries.indices.contains(row), let seq = entries[row].id.seq else { return nil }
                return (seq, CGFloat(TranscriptAnchor.delta(
                    rowTop: tableView.rect(ofRow: row).minY, viewportTop: visible.minY
                )))
            }
            for row in stride(from: range.location, through: 0, by: -1) {
                if let found = place(row) { return found }
            }
            for row in stride(from: range.location + 1, to: entries.count, by: 1) {
                if let found = place(row) { return found }
            }
            return nil
        }

        func isAboveViewport(_ entryID: TranscriptEntryID) -> Bool? {
            guard let tableView, let scrollView, let row = index[entryID] else { return nil }
            return tableView.rect(ofRow: row).maxY <= scrollView.contentView.bounds.minY
        }

        func goToEnd() {
            guard !isLiveScrolling else { return }
            putEnd()
            guard !isFollowerDriving else { return }
            holdsEnd = true
            endWork?.cancel()
            endWork = Task { @MainActor [weak self] in
                await Task.yield()
                guard !Task.isCancelled, let self, holdsEnd else { return }
                putEnd()
            }
        }

        func releaseEnd() {
            holdsEnd = false
            isSettlingResizeAtEnd = false
            endWork?.cancel()
            endWork = nil
        }

        func followerTookOver() -> Bool {
            let ownedEnd = holdsEnd || isFollowingAlong
            isFollowerDriving = true
            releaseEnd()
            return ownedEnd
        }

        func followerHandedBack() {
            isFollowerDriving = false
        }

        private func putEnd() {
            guard let scrollView else { return }
            for _ in 0..<2 { measureLanding(at: scrollView.endOffset) }
            put(scrollView.endOffset, in: scrollView)
        }

        func scroll(to entryID: TranscriptEntryID, anchor: UnitPoint) {
            aimingElsewhere()
            put(at: entryID, anchor: anchor)
            reaimWork?.cancel()
            reaimWork = Task { @MainActor [weak self] in
                await Task.yield()
                guard !Task.isCancelled, let self else { return }
                reaimWork = nil
                put(at: entryID, anchor: anchor)
            }
        }

        private func put(at entryID: TranscriptEntryID, anchor: UnitPoint) {
            guard let tableView, let scrollView, let row = index[entryID] else { return }
            func target() -> CGFloat {
                let rect = tableView.rect(ofRow: row)
                return TranscriptAnchor.offset(
                    rowTop: rect.minY,
                    rowHeight: rect.height,
                    viewportHeight: scrollView.contentView.bounds.height,
                    anchor: anchor.y
                )
            }
            measureLanding(at: target())
            put(target(), in: scrollView)
        }

        func scroll(to entryID: TranscriptEntryID, delta: CGFloat) {
            aimingElsewhere()
            put(at: entryID, delta: delta)
            reaimWork?.cancel()
            reaimWork = Task { @MainActor [weak self] in
                await Task.yield()
                guard !Task.isCancelled, let self else { return }
                reaimWork = nil
                put(at: entryID, delta: delta)
            }
        }

        private func put(at entryID: TranscriptEntryID, delta: CGFloat) {
            guard let tableView, let scrollView, let row = index[entryID] else { return }
            func target() -> CGFloat {
                CGFloat(TranscriptAnchor.offset(
                    rowTop: tableView.rect(ofRow: row).minY, delta: delta
                ))
            }
            measureLanding(at: target())
            put(target(), in: scrollView)
        }

        func scroll(toY y: CGFloat) {
            aimingElsewhere()
            guard let scrollView else { return }
            measureLanding(at: y)
            put(y, in: scrollView)
        }

        private func aimingElsewhere() {
            viewportWork?.cancel()
            viewportWork = nil
            viewportPlace = nil
            isFollowerDriving = false
            releaseEnd()
        }

        private func put(_ y: CGFloat, in scrollView: NSScrollView) {
            let clip = scrollView.contentView
            guard TranscriptAnchor.canPlace(viewportHeight: Double(clip.bounds.height)) else {
                return
            }
            let target = TranscriptAnchor.clamped(
                y,
                contentHeight: Double(scrollView.documentView?.frame.height ?? 0),
                viewportHeight: clip.bounds.height
            )
            guard abs(clip.bounds.origin.y - target) > 0.01 else { return }
            TranscriptHoldCensus.placed()
            isPutting = true
            clip.setBoundsOrigin(NSPoint(x: clip.bounds.origin.x, y: target))
            scrollView.reflectScrolledClipView(clip)
            isPutting = false
        }

        private func rowsArrived(
            head: Range<Int>, tail: Range<Int>, fading: Bool, in tableView: NSTableView
        ) {
            (tableView as? TranscriptTableView)?.deferRowAlignment(for: fading ? Motion.hoverSeconds : 0)
            NSAnimationContext.beginGrouping()
            NSAnimationContext.current.duration = fading ? Motion.hoverSeconds : 0
            tableView.beginUpdates()
            let animation: NSTableView.AnimationOptions = fading ? .effectFade : []
            if !head.isEmpty { tableView.insertRows(at: IndexSet(integersIn: head), withAnimation: animation) }
            if !tail.isEmpty { tableView.insertRows(at: IndexSet(integersIn: tail), withAnimation: animation) }
            tableView.endUpdates()
            NSAnimationContext.endGrouping()
        }

        private func rowsLeft(
            head: Range<Int>, tail: Range<Int>, fading: Bool, in tableView: NSTableView
        ) {
            (tableView as? TranscriptTableView)?.deferRowAlignment(for: fading ? Motion.hoverSeconds : 0)
            NSAnimationContext.beginGrouping()
            NSAnimationContext.current.duration = fading ? Motion.hoverSeconds : 0
            tableView.beginUpdates()
            let animation: NSTableView.AnimationOptions = fading ? .effectFade : []
            if !tail.isEmpty { tableView.removeRows(at: IndexSet(integersIn: tail), withAnimation: animation) }
            if !head.isEmpty { tableView.removeRows(at: IndexSet(integersIn: head), withAnimation: animation) }
            tableView.endUpdates()
            NSAnimationContext.endGrouping()
        }

        private func anchorEntry() -> (id: TranscriptEntryID, delta: CGFloat)? {
            guard let tableView, let scrollView, let id = topmostEntry,
                  let row = index[id] else { return nil }
            let visible = scrollView.contentView.documentVisibleRect
            return (
                id,
                CGFloat(TranscriptAnchor.delta(
                    rowTop: tableView.rect(ofRow: row).minY, viewportTop: visible.minY
                ))
            )
        }

        private func anchorEntry(
            _ entryID: TranscriptEntryID
        ) -> (id: TranscriptEntryID, delta: CGFloat)? {
            guard let tableView, let scrollView, let row = index[entryID] else { return nil }
            return (
                entryID,
                CGFloat(TranscriptAnchor.delta(
                    rowTop: tableView.rect(ofRow: row).minY,
                    viewportTop: scrollView.contentView.bounds.origin.y
                ))
            )
        }

        private func restore(_ anchor: (id: TranscriptEntryID, delta: CGFloat)) {
            guard let tableView, let scrollView, let row = index[anchor.id] else { return }
            put(
                TranscriptAnchor.offset(
                    rowTop: tableView.rect(ofRow: row).minY, delta: anchor.delta
                ),
                in: scrollView
            )
        }

        @objc private func clipMoved() {
            if holdsEnd, !isPutting, viewportPlace == nil,
               !isSettlingResizeAtEnd, !currentGeometry.isAtEnd {
                releaseEnd()
            }
            warmWork?.cancel()
            warmWork = nil
            reportGeometry()
            scheduleSettle()
        }

        @objc private func liveScrollBegan() {
            guard !isLiveScrolling else { return }
            isLiveScrolling = true
            aimingElsewhere()
            reaimWork?.cancel()
            onLiveScrollChange?(true)
        }

        @objc private func liveScrolled() {
            lastLiveScroll = CACurrentMediaTime()
            guard !isLiveScrolling else { return }
            liveScrollBegan()
            watchForQuiet()
        }

        private static let quietSeconds: Double = 0.2

        private func watchForQuiet() {
            quietWork?.cancel()
            quietWork = Task { @MainActor [weak self] in
                while true {
                    try? await Task.sleep(for: .seconds(Self.quietSeconds))
                    guard !Task.isCancelled, let self, isLiveScrolling else { return }
                    guard CACurrentMediaTime() - lastLiveScroll >= Self.quietSeconds else { continue }
                    quietWork = nil
                    return liveScrollEnded()
                }
            }
        }

        @objc private func liveScrollEnded() {
            quietWork?.cancel()
            quietWork = nil
            guard isLiveScrolling else { return }
            isLiveScrolling = false
            onLiveScrollChange?(false)
            drainOwedHeights()
            scheduleSettle()
        }

        private func scheduleSettle() {
            settleWork?.cancel()
            settleWork = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(150))
                guard !Task.isCancelled, let self, !isLiveScrolling else { return }
                settleWork = nil
                if isSettlingResizeAtEnd {
                    putEnd()
                    reportGeometry()
                    isSettlingResizeAtEnd = false
                }
                (tableView as? TranscriptTableView)?.alignRowOrigins()
                censusOfTheScreen(settled: true)
                if let scrollView, let holdView {
                    TranscriptStateDump.tripIfBlank(TranscriptStateDump.Pane(
                        scroll: scrollView,
                        hold: holdView,
                        table: tableView,
                        coordinator: self
                    ))
                }
                onSettled?()
                warmAhead()
            }
        }

        private func warmAhead() {
            warmWork?.cancel()
            warmWork = Task { @MainActor [weak self] in
                await self?.warmTheRowsAbove()
            }
        }

        private func warmTheRowsAbove() async {
            guard let tableView, let scrollView, heights.isReady,
                  let sizing = heights.measure else { return }
            let visible = scrollView.contentView.documentVisibleRect
            let reach = TranscriptWarming.reach(viewport: Double(visible.height))
            let top = max(0, visible.minY - reach)
            let band = CGRect(x: 0, y: top, width: 1, height: visible.minY - top)
            guard band.height > 1 else { return }
            let found = tableView.rows(in: band)
            guard found.length > 0 else { return }
            let rows = TranscriptWarming.worthWarming(
                found.location..<(found.location + found.length)
            )
            var moved = IndexSet()
            for row in rows.reversed() where entries.indices.contains(row) {
                guard !Task.isCancelled, !isLiveScrolling else { break }
                let entry = entries[row]
                guard !entry.id.redrawsItself else { continue }
                let key = entry.contentKey
                guard heights.height(for: key) == nil || heights.isStale(key) else { continue }
                let taken = heights.note(
                    measure(entry, at: CGFloat(sizing.width)),
                    for: key,
                    shape: entry.shape,
                    measuredAt: sizing.width
                )
                if taken { moved.insert(row) }
                await Task.yield()
            }
            guard !moved.isEmpty else { return }
            if Task.isCancelled || isLiveScrolling {
                for row in moved where entries.indices.contains(row) {
                    owedHeights.insert(entries[row].id)
                }
                drainOwedHeights()
                return
            }
            let wasAtEnd = isFollowingAlong
            let anchor = anchorEntry()
            noteHeights(moved)
            keepPlace(wasAtEnd: wasAtEnd, anchor: anchor)
            reportGeometry()
        }

        @objc private func paneResized() {
            guard let sizing = heights.measure,
                  !TranscriptRowHeights.isSameWidth(Double(columnWidth), sizing.width) else {
                reportGeometry()
                return
            }
            settleWidth()
            reportGeometry()
        }

        private func widthChanged() {
            guard let sizing = heights.measure,
                  !TranscriptRowHeights.isSameWidth(Double(columnWidth), sizing.width) else { return }
            guard TranscriptPaneHold.reflowsNow(from: sizing.width, to: Double(columnWidth)) else {
                settleWidth()
                return
            }
            let place = viewportPlace
            viewportWork?.cancel()
            viewportWork = nil
            viewportPlace = nil
            warmWork?.cancel()
            warmWork = nil
            rewidth(keeping: place, withMargin: false)
            settleWidth()
        }

        private func settleWidth() {
            resizeWork?.cancel()
            resizeWork = Task { @MainActor [weak self] in
                try? await Task.sleep(for: TranscriptPaneHold.settle)
                guard !Task.isCancelled, let self else { return }
                resizeWork = nil
                if !rewidth(keeping: nil, withMargin: true) { measureMargin() }
            }
        }

        private func measureMargin() {
            guard heights.isReady, !isLiveScrolling else { return }
            let rows = TranscriptPaneHold.eager(visible: visibleRows, count: entries.count)
            let wasAtEnd = isFollowingAlong
            let anchor = anchorEntry()
            measureExactly(rows)
            let moved = heightUpdates(in: rows)
            guard !moved.isEmpty else { return }
            noteHeights(moved)
            keepPlace(wasAtEnd: wasAtEnd, anchor: anchor)
            reportGeometry()
        }

        private func viewportWillResize() {
            guard !isLiveScrolling, viewportPlace == nil, heights.isReady else { return }
            viewportPlace = PlaceBeforeResize(
                wasAtEnd: holdsEnd || isFollowingAlong, anchor: anchorEntry()
            )
        }

        private func viewportDidResize() {
            guard viewportPlace != nil else { return }
            viewportWork?.cancel()
            viewportWork = Task { @MainActor [weak self] in
                guard !Task.isCancelled, let self, !isLiveScrolling,
                      let place = viewportPlace,
                      TranscriptAnchor.canPlace(viewportHeight: Double(currentGeometry.viewportHeight))
                else { return }
                viewportWork = nil
                keepPlace(wasAtEnd: place.wasAtEnd, anchor: place.anchor)
                (tableView as? TranscriptTableView)?.alignRowOrigins()
                viewportPlace = nil
                reportGeometry()
                scheduleSettle()
            }
        }

        func holdEnded() {
            rewidth(keeping: nil, withMargin: true)
        }

        var reducesMotion: Bool { rowEnvironment?.reduceMotion ?? false }

        func showing(session: SessionID, in view: TranscriptHoldView) {
            holdView = view
            guard shownSession != session else { return }
            shownSession = session
            viewportWork?.cancel()
            viewportWork = nil
            viewportPlace = nil
            cellGeneration += 1
            heights.showing(session)
            view.hold()
        }

        func arrived() { holdView?.ready() }

        @discardableResult
        private func rewidth(keeping place: PlaceBeforeResize?, withMargin: Bool) -> Bool {
            guard heights.rewidth(to: Double(columnWidth)) else { return false }
            let wasAtEnd: Bool
            let anchor: (id: TranscriptEntryID, delta: CGFloat)?
            if let place {
                wasAtEnd = place.wasAtEnd
                anchor = place.anchor
            } else {
                wasAtEnd = isFollowingAlong
                anchor = anchorEntry()
            }
            reportGeometry()
            let measured = withMargin
                ? TranscriptPaneHold.eager(visible: visibleRows, count: entries.count)
                : visibleRows
            measureExactly(measured)
            noteHeights(heightUpdates(in: measured))
            if wasAtEnd, !isFollowerDriving, !isLiveScrolling {
                holdsEnd = true
                isSettlingResizeAtEnd = true
                scheduleSettle()
            }
            keepPlace(wasAtEnd: wasAtEnd, anchor: anchor)
            reportGeometry()
            placeWork?.cancel()
            placeWork = Task { @MainActor [weak self] in
                await Task.yield()
                guard !Task.isCancelled, let self, !isLiveScrolling else { return }
                placeWork = nil
                keepPlace(wasAtEnd: wasAtEnd, anchor: anchor)
                reportGeometry()
            }
            TranscriptHoldCensus.released(estimated: heights.staleCount)
            return true
        }

        @discardableResult
        private func measureExactly(_ rows: some Sequence<Int>) -> IndexSet {
            guard let sizing = heights.measure else { return IndexSet() }
            var moved = IndexSet()
            for row in rows where entries.indices.contains(row) {
                let entry = entries[row]
                guard heights.needsMeasuring(
                    entry.contentKey, redrawsItself: entry.id.redrawsItself
                ) else { continue }
                let height = measure(entry, at: CGFloat(sizing.width))
                if height == 0, !entry.drawsNothing, !entry.id.redrawsItself {
                    noteSilence(row: row, entry: entry, source: "measureExactly")
                }
                let taken = heights.note(
                    height, for: entry.contentKey, shape: entry.shape, measuredAt: sizing.width
                )
                if taken { moved.insert(row) }
            }
            return moved
        }

        private func measureLanding(at y: CGFloat) {
            guard let tableView, let scrollView, heights.isReady else { return }
            let viewport = scrollView.contentView.bounds.height
            guard viewport > 1 else { return }
            let rect = CGRect(x: 0, y: max(0, y - viewport), width: 1, height: viewport * 3)
            let range = tableView.rows(in: rect)
            guard range.length > 0 else { return }
            let rows = range.location..<(range.location + range.length)
            measureExactly(rows)
            noteHeights(heightUpdates(in: rows))
        }

        private func heightUpdates(in rows: some Sequence<Int>) -> IndexSet {
            guard let tableView else { return IndexSet() }
            return IndexSet(rows.filter { row in
                entries.indices.contains(row) && !TranscriptRowHeights.isSameHeight(
                    Double(tableView.rect(ofRow: row).height), owedHeight(of: entries[row])
                )
            })
        }

        private var visibleRows: Range<Int> {
            guard let tableView, let scrollView else { return 0..<0 }
            let range = tableView.rows(in: scrollView.contentView.documentVisibleRect)
            guard range.length > 0 else { return 0..<0 }
            return range.location..<(range.location + range.length)
        }

        private func reportGeometry() {
            onGeometry?(currentGeometry)
        }

        private func noteSilence(row: Int, entry: TranscriptTableEntry, source: String) {
            let clip = scrollView?.contentView
            TranscriptHoldCensus.silenced(TranscriptHoldCensus.Silence(
                row: row,
                source: source,
                shape: String(describing: entry.shape),
                columnWidth: Double(columnWidth),
                viewportWidth: Double(clip?.bounds.width ?? 0),
                viewportHeight: Double(clip?.bounds.height ?? 0)
            ))
        }

        func rowFacts(for rows: some Sequence<Int>) -> [RowFact] {
            rows.compactMap { row in
                guard entries.indices.contains(row) else { return nil }
                let entry = entries[row]
                let cell = tableView?.view(atColumn: 0, row: row, makeIfNecessary: false)
                let drawn = cell.map { $0.convert($0.bounds, to: tableView) }
                return RowFact(
                    row: row,
                    name: String(describing: entry.id),
                    shape: String(describing: entry.shape),
                    drawsNothing: entry.drawsNothing,
                    known: heights.height(for: entry.contentKey),
                    assumed: heights.assumed(
                        for: entry.contentKey, shape: entry.shape, drawsNothing: entry.drawsNothing
                    ),
                    measuredNothing: heights.measuredNothing(entry.contentKey),
                    needsMeasuring: heights.needsMeasuring(
                        entry.contentKey, redrawsItself: entry.id.redrawsItself
                    ),
                    told: Double(tableView?.rect(ofRow: row).height ?? 0),
                    top: Double(tableView?.rect(ofRow: row).minY ?? 0),
                    drawnTop: drawn.map { Double($0.minY) },
                    drawnHeight: drawn.map { Double($0.height) },
                    hasCell: cell != nil,
                    redrawsItself: entry.id.redrawsItself
                )
            }
        }

        var heightCacheCount: Int { heights.count }
        var heightCacheWidth: Double { heights.measure?.width ?? 0 }
        var heightCacheIsReady: Bool { heights.isReady }

        var visibleRowRange: Range<Int> { visibleRows }

        struct RowFact: Sendable {
            var row: Int
            var name: String
            var shape: String
            var drawsNothing: Bool
            var known: Double?
            var assumed: Double
            var measuredNothing: Bool
            var needsMeasuring: Bool
            var told: Double
            var top: Double
            var drawnTop: Double?
            var drawnHeight: Double?
            var hasCell: Bool
            var redrawsItself: Bool
        }
    }
}

private struct HostedRow: View {
    let content: AnyView
    let report: @MainActor (CGSize) -> Void
    var fills = true

    var body: some View {
        let measured = VStack(alignment: .leading, spacing: 0) { content }
            .frame(maxWidth: TranscriptLayout.conversationMeasure, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
            .fixedSize(horizontal: false, vertical: true)
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .onChange(of: proxy.size, initial: true) { _, _ in
                            report(proxy.size)
                        }
                }
            )
        return Group {
            if fills {
                measured.frame(
                    maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .topLeading
                )
            } else {
                measured
            }
        }
        .transaction { $0.animation = nil }
    }
}

private struct TranscriptCellRoot: View {
    var content: AnyView?
    var id: TranscriptEntryID?
    var environment: TranscriptRowEnvironment?
    var report: (@MainActor (CGSize) -> Void)?

    var body: some View {
        if let content, let id, let environment {
            HostedRow(content: content, report: { size in report?(size) })
                .id(id)
                .transcriptRowEnvironment(environment)
        }
    }
}

final class TranscriptTableCell: NSView {
    private let host: NSHostingView<TranscriptCellRoot>
    private var appliedKey: TranscriptContentKey?
    private var appliedGeneration: Int?
    private var unclip: Task<Void, Never>?
    var onMeasured: (@MainActor (TranscriptEntryID, TranscriptContentKey, CGSize) -> Void)?

    init(identifier: NSUserInterfaceItemIdentifier) {
        host = NSHostingView(rootView: TranscriptCellRoot())
        super.init(frame: .zero)
        self.identifier = identifier
        host.safeAreaRegions = []
        host.sizingOptions = []
        host.translatesAutoresizingMaskIntoConstraints = false
        addSubview(host)
        NSLayoutConstraint.activate([
            host.leadingAnchor.constraint(equalTo: leadingAnchor),
            host.trailingAnchor.constraint(equalTo: trailingAnchor),
            host.topAnchor.constraint(equalTo: topAnchor),
            host.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not in a nib") }

    @discardableResult
    func apply(
        entry: TranscriptTableEntry, environment: TranscriptRowEnvironment, generation: Int
    ) -> Bool {
        guard appliedKey != entry.contentKey || appliedGeneration != generation else { return false }
        appliedKey = entry.contentKey
        appliedGeneration = generation
        let id = entry.id
        let key = entry.contentKey
        host.rootView = TranscriptCellRoot(
            content: entry.content(),
            id: id,
            environment: environment,
            report: { [weak self] size in self?.onMeasured?(id, key, size) }
        )
        return true
    }

    func clips(whileGrowingFor seconds: Double) {
        unclip?.cancel()
        clipsToBounds = true
        unclip = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            self?.clipsToBounds = false
            self?.unclip = nil
        }
    }
}
