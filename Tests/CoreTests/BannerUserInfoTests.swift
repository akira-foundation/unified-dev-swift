import Foundation
import Testing
@testable import Core

@Suite("Banner userInfo")
struct BannerUserInfoTests {
    @Test("what a banner carries is a property list, which is the only kind of value it may carry")
    func encodesAPropertyList() {
        let userInfo = BannerUserInfo.encode(workspaceID: WorkspaceID("w1"))
        #expect(PropertyListSerialization.propertyList(userInfo, isValidFor: .binary))
    }

    @Test("the struct that used to be written here is neither a property list nor readable")
    func theOldEncodingWasUnsendableAndUnreadable() {
        let old: [AnyHashable: Any] = ["unifieddevWorkspaceID": WorkspaceID("w1")]
        #expect(!PropertyListSerialization.propertyList(old, isValidFor: .binary))
        #expect(BannerUserInfo.workspaceID(from: old) == nil)
    }

    @Test("an id written into a banner is the id read back out of it")
    func roundTrips() {
        let userInfo = BannerUserInfo.encode(workspaceID: WorkspaceID("9d4b0f1e-1111-2222"))
        #expect(BannerUserInfo.workspaceID(from: userInfo) == WorkspaceID("9d4b0f1e-1111-2222"))
    }

    @Test("a banner that names no workspace reads back as none")
    func namesNoWorkspace() {
        let unnamed = BannerUserInfo.encode(workspaceID: WorkspaceID(""))
        #expect(BannerUserInfo.workspaceID(from: unnamed) == nil)
        #expect(BannerUserInfo.workspaceID(from: [:]) == nil)
        #expect(BannerUserInfo.workspaceID(from: ["somethingElse": "w1"]) == nil)
    }
}
