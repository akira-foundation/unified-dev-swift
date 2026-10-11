import SwiftUI
import Core

struct SpendScreenView: View {
    @Environment(AppModel.self) private var app

    @State private var span = SpendSpan.week

    var body: some View {
        SpendScreenBody(board: app.spendBoard(span: span), span: $span)
            .task { app.refreshSpend() }
    }
}

struct SpendScreenBody: View {
    let board: SpendBoard
    @Binding var span: SpendSpan

    var body: some View {
        Form {
            Section {
                LabeledContent(SpendLines.apiRates) {
                    Text(SpendLines.cost(board.total))
                        .font(Typo.display)
                        .monospacedDigit()
                }
                SpendChart(board: board)
            } footer: {
                Text(dearestLine).settingsFootnote()
            }
            Section {
                SpendColumnsTable(board: board)
            } header: {
                Text(SpendLines.whereItWent)
            } footer: {
                Text(SpendLines.savedLine(board.total.cost)).settingsFootnote()
            }
            Section {
                ForEach(board.providers) { provider in
                    LabeledContent {
                        Text(provider.spend.isEmpty ? "" : SpendLines.cost(provider.spend))
                            .monospacedDigit()
                    } label: {
                        Label(provider.kind.label, systemImage: "circle.fill")
                            .labelStyle(SpendDotLabelStyle(
                                ink: Color(hexString: ProviderAccent.hex(for: provider.kind))
                            ))
                        Text(SpendLines.providerCaption(provider))
                    }
                }
            } header: {
                Text(SpendLines.byProvider)
            } footer: {
                Text(SpendFormat.pricedOn(board.pricedOn)).settingsFootnote()
            }
            Section(SpendLines.byProject) {
                SpendProjectsList(projects: board.projects)
            }
        }
        .settingsForm()
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("", selection: $span) {
                    ForEach(SpendSpan.allCases) { choice in
                        Text(choice.label).tag(choice)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
            }
        }
        .frame(minWidth: 520, minHeight: 420)
    }

    private var dearestLine: String {
        board.dearestDay.map(SpendLines.dearestDay) ?? SpendBoard.emptyLine
    }
}

struct SpendDotLabelStyle: LabelStyle {
    let ink: Color

    func makeBody(configuration: Configuration) -> some View {
        Label {
            configuration.title
        } icon: {
            configuration.icon
                .foregroundStyle(ink)
                .font(.system(size: 8))
        }
    }
}
