import SwiftUI
import AppKit
import Core

struct TurnFooterView: View {
    var rows: [TranscriptRow]
    var row: TranscriptRow
    var worktree: String
    var permissionMode: PermissionMode = .acceptEdits
    var agentKind: AgentKind = .claudeCode
    var wasStopped = false
    var recovered: RetryRun?
    var stillRunning: String?
    var transcript: TranscriptModel?

    private static let visibleFileLimit = 6

    @State private var files: [TurnFile] = []
    @State private var snapshotFailure: String?
    @State private var historicalFile: TurnFile?

    private var checkpoint: TurnCheckpoint? {
        transcript?.history.checkpoints.first { $0.endSeq == row.seq && $0.after != nil }
    }

    var body: some View {
        let result = result
        let outcome = TurnEnding.of(
            wasStopped: wasStopped,
            succeeded: result?.succeeded != false,
            denials: result?.permissionDenials ?? 0
        )
        let answerText = TurnAnswer.text(
            summary: result?.summary ?? "",
            rows: rows.lazy.map {
                TurnAnswer.Row(
                    seq: $0.seq, kind: $0.kind, payload: $0.payload,
                    isNested: $0.parentToolUseID != nil
                )
            },
            endingAt: row.seq
        )

        return VStack(alignment: .leading, spacing: 0) {
            Rectangle()
                .fill(Palette.border)
                .frame(height: Metrics.outline)
                .padding(.horizontal, TranscriptLayout.inset)
                .padding(.top, TranscriptLayout.inset)
                .padding(.bottom, TranscriptLayout.tight)

            HStack(spacing: TranscriptLayout.block) {
                if outcome != .finished {
                    let appearance = Self.appearance(of: outcome)
                    Image(systemName: appearance.glyph)
                        .font(Typo.caption)
                        .imageScale(.medium)
                        .foregroundStyle(appearance.tint)
                        .accessibilityLabel(outcome.label)
                        .help(outcome.label)
                }

                Text(
                    Self.durationLabel(
                        outcome: outcome,
                        milliseconds: row.durationMS ?? result?.durationMS ?? 0
                    )
                )
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textSecondary)
                    .monospacedDigit()
                    .fixedSize()

                ViewThatFits(in: .horizontal) {
                    fileChips(limit: Self.visibleFileLimit)
                    fileChips(limit: files.count > 3 ? 3 : 1)
                    fileChips(limit: 1)
                    countChip
                    Color.clear.frame(width: 0, height: 0)
                }

                if let transcript { TurnHistoryActions(transcript: transcript, endingAt: row.seq) }
                CopyButton(text: answerText, title: "Copy this answer")
                    .disabled(answerText.isEmpty)
            }
            .foregroundStyle(Palette.textSecondary)
            .padding(.horizontal, TranscriptLayout.inset)
            .padding(.vertical, Metrics.spacingSmall)

            if let notice = outcome.note(permissionMode: permissionMode, agentKind: agentKind) {
                Text(notice)
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, TranscriptLayout.inset)
                    .padding(.bottom, TranscriptLayout.inset)
            }

            if outcome == .failed, let result, let failure = TurnFailure.of(result) {
                VStack(alignment: .leading, spacing: TranscriptLayout.tight) {
                    if let lead = failure.lead {
                        Text(lead)
                            .foregroundStyle(Palette.textSecondary)
                    }
                    if let words = failure.clisOwnWords {
                        Text("The agent said: \(words)")
                            .foregroundStyle(Palette.textTertiary)
                    }
                }
                .font(Typo.caption)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: TranscriptLayout.proseMeasure, alignment: .leading)
                .padding(.horizontal, TranscriptLayout.inset)
                .padding(.bottom, TranscriptLayout.inset)
            }

            if let snapshotFailure {
                Text("Saved file summary unavailable")
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textSecondary)
                    .help(snapshotFailure)
                    .padding(.horizontal, TranscriptLayout.inset)
                    .padding(.bottom, TranscriptLayout.inset)
            }

            if let stillRunning {
                Text(stillRunning)
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, TranscriptLayout.inset)
                    .padding(.bottom, TranscriptLayout.inset)
            }

            if let recovered {
                Text(recovered.recoveredSentence)
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, TranscriptLayout.inset)
                    .padding(.bottom, TranscriptLayout.inset)
            }
        }
        .task(id: "\(row.seq):\(checkpoint?.after?.id.rawValue ?? "legacy")") { await scanFiles() }
        .sheet(item: $historicalFile) { file in
            if let transcript, let checkpoint {
                TurnSnapshotView(transcript: transcript, checkpoint: checkpoint, initialPath: file.path)
            }
        }
    }

    private static func durationLabel(outcome: TurnEnding, milliseconds: Int) -> String {
        let duration = TurnDuration.wholeSeconds(milliseconds)
        return switch outcome {
        case .finished, .denied: "Completed in \(duration)"
        case .failed: "Failed after \(duration)"
        case .stopped: "Stopped after \(duration)"
        }
    }

    private var result: AgentResult? {
        guard case .result(let value)? = TranscriptEventCache.event(rowID: row.id, payload: row.payload) else {
            return nil
        }
        return value
    }

    private static func appearance(of outcome: TurnEnding) -> (glyph: String, tint: Color) {
        switch outcome {
        case .finished: ("checkmark.circle", Palette.positive)
        case .denied: ("hand.raised.circle", Palette.warning)
        case .failed: ("exclamationmark.circle", Palette.negative)
        case .stopped: ("stop.circle", Palette.textSecondary)
        }
    }

    private func scanFiles() async {
        snapshotFailure = nil
        if let transcript, let checkpoint, let snapshotID = checkpoint.after?.id {
            if let known = TurnScanCache.files(snapshotID: snapshotID) {
                files = known
                return
            }
            do {
                let changed = try await transcript.history.files(checkpoint, cwd: worktree)
                guard !Task.isCancelled else { return }
                files = changed.map { TurnFile(path: $0.path, additions: $0.additions, deletions: $0.deletions) }
                TurnScanCache.remember(files, snapshotID: snapshotID)
            } catch {
                guard !Task.isCancelled else { return }
                files = []
                snapshotFailure = "Could not load the saved file summary: \(error)"
            }
            return
        }
        if let known = TurnScanCache.files(rowID: row.id) {
            files = known
            return
        }
        let scanned = await Task.detached(priority: .utility) { [rows, seq = row.seq] in
            TurnScan.files(rows: rows, endingAt: seq)
        }.value
        guard !Task.isCancelled else { return }
        TurnScanCache.remember(scanned, rowID: row.id)
        files = scanned
    }

    @ViewBuilder
    private func fileChips(limit: Int) -> some View {
        HStack(spacing: TranscriptLayout.block) {
            ForEach(files.prefix(limit)) { file in
                if checkpoint != nil {
                    Button { historicalFile = file } label: {
                        TurnFileChip(file: file, worktree: worktree, previewsCurrentFile: false)
                    }
                    .buttonStyle(.plain)
                } else {
                    TurnFileChip(file: file, worktree: worktree)
                }
            }
            if files.count > limit {
                Chip(text: "+\(files.count - limit) more")
            }
        }
        .fixedSize()
    }

    @ViewBuilder
    private var countChip: some View {
        if !files.isEmpty {
            Chip(text: files.count == 1 ? "1 file" : "\(files.count) files")
                .fixedSize()
        }
    }
}
