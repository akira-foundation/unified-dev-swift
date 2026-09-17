import Foundation

extension SettingsLoader {
    static func applyRunScripts(
        _ toml: TOMLValue, outline: TOMLOutline?, from source: String,
        to settings: inout RepoSettings, repo: String
    ) {
        guard let run = toml["scripts.run"] else { return }
        let base = SettingsKey.runScripts.path

        switch run {
        case .string(let command):
            guard !command.isEmpty else { return }
            settings.runScripts = [RunScript(id: "run", name: "Run", command: command)]
            settings.origins[.runScripts] = source

        case .table(let named):
            let keys = outline?.keys(of: named, at: base) ?? named.keys.sorted()
            var scripts: [RunScript] = []
            var files: [ScriptLocation: ScriptFile] = [:]
            var taken: [String: String] = [:]

            for key in keys {
                guard let value = named[key] else { continue }
                let line = outline?.line(of: base + [key])
                func report(_ message: String) {
                    settings.issues.append(SettingsIssue(
                        path: source, message: "Run script \u{201C}\(key)\u{201D} \(message)",
                        entry: .runScript(key), line: line
                    ))
                }

                let read: RunScriptEntry
                switch readRunScript(key: key, value: value, repo: repo) {
                case .success(let entry): read = entry
                case .failure(let problem):
                    report("was skipped: \(problem.reason).")
                    continue
                }

                let normalised = read.script.name
                    .trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                if let first = taken[normalised] {
                    report(
                        "was skipped: run script \u{201C}\(first)\u{201D} already has the name "
                            + "\u{201C}\(read.script.name)\u{201D}."
                    )
                    continue
                }
                taken[normalised] = key

                if let file = read.file {
                    files[.run(key)] = file
                    if file.isMissing {
                        report("cannot run: \(file.path) does not exist.")
                    }
                }
                scripts.append(read.script)
            }

            if !scripts.isEmpty {
                settings.runScripts = scripts
                for (location, file) in files { settings.scriptFiles[location] = file }
                settings.origins[.runScripts] = source
            }

        default:
            settings.issues.append(SettingsIssue(
                path: source,
                message: "Run scripts were skipped: scripts.run has to be a command or a table of scripts.",
                entry: .file,
                line: outline?.line(of: base)
            ))
        }
    }

    struct RunScriptEntry {
        var script: RunScript
        var file: ScriptFile?
    }

    struct EntryProblem: Error {
        var reason: String
    }

    static func readRunScript(
        key: String, value: TOMLValue, repo: String
    ) -> Result<RunScriptEntry, EntryProblem> {
        let table: [String: TOMLValue]
        switch value {
        case .string(let command):
            guard !command.isEmpty else { return .failure(EntryProblem(reason: "it has no command")) }
            return .success(RunScriptEntry(
                script: RunScript(id: key, name: key.capitalizedFirst, command: command), file: nil
            ))
        case .table(let fields):
            table = fields
        default:
            return .failure(EntryProblem(reason: "it has to be a table or a command in quotes"))
        }

        let name: String?
        let command: String?
        let file: String?
        let icon: String?
        let autostart: Bool?
        do throws(EntryProblem) {
            name = try text(table["name"], "name")
            command = try text(table["command"], "command")
            file = try text(table["file"], "file")
            icon = try text(table["icon"], "icon")
            autostart = try flag(table["autostart"], "autostart")
        } catch {
            return .failure(error)
        }

        let trimmedName = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let resolvedName = trimmedName.isEmpty ? key.capitalizedFirst : trimmedName
        let trimmedIcon = icon?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let resolvedIcon = trimmedIcon.isEmpty ? nil : trimmedIcon

        if let file, !file.isEmpty {
            let text = try? String(contentsOfFile: resolve(file, repo: repo), encoding: .utf8)
            return .success(RunScriptEntry(
                script: RunScript(
                    id: key, name: resolvedName, command: text ?? "",
                    icon: resolvedIcon, autostart: autostart ?? false
                ),
                file: ScriptFile(path: file, isMissing: text == nil)
            ))
        }
        guard let command, !command.isEmpty else {
            return .failure(EntryProblem(reason: "it has no command"))
        }
        return .success(RunScriptEntry(
            script: RunScript(
                id: key, name: resolvedName, command: command,
                icon: resolvedIcon, autostart: autostart ?? false
            ),
            file: nil
        ))
    }

    static func applyQuickPrompts(
        _ toml: TOMLValue, outline: TOMLOutline?, from source: String,
        to settings: inout RepoSettings
    ) {
        guard let stated = toml["quick_prompts"] else { return }
        guard case .array(let entries) = stated else {
            settings.issues.append(SettingsIssue(
                path: source,
                message: "Quick prompts were skipped: each one has to be a [[quick_prompts]] table.",
                entry: .file,
                line: outline?.line(of: ["quick_prompts"])
            ))
            return
        }

        var prompts: [ProjectQuickPrompt] = []
        var taken: Set<String> = []
        for (index, entry) in entries.enumerated() {
            let line = outline?.line(of: ["quick_prompts", "\(index)"])
            let fields = entry.tableValue
            let usableName = (fields?["name"]?.stringValue)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .flatMap { $0.isEmpty ? nil : $0 }
            func report(_ message: String) {
                let label = usableName.map { "Quick prompt \u{201C}\($0)\u{201D}" }
                    ?? "Quick prompt \(index + 1)"
                settings.issues.append(SettingsIssue(
                    path: source, message: "\(label) \(message)",
                    entry: .quickPrompt(index: index, name: usableName), line: line
                ))
            }

            guard let fields else {
                report("was skipped: it has to be a table.")
                continue
            }
            switch readQuickPrompt(fields, source: source) {
            case .failure(let problem):
                report("was skipped: \(problem.reason).")
            case .success(let prompt):
                if fields["send_immediately"] != nil {
                    report("will not send on its own: send_immediately is not supported in a shared settings file.")
                }
                guard taken.insert(prompt.id).inserted else {
                    report("was skipped: another quick prompt already has that name.")
                    continue
                }
                if let stated = fields["symbol"]?.stringValue?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                   !stated.isEmpty, prompt.symbol != stated {
                    report("shows the default symbol: \u{201C}\(stated)\u{201D} is not one Unified Dev offers.")
                }
                prompts.append(prompt)
            }
        }
        settings.quickPrompts = prompts
    }

    static func readQuickPrompt(
        _ fields: [String: TOMLValue], source: String
    ) -> Result<ProjectQuickPrompt, EntryProblem> {
        let name: String?
        let prompt: String?
        let symbol: String?
        let newChat: Bool?
        do throws(EntryProblem) {
            name = try text(fields["name"], "name")
            prompt = try text(fields["prompt"], "prompt")
            symbol = try text(fields["symbol"], "symbol")
            newChat = try flag(fields["new_chat"], "new_chat")
        } catch {
            return .failure(error)
        }

        let trimmedName = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmedName.isEmpty else { return .failure(EntryProblem(reason: "it has no name")) }
        guard let prompt, !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .failure(EntryProblem(reason: "it has no prompt"))
        }
        return .success(ProjectQuickPrompt(
            name: trimmedName,
            text: prompt,
            symbol: QuickPrompt.resolvedSymbol(symbol ?? QuickPrompt.defaultSymbol),
            opensNewChat: newChat ?? false,
            source: source
        ))
    }

    private static func text(_ value: TOMLValue?, _ key: String) throws(EntryProblem) -> String? {
        guard let value else { return nil }
        guard let text = value.stringValue else {
            throw EntryProblem(reason: "\(key) has to be text in quotes")
        }
        return text
    }

    private static func flag(_ value: TOMLValue?, _ key: String) throws(EntryProblem) -> Bool? {
        guard let value else { return nil }
        guard let flag = value.boolValue else {
            throw EntryProblem(reason: "\(key) has to be true or false")
        }
        return flag
    }
}
