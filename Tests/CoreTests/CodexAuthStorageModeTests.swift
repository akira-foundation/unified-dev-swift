import Testing
import Foundation
@testable import Core

@Suite("Codex auth storage mode")
struct CodexAuthStorageModeTests {
    private func mode(_ toml: String) -> CodexAuthStorageMode {
        CodexAuthStorageMode.read(configTOML: Data(toml.utf8))
    }

    @Test func anAbsentConfigFileReadsAsFileModeBecauseThatIsWhatWasMeasured() {
        #expect(CodexAuthStorageMode.read(configTOML: nil) == .file)
    }

    @Test func aConfigWithoutTheKeyReadsAsFileMode() {
        let toml = "model = \"gpt\"\n[features]\njs_repl = false\n"
        #expect(mode(toml) == .file)
    }

    @Test func theSecretAuthStorageFeatureReadsAsKeyring() {
        let toml = "[features]\njs_repl = false\nsecret_auth_storage = true\n"
        #expect(mode(toml) == .keyring)
    }

    @Test func theSecretAuthStorageFeatureSwitchedOffReadsAsFileMode() {
        let toml = "[features]\nsecret_auth_storage = false # off\n"
        #expect(mode(toml) == .file)
    }

    @Test func theFeatureKeyOutsideTheFeaturesTableIsNotTheFeature() {
        let toml = "[other]\nsecret_auth_storage = true\n"
        #expect(mode(toml) == .file)
    }

    @Test func theDottedFormOfTheFeatureKeyReadsAsKeyring() {
        let toml = "features.secret_auth_storage = true\n"
        #expect(mode(toml) == .keyring)
    }

    @Test(arguments: [("file", CodexAuthStorageMode.file), ("keyring", .keyring), ("auto", .keyring)])
    func theCredentialsStoreKeyIsHonoured(value: String, expected: CodexAuthStorageMode) {
        let toml = "cli_auth_credentials_store = \"\(value)\"\n[features]\njs_repl = false\n"
        #expect(mode(toml) == expected)
    }

    @Test func aCredentialsStoreValueNobodyKnowsDoesNotGuaranteeFileMode() {
        let toml = "cli_auth_credentials_store = \"vault\"\n"
        #expect(mode(toml) == .keyring)
    }

    @Test func aQuotedKeyAskingForKeyringReadsAsKeyring() {
        let toml = "\"cli_auth_credentials_store\" = \"keyring\"\n"
        #expect(mode(toml) == .keyring)
    }

    @Test func anInlineFeaturesTableAskingForSecretStorageReadsAsKeyring() {
        let toml = "features = { secret_auth_storage = true }\n"
        #expect(mode(toml) == .keyring)
    }

    @Test func aShapeTheReaderCannotResolveButNamesTheKeyReadsAsKeyring() {
        let toml = "[cli_auth_credentials_store]\nmode = \"keyring\"\n"
        #expect(mode(toml) == .keyring)
    }

    @Test func anUnresolvedMentionOutweighsAKeyThatSaidFile() {
        let toml = "cli_auth_credentials_store = \"file\"\nfeatures = { secret_auth_storage = true }\n"
        #expect(mode(toml) == .keyring)
    }

    @Test func aMentionInsideACommentIsNotAMention() {
        let toml = "# cli_auth_credentials_store = \"keyring\"\nmodel = \"gpt\"\n"
        #expect(mode(toml) == .file)
    }

    @Test func aConfigThatIsNotTextReadsAsFileMode() {
        #expect(CodexAuthStorageMode.read(configTOML: Data([0xFF, 0xFE, 0x00])) == .file)
    }

    @Test(arguments: [
        "[\"features\"]\nsecret_auth_storage = true\n",
        "[ \"features\" ]\nsecret_auth_storage = true\n",
        "[features\t]\nsecret_auth_storage = true\n",
        "\"features\".secret_auth_storage = true\n",
        "features.\"secret_auth_storage\" = true\n",
    ])
    func aValidSpellingOfTheFeatureTableAskingForSecretStorageReadsAsKeyring(toml: String) {
        #expect(mode(toml) == .keyring)
    }

    @Test func aSimplyNamedOtherTableHoldingTheKeyIsGenuinelyElsewhere() {
        #expect(mode("[other-table_1]\nsecret_auth_storage = true\n") == .file)
    }
}
