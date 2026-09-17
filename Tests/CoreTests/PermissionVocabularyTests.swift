import Testing
import Foundation
@testable import Core

@Suite("The permission menu, in each backend's own words")
struct PermissionVocabularyTests {
    @Test("a Codex chat's menu reads the way the Codex app reads")
    func codexUsesCodexsWords() {
        #expect(PermissionMode.auto.label(on: .codex) == "Read only")
        #expect(PermissionMode.acceptEdits.label(on: .codex) == "Ask for approval")
        #expect(PermissionMode.autoReview.label(on: .codex) == "Approve for me")
        #expect(PermissionMode.bypassPermissions.label(on: .codex) == "Full access")

        #expect(
            PermissionMode.autoReview.summary(on: .codex)
                == "Only ask for actions detected as potentially unsafe."
        )
    }

    @Test("a Claude Code chat's menu reads the way Claude Code reads")
    func claudeCodeUsesItsOwnWords() {
        #expect(PermissionMode.auto.label(on: .claudeCode) == "Auto")
        #expect(PermissionMode.acceptEdits.label(on: .claudeCode) == "Accept edits")
        #expect(PermissionMode.plan.label(on: .claudeCode) == "Plan")
        #expect(PermissionMode.bypassPermissions.label(on: .claudeCode) == "Bypass permissions")
    }

    @Test("with no backend said the words are Claude Code's, because that is what a chat starts as")
    func theBareLabelIsClaudeCodes() {
        for mode in PermissionMode.allCases {
            #expect(mode.label == mode.label(on: .claudeCode))
        }
    }

    @Test("every mode has a sentence on every backend, because every row prints one")
    func nothingIsSilent() {
        for mode in PermissionMode.allCases {
            for kind in AgentKind.allCases {
                #expect(!mode.label(on: kind).isEmpty)
                #expect(!mode.summary(on: kind).isEmpty)
            }
        }
    }

    @Test("each backend offers only the modes it has")
    func eachBackendOffersWhatItHas() {
        let codex = ComposerControls(agentKind: .codex).availablePermissionModes
        #expect(codex.contains(.autoReview))
        #expect(!codex.contains(.plan))

        let claude = ComposerControls(agentKind: .claudeCode).availablePermissionModes
        #expect(claude.contains(.plan))
        #expect(!claude.contains(.autoReview))
        #expect(PermissionMode.autoReview.cliValue == PermissionMode.auto.cliValue)

        let grok = ComposerControls(agentKind: .grok).availablePermissionModes
        #expect(grok.contains(.plan))
        #expect(!grok.contains(.autoReview))
        #expect(PermissionMode.bypassPermissions.label(on: .grok) == "Always approve")
    }

    @Test("a mode the new backend has no row for lands somewhere that mode still means something")
    func aModeThatMovesBackendLandsSomewhere() {
        #expect(PermissionMode.autoReview.nearest(on: .claudeCode) == .auto)
        #expect(PermissionMode.plan.nearest(on: .codex) == .auto)
        for mode in PermissionMode.allCases {
            for kind in AgentKind.allCases {
                let landed = mode.nearest(on: kind)
                #expect(ComposerControls(agentKind: kind).availablePermissionModes.contains(landed))
            }
        }
    }

    @Test("every row carries its own sentence, in the backend's vocabulary")
    func everyRowSaysWhatItDoes() {
        let codex = ComposerControls(agentKind: .codex).permissionModeChoices
        #expect(codex.map(\.mode) == ComposerControls(agentKind: .codex).availablePermissionModes)
        #expect(codex.contains { $0.label == "Approve for me" })
        #expect(codex.contains { $0.summary.contains("potentially unsafe") })
        for choice in codex {
            #expect(!choice.label.isEmpty)
            #expect(!choice.summary.isEmpty)
        }

        let claude = ComposerControls(agentKind: .claudeCode).permissionModeChoices
        #expect(claude.contains { $0.mode == .plan && $0.label == "Plan" })
        #expect(claude.contains { $0.mode == .plan && $0.summary.contains("without making them") })
    }

    @Test("the footnote is left with the one fact no row can carry")
    func theFootnoteIsOnlyAboutTheConversation() {
        let codex = ComposerControls(agentKind: .codex, permissionMode: .autoReview)
        #expect(codex.permissionModeNote == nil)

        let claude = ComposerControls(agentKind: .claudeCode, permissionMode: .plan)
        #expect(claude.permissionModeNote == nil)
    }

    @Test("a mode a backend does not have can never be the selected one for that backend")
    func anAbsentModeIsNeverSelected() {
        for kind in AgentKind.allCases {
            for mode in PermissionMode.allCases {
                let made = ComposerControls(agentKind: kind, permissionMode: mode)
                #expect(made.availablePermissionModes.contains(made.permissionMode))

                var moved = ComposerControls(permissionMode: mode)
                moved.agentKind = kind
                #expect(moved.availablePermissionModes.contains(moved.permissionMode))

                var picked = ComposerControls(agentKind: kind)
                picked.permissionMode = mode
                #expect(picked.availablePermissionModes.contains(picked.permissionMode))
            }
        }
    }

    @Test("moving back to Claude Code offers Plan again without silently choosing it")
    func movingBackOffersPlanAgain() {
        var controls = ComposerControls(agentKind: .claudeCode, permissionMode: .plan)
        controls.agentKind = .codex
        #expect(controls.permissionMode == .auto)

        controls.agentKind = .claudeCode
        #expect(controls.permissionMode == .auto)
        #expect(controls.availablePermissionModes.contains(.plan))
    }

    @Test("the app-wide plan default does not replace Codex permissions")
    func theDefaultLandsOnAModeTheBackendHas() {
        var claude = AppDefaults()
        claude.planMode = true
        #expect(ComposerDefaults.resolve(repo: RepoSettings(), app: claude).permissionMode == .plan)

        var codex = AppDefaults(model: "gpt-5.6-sol", backend: .codex)
        codex.planMode = true
        let resolved = ComposerDefaults.resolve(repo: RepoSettings(), app: codex)
        #expect(resolved.permissionMode == codex.permissionMode)
        #expect(resolved.interactionMode == .plan)
    }

    @Test("relabelling a mode does not rename the slug it is counted under")
    func slugsAreUnchanged() {
        #expect(Feedback.wireName(.auto) == "ask")
        #expect(Feedback.wireName(.acceptEdits) == "accept-edits")
        #expect(Feedback.wireName(.bypassPermissions) == "full-access")
        #expect(Feedback.wireName(.plan) == "plan")
        #expect(Feedback.wireName(.autoReview) == "approve-for-me")
        #expect(Set(PermissionMode.allCases.map(Feedback.wireName)).count == PermissionMode.allCases.count)
    }
}
