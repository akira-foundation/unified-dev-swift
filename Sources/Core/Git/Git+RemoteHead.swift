import Foundation

extension Git {
    public static func remoteDefaultBranch(
        of directory: String, timeout: Duration = .seconds(5)
    ) async -> String? {
        guard let names = try? await remoteNames(of: directory),
              let remote = primaryRemote(of: names),
              (try? validate(ref: remote, label: "remote")) != nil,
              let result = try? await run(
                  ["ls-remote", "--symref", "--", remote, "HEAD"], in: directory, timeout: timeout
              ),
              result.ok
        else { return nil }
        return remoteHeadBranch(inListing: result.stdout)
    }

    static func remoteHeadBranch(inListing listing: String) -> String? {
        let prefix = "ref: refs/heads/"
        for line in listing.split(separator: "\n") {
            let fields = line.split(separator: "\t", omittingEmptySubsequences: false)
            guard fields.count == 2, fields[1] == "HEAD", fields[0].hasPrefix(prefix) else { continue }
            let branch = String(fields[0].dropFirst(prefix.count))
            return isValidBranchName(branch) ? branch : nil
        }
        return nil
    }
}
