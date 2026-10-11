import Foundation
import Core

extension AppModel {
    func startSpendIndexing() {
        guard let store else { return }
        spendIndexTask?.cancel()
        let indexer = spendIndexer ?? SpendIndexer(store: store)
        spendIndexer = indexer
        spendIndexTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.noteSpendRead()
                _ = try? await indexer.refresh()
                await self?.reloadSpend()
                try? await Task.sleep(for: .seconds(SpendPollSchedule.interval))
            }
        }
    }

    func refreshSpend(after gap: TimeInterval = SpendPollSchedule.onDemandFloor) {
        guard let indexer = spendIndexer,
              SpendPollSchedule.isDue(lastReadAt: lastSpendReadAt, at: Date(), after: gap)
        else { return }
        lastSpendReadAt = Date()
        Task { [weak self] in
            _ = try? await indexer.refresh()
            await self?.reloadSpend()
        }
    }

    func noteSpendRead() {
        lastSpendReadAt = Date()
    }

    func reloadSpend() async {
        guard let store else { return }
        let since = SpendSpan.month.start(from: Date(), calendar: .current)
        let loaded = (try? await store.spendDays(since: since)) ?? []
        if spendDays != loaded { spendDays = loaded }
        let census = (try? await store.setting(SpendCensus.settingKey))
            .flatMap { try? JSONDecoder().decode(SpendCensus.self, from: Data($0.utf8)) }
        if let census, spendCensus != census { spendCensus = census }
    }

    func spendBoard(span: SpendSpan, at now: Date = Date()) -> SpendBoard {
        SpendBoard.make(SpendBoard.Input(
            days: spendDays,
            workspaces: workspaces,
            repos: repos,
            census: spendCensus,
            installed: SpendProviders.onThisMac(
                accounts: accounts,
                quotas: quotas,
                unanswered: unansweredQuotaProviders,
                withoutLimits: quotalessProviders,
                census: spendCensus
            ),
            window: span,
            now: now,
            calendar: .current
        ))
    }
}
