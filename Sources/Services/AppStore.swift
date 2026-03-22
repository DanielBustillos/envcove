import SwiftUI
import AppKit
import OSLog
import LocalAuthentication

private let logger = Logger(subsystem: "com.daniel.secretmanager", category: "AppStore")

@MainActor
final class AppStore: ObservableObject {
    @Published var projects: [Project] = []
    @Published var selectedProjectID: Project.ID?
    /// When set, the detail column shows all keys for this provider (grouped by project). Cleared when picking a project from the list.
    @Published var selectedSidebarProvider: String?

    private let saveURL: URL
    private let keychain = KeychainStore(service: "com.daniel.secretmanager")
    private var hasPreparedSecretsFromKeychain = false

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let folder = appSupport.appendingPathComponent("SecretManager", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        self.saveURL = folder.appendingPathComponent("projects.json")
        load()
        if projects.isEmpty {
            projects = [Project(name: "Default Project")]
        }
        selectedProjectID = projects.first?.id
    }

    func selectSidebarProvider(_ name: String) {
        selectedSidebarProvider = name
        if let sid = selectedProjectID,
           let idx = projects.firstIndex(where: { $0.id == sid }),
           projects[idx].secrets.contains(where: { $0.provider == name }) {
            return
        }
        selectedProjectID = projects.first(where: { $0.secrets.contains { $0.provider == name } })?.id
    }

    func selectProjectOnly(_ id: Project.ID) {
        selectedSidebarProvider = nil
        selectedProjectID = id
    }

    func prepareSecretsFromKeychainIfNeeded(context: LAContext? = nil) {
        guard !hasPreparedSecretsFromKeychain else { return }
        hydrateValuesFromKeychain(context: context)
        hasPreparedSecretsFromKeychain = true
    }

    func reauthenticateWithKeychain(context: LAContext? = nil) {
        hydrateValuesFromKeychain(context: context)
        hasPreparedSecretsFromKeychain = true
    }

    func flushAllProjectsToKeychain(context: LAContext? = nil) {
        for index in projects.indices {
            persistProjectSecretsToKeychain(projectIndex: index)
        }
    }

    /// Zeroes every secret value held in memory. Called when the app locks so plaintext keys
    /// are no longer accessible in the process heap until the next successful authentication.
    func clearSecretsFromMemory() {
        for pIdx in projects.indices {
            for sIdx in projects[pIdx].secrets.indices {
                projects[pIdx].secrets[sIdx].value = ""
            }
        }
        hasPreparedSecretsFromKeychain = false
    }

    var selectedProjectIndex: Int? {
        guard let selectedProjectID else { return nil }
        return projects.firstIndex(where: { $0.id == selectedProjectID })
    }

    private func indicesForSecret(_ secretID: SecretEntry.ID) -> (pIdx: Int, sIdx: Int)? {
        for pIdx in projects.indices {
            if let sIdx = projects[pIdx].secrets.firstIndex(where: { $0.id == secretID }) {
                return (pIdx, sIdx)
            }
        }
        return nil
    }

    func addProject() {
        let base = "New Project"
        var candidate = base
        var n = 1
        while projects.contains(where: { $0.name == candidate }) {
            n += 1
            candidate = "\(base) \(n)"
        }
        let project = Project(name: candidate)
        projects.append(project)
        touchProject(at: projects.count - 1)
        _ = keychain.setProjectSecrets(projectID: project.id, valuesBySecretID: [:])
        selectedSidebarProvider = nil
        selectedProjectID = project.id
        save()
    }

    func deleteProjects(at offsets: IndexSet) {
        let removedProjects = offsets.map { projects[$0] }
        for project in removedProjects {
            keychain.deleteProjectSecrets(projectID: project.id)
        }
        let removedIDs = removedProjects.map(\.id)
        projects.remove(atOffsets: offsets)
        if let selectedProjectID, removedIDs.contains(selectedProjectID) {
            self.selectedProjectID = projects.first?.id
            selectedSidebarProvider = nil
        }
        save()
    }

    func renameSelectedProject(_ name: String) {
        guard let idx = selectedProjectIndex else { return }
        projects[idx].name = name
        touchProject(at: idx)
        save()
    }

    func renameProject(_ projectID: Project.ID, to name: String) {
        guard let idx = projects.firstIndex(where: { $0.id == projectID }) else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        projects[idx].name = trimmed
        touchProject(at: idx)
        save()
    }

    func deleteProject(_ projectID: Project.ID) {
        guard let idx = projects.firstIndex(where: { $0.id == projectID }) else { return }
        keychain.deleteProjectSecrets(projectID: projectID)
        let removedID = projects[idx].id
        projects.remove(at: idx)
        if selectedProjectID == removedID {
            selectedProjectID = projects.first?.id
            selectedSidebarProvider = nil
        }
        save()
    }

    func addSecret() {
        guard let idx = selectedProjectIndex else { return }
        let previousPersistedValues = persistedValuesMap(forProjectAt: idx)
        let secret = SecretEntry(key: "NEW_KEY", value: "", provider: "OpenAI", providerIcon: "brain")
        projects[idx].secrets.append(secret)
        persistProjectSecretsToKeychainIfChanged(projectIndex: idx, previousValues: previousPersistedValues)
        touchProject(at: idx)
        save()
    }

    func addProvider(name: String, icon: String) {
        guard let idx = selectedProjectIndex else { return }
        let previousPersistedValues = persistedValuesMap(forProjectAt: idx)
        let placeholder = SecretEntry(key: "", value: "", provider: name, providerIcon: icon, isPlaceholder: true)
        projects[idx].secrets.append(placeholder)
        persistProjectSecretsToKeychainIfChanged(projectIndex: idx, previousValues: previousPersistedValues)
        touchProject(at: idx)
        save()
    }

    func addSecret(to provider: String, icon: String) {
        guard let idx = selectedProjectIndex else { return }
        let previousPersistedValues = persistedValuesMap(forProjectAt: idx)
        projects[idx].secrets.removeAll { $0.provider == provider && $0.isPlaceholder }
        let secret = SecretEntry(key: "NEW_KEY", value: "", provider: provider, providerIcon: icon)
        projects[idx].secrets.append(secret)
        persistProjectSecretsToKeychainIfChanged(projectIndex: idx, previousValues: previousPersistedValues)
        touchProject(at: idx)
        save()
    }

    /// Adds a secret with explicit name (env key), value, and provider; icon is resolved from presets when possible.
    /// Pass `projectID` to add to a specific project (e.g. from the provider sidebar); otherwise uses the selected project.
    func addSecret(named keyName: String, secretValue: String, provider: String, projectID: Project.ID? = nil) {
        let name = keyName.trimmingCharacters(in: .whitespacesAndNewlines)
        let prov = provider.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !prov.isEmpty else { return }
        let idx: Int?
        if let pid = projectID {
            idx = projects.firstIndex(where: { $0.id == pid })
        } else {
            idx = selectedProjectIndex
        }
        guard let idx else { return }
        let previousPersistedValues = persistedValuesMap(forProjectAt: idx)
        let icon = providerPresets.first(where: { $0.name.caseInsensitiveCompare(prov) == .orderedSame })?.icon ?? "network"
        projects[idx].secrets.removeAll { $0.provider == prov && $0.isPlaceholder }
        let secret = SecretEntry(key: name, value: secretValue, provider: prov, providerIcon: icon)
        projects[idx].secrets.append(secret)
        persistProjectSecretsToKeychainIfChanged(projectIndex: idx, previousValues: previousPersistedValues)
        touchProject(at: idx)
        save()
    }

    func deleteSecrets(at offsets: IndexSet) {
        guard let idx = selectedProjectIndex else { return }
        let previousPersistedValues = persistedValuesMap(forProjectAt: idx)
        projects[idx].secrets.remove(atOffsets: offsets)
        removeEmptySecrets(projectIndex: idx)
        persistProjectSecretsToKeychainIfChanged(projectIndex: idx, previousValues: previousPersistedValues)
        touchProject(at: idx)
        save()
    }

    func deleteSecrets(withIDs ids: [SecretEntry.ID]) {
        let idSet = Set(ids)
        var changed = false
        for pIdx in projects.indices {
            let previousPersistedValues = persistedValuesMap(forProjectAt: pIdx)
            let beforeCount = projects[pIdx].secrets.count
            projects[pIdx].secrets.removeAll { idSet.contains($0.id) }
            guard projects[pIdx].secrets.count != beforeCount else { continue }
            removeEmptySecrets(projectIndex: pIdx)
            persistProjectSecretsToKeychainIfChanged(projectIndex: pIdx, previousValues: previousPersistedValues)
            touchProject(at: pIdx)
            changed = true
        }
        if changed { save() }
    }

    func updateSecret(_ secretID: SecretEntry.ID, key: String, value: String, provider: String, providerIcon: String) {
        guard let (pIdx, sIdx) = indicesForSecret(secretID) else { return }
        let previousPersistedValues = persistedValuesMap(forProjectAt: pIdx)
        projects[pIdx].secrets[sIdx].key = key
        projects[pIdx].secrets[sIdx].value = value
        projects[pIdx].secrets[sIdx].provider = provider
        projects[pIdx].secrets[sIdx].providerIcon = providerIcon
        removeEmptySecrets(projectIndex: pIdx)
        persistProjectSecretsToKeychainIfChanged(projectIndex: pIdx, previousValues: previousPersistedValues)
        touchProject(at: pIdx)
        save()
    }

    func moveSecret(_ secretID: SecretEntry.ID, toProvider provider: String, icon: String) {
        guard let (pIdx, sIdx) = indicesForSecret(secretID) else { return }
        projects[pIdx].secrets[sIdx].provider = provider
        projects[pIdx].secrets[sIdx].providerIcon = icon
        removeEmptySecrets(projectIndex: pIdx)
        touchProject(at: pIdx)
        save()
    }

    func createProviderAndMoveSecret(_ secretID: SecretEntry.ID, baseName: String = "New Provider", icon: String = "network") {
        guard let (pIdx, sIdx) = indicesForSecret(secretID) else { return }

        var candidate = baseName
        var suffix = 1
        let existing = Set(projects[pIdx].secrets.map(\.provider))
        while existing.contains(candidate) {
            suffix += 1
            candidate = "\(baseName) \(suffix)"
        }

        projects[pIdx].secrets[sIdx].provider = candidate
        projects[pIdx].secrets[sIdx].providerIcon = icon
        touchProject(at: pIdx)
        save()
    }

    func renameProvider(oldName: String, newName: String) {
        guard let idx = selectedProjectIndex else { return }
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        for secretIndex in projects[idx].secrets.indices where projects[idx].secrets[secretIndex].provider == oldName {
            projects[idx].secrets[secretIndex].provider = trimmed
        }
        touchProject(at: idx)
        save()
    }

    func updateProviderIcon(providerName: String, icon: String) {
        guard let idx = selectedProjectIndex else { return }
        for secretIndex in projects[idx].secrets.indices where projects[idx].secrets[secretIndex].provider == providerName {
            projects[idx].secrets[secretIndex].providerIcon = icon
        }
        touchProject(at: idx)
        save()
    }

    func deleteProvider(name: String, projectID: Project.ID? = nil) {
        let idx: Int?
        if let pid = projectID {
            idx = projects.firstIndex(where: { $0.id == pid })
        } else {
            idx = selectedProjectIndex
        }
        guard let idx else { return }
        let previousPersistedValues = persistedValuesMap(forProjectAt: idx)
        projects[idx].secrets.removeAll { $0.provider == name }
        persistProjectSecretsToKeychainIfChanged(projectIndex: idx, previousValues: previousPersistedValues)
        touchProject(at: idx)
        save()
    }

    func exportSelectedProjectAsEnv() {
        guard let idx = selectedProjectIndex else { return }
        exportProjectAsEnv(projectID: projects[idx].id)
    }

    func exportProjectAsEnv(projectID: Project.ID) {
        guard let idx = projects.firstIndex(where: { $0.id == projectID }) else { return }
        let project = projects[idx]
        let lines = project.secrets
            .filter { !$0.key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .map { "\($0.key)=\($0.value)" }
        let content = lines.joined(separator: "\n")

        guard let url = downloadsURL(filename: "\(project.name).env") else { return }
        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } catch {
            logger.error("Export .env error: \(error.localizedDescription, privacy: .public)")
        }
    }

    func exportSelectedProjectAsJSON() {
        guard let idx = selectedProjectIndex else { return }
        let project = projects[idx]

        let payload = ProjectKeysExport(
            projectName: project.name,
            items: project.secrets.map { secret in
                ProjectKeyExportItem(provider: secret.provider, key: secret.key, secret: secret.value)
            }
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(payload) else { return }
        guard let url = downloadsURL(filename: "\(project.name).json") else { return }

        Task.detached(priority: .userInitiated) {
            do {
                try data.write(to: url, options: .atomic)
                await MainActor.run {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                }
            } catch {
                logger.error("Export JSON error: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    /// Returns a unique URL inside ~/Downloads, appending a suffix if the file already exists.
    private func downloadsURL(filename: String) -> URL? {
        guard let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
        else { return nil }

        let base = (filename as NSString).deletingPathExtension
        let ext  = (filename as NSString).pathExtension

        var candidate = downloads.appendingPathComponent(filename)
        var counter = 1
        while FileManager.default.fileExists(atPath: candidate.path) {
            let name = ext.isEmpty ? "\(base) \(counter)" : "\(base) \(counter).\(ext)"
            candidate = downloads.appendingPathComponent(name)
            counter += 1
        }
        return candidate
    }

    func importEnvIntoSelectedProject() {
        guard let idx = selectedProjectIndex else { return }
        let previousPersistedValues = persistedValuesMap(forProjectAt: idx)

        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.init(filenameExtension: "env")!, .plainText]
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.title = "Import .env"

        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return }

        let importedEntries = parseEnv(content: content)
        guard !importedEntries.isEmpty else { return }

        for entry in importedEntries {
            if let existingIdx = projects[idx].secrets.firstIndex(where: { $0.key == entry.key }) {
                projects[idx].secrets[existingIdx].value = entry.value
            } else {
                let secret = SecretEntry(
                    key: entry.key,
                    value: entry.value,
                    provider: "Imported",
                    providerIcon: "square.and.arrow.down"
                )
                projects[idx].secrets.append(secret)
            }
        }

        removeEmptySecrets(projectIndex: idx)
        persistProjectSecretsToKeychainIfChanged(projectIndex: idx, previousValues: previousPersistedValues)
        touchProject(at: idx)
        save()
    }

    func importProjectFromJSON() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.title = "Import Project JSON"

        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard let data = try? Data(contentsOf: url) else { return }
        guard let payload = try? JSONDecoder().decode(ProjectKeysExport.self, from: data) else { return }

        let projectName = payload.projectName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !projectName.isEmpty else { return }

        let projectIndex: Int
        if let existingIndex = projects.firstIndex(where: { $0.name == projectName }) {
            projectIndex = existingIndex
        } else {
            let newProject = Project(name: projectName)
            projects.append(newProject)
            projectIndex = projects.count - 1
        }

        let previousPersistedValues = persistedValuesMap(forProjectAt: projectIndex)

        for item in payload.items {
            let key = item.key.trimmingCharacters(in: .whitespacesAndNewlines)
            let provider = item.provider.trimmingCharacters(in: .whitespacesAndNewlines)
            let providerName = provider.isEmpty ? "Custom" : provider

            if let existingSecretIndex = projects[projectIndex].secrets.firstIndex(where: {
                $0.key == key && $0.provider == providerName
            }) {
                projects[projectIndex].secrets[existingSecretIndex].value = item.secret
            } else {
                let newSecret = SecretEntry(
                    key: key,
                    value: item.secret,
                    provider: providerName,
                    providerIcon: providerIcon(for: providerName)
                )
                projects[projectIndex].secrets.append(newSecret)
            }
        }

        removeEmptySecrets(projectIndex: projectIndex)
        persistProjectSecretsToKeychainIfChanged(projectIndex: projectIndex, previousValues: previousPersistedValues)
        touchProject(at: projectIndex)
        selectedSidebarProvider = nil
        selectedProjectID = projects[projectIndex].id
        save()
    }

    private func parseEnv(content: String) -> [(key: String, value: String)] {
        var result: [(key: String, value: String)] = []

        for rawLine in content.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty || line.hasPrefix("#") { continue }

            let normalizedLine = line.hasPrefix("export ") ? String(line.dropFirst(7)) : line
            guard let equalIndex = normalizedLine.firstIndex(of: "=") else { continue }

            let keyPart = normalizedLine[..<equalIndex].trimmingCharacters(in: .whitespacesAndNewlines)
            var valuePart = String(normalizedLine[normalizedLine.index(after: equalIndex)...])
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if valuePart.hasPrefix("\""), valuePart.hasSuffix("\""), valuePart.count >= 2 {
                valuePart.removeFirst()
                valuePart.removeLast()
            } else if valuePart.hasPrefix("'"), valuePart.hasSuffix("'"), valuePart.count >= 2 {
                valuePart.removeFirst()
                valuePart.removeLast()
            }

            if !keyPart.isEmpty {
                result.append((key: keyPart, value: valuePart))
            }
        }

        return result
    }

    private func providerIcon(for providerName: String) -> String {
        if let preset = providerPresets.first(where: { $0.name.caseInsensitiveCompare(providerName) == .orderedSame }) {
            return preset.icon
        }
        return "network"
    }

    private func touchProject(at index: Int) {
        guard projects.indices.contains(index) else { return }
        projects[index].lastModified = Date()
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(projects)
            try data.write(to: saveURL, options: .atomic)
        } catch {
            logger.error("Save error: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: saveURL) else {
            projects = []
            return
        }
        do {
            projects = try JSONDecoder().decode([Project].self, from: data)
        } catch {
            projects = []
            logger.error("Load error: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func hydrateValuesFromKeychain(context: LAContext? = nil) {
        // Items are stored with kSecAttrAccessibleWhenUnlockedThisDeviceOnly (no user-presence
        // access control), so a plain batch read works. We pass the LAContext only as a hint
        // in case any legacy access-controlled items still exist from before the migration.
        let valuesByProject = keychain.getAllProjectSecrets(context: context)

        for pIdx in projects.indices {
            let projectID = projects[pIdx].id
            var projectValues = valuesByProject[projectID]

            // Per-project fallback for legacy access-controlled items not returned by the batch read.
            if projectValues == nil {
                projectValues = keychain.getProjectSecrets(projectID: projectID, context: context)
            }

            for sIdx in projects[pIdx].secrets.indices {
                let id = projects[pIdx].secrets[sIdx].secretStorageID
                if let hydratedValue = projectValues?[id] {
                    projects[pIdx].secrets[sIdx].value = hydratedValue
                }
            }
        }
    }

    private func persistedValuesMap(forProjectAt projectIndex: Int) -> [String: String] {
        guard projects.indices.contains(projectIndex) else { return [:] }
        let project = projects[projectIndex]
        return Dictionary(
            uniqueKeysWithValues: project.secrets
                .filter { !$0.value.isEmpty }
                .map { ($0.secretStorageID, $0.value) }
        )
    }

    private func removeEmptySecrets(projectIndex: Int) {
        guard projects.indices.contains(projectIndex) else { return }
        projects[projectIndex].secrets.removeAll { secret in
            secret.key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            secret.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private func persistProjectSecretsToKeychainIfChanged(projectIndex: Int, previousValues: [String: String]) {
        guard projects.indices.contains(projectIndex) else { return }
        let project = projects[projectIndex]
        let valuesBySecretID = persistedValuesMap(forProjectAt: projectIndex)
        guard valuesBySecretID != previousValues else { return }
        _ = keychain.setProjectSecrets(projectID: project.id, valuesBySecretID: valuesBySecretID)
    }

    private func persistProjectSecretsToKeychain(projectIndex: Int) {
        guard projects.indices.contains(projectIndex) else { return }
        let project = projects[projectIndex]
        let valuesBySecretID = persistedValuesMap(forProjectAt: projectIndex)
        _ = keychain.setProjectSecrets(projectID: project.id, valuesBySecretID: valuesBySecretID)
    }
}
