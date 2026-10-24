import Testing
import Foundation
@testable import Core

@Suite("Capture stage")
struct CaptureStageTests {
    @Test func stagesNothingWhenNoneIsAskedFor() {
        #expect(CaptureStage.reading(nil, asked: false) == .stage(.window))
    }

    @Test func refusesTheFlagWithNothingAfterIt() {
        guard case .refused(let why) = CaptureStage.reading(nil, asked: true) else {
            Issue.record("--stage with no name has to be refused")
            return
        }
        #expect(why.contains("--stage needs a name"))
    }

    @Test func readsTheNamesTheCommandLineUses() {
        #expect(CaptureStage.reading("window") == .stage(.window))
        #expect(CaptureStage.reading("create-workspace") == .stage(.createWorkspace))
        #expect(CaptureStage.reading("review") == .stage(.review))
        #expect(CaptureStage.reading("agent-choice") == .stage(.agentChoice))
        #expect(CaptureStage.reading("terminal") == .stage(.terminal))
        #expect(CaptureStage.reading("browser") == .stage(.browser))
        #expect(CaptureStage.reading("spend") == .stage(.spend))
    }

    @Test func spellsTheTwoWordNamesWithAHyphen() {
        #expect(CaptureStage.createWorkspace.rawValue == "create-workspace")
        #expect(CaptureStage.agentChoice.rawValue == "agent-choice")
        for spelling in ["createWorkspace", "agentChoice"] {
            guard case .refused = CaptureStage.reading(spelling) else {
                Issue.record("\(spelling) is not a name the command line takes")
                return
            }
        }
    }

    @Test func ignoresTheSpaceAroundAName() {
        #expect(CaptureStage.reading("  review  ") == .stage(.review))
    }

    @Test func refusesANameItDoesNotStage() {
        guard case .refused(let why) = CaptureStage.reading("inspector") else {
            Issue.record("an unknown stage has to be refused")
            return
        }
        #expect(why.contains("'inspector'"))
        #expect(why.contains("has no capture stage"))
        for stage in CaptureStage.allCases {
            #expect(why.contains("'\(stage.rawValue)'"), "\(stage.rawValue) is not listed")
        }
    }

    @Test func refusesAnEmptyName() {
        guard case .refused(let why) = CaptureStage.reading("   ") else {
            Issue.record("an empty stage name has to be refused")
            return
        }
        #expect(why.contains("--stage needs a name"))
    }

    private static let popovers: Set<CaptureStage> = [.createWorkspace, .agentChoice]

    private static let ownWindows: Set<CaptureStage> = [.spend]

    private static let workspaces: Set<CaptureStage> = [.review, .agentChoice, .terminal, .browser]

    private static let parkable: Set<CaptureStage> = [.window, .review, .terminal, .browser, .spend]

    private static let arranged: Set<CaptureStage> = [
        .createWorkspace, .review, .agentChoice, .terminal, .browser,
    ]

    @Test func answersEveryStageAboutWhatItOpens() {
        for stage in CaptureStage.allCases {
            #expect(stage.opensAPopover == Self.popovers.contains(stage), "\(stage.rawValue)")
            #expect(stage.opensItsOwnWindow == Self.ownWindows.contains(stage), "\(stage.rawValue)")
        }
    }

    @Test func answersEveryStageAboutTheWorkspaceItArranges() {
        for stage in CaptureStage.allCases {
            #expect(
                stage.arrangesTheWorkspace == Self.workspaces.contains(stage), "\(stage.rawValue)"
            )
        }
    }

    @Test func answersEveryStageAboutBeingParkedOffTheScreen() {
        for stage in CaptureStage.allCases {
            #expect(stage.canBeParkedOffscreen == Self.parkable.contains(stage), "\(stage.rawValue)")
        }
    }

    @Test func answersEveryStageAboutBeingArrangedInTheWindow() {
        for stage in CaptureStage.allCases {
            #expect(
                stage.isArrangedInTheWindow == Self.arranged.contains(stage), "\(stage.rawValue)"
            )
        }
    }

    @Test func letsOnlyAPreviewArrangeItself() {
        #expect(CaptureStage.window.refusal(inAPreview: false) == nil)
        #expect(CaptureStage.window.refusal(inAPreview: true) == nil)
        for stage in CaptureStage.allCases where stage != .window {
            #expect(stage.refusal(inAPreview: true) == nil, "\(stage.rawValue)")
            guard let why = stage.refusal(inAPreview: false) else {
                Issue.record("\(stage.rawValue) has to be refused outside a preview")
                return
            }
            #expect(why.contains("--stage \(stage.rawValue)"))
            #expect(why.contains("preview"))
        }
    }
}
