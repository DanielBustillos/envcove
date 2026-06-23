import SwiftUI
import AppKit
import CryptoKit
import LocalAuthentication
import OSLog

private let logger = Logger(subsystem: "com.daniel.secretmanager", category: "AppStore")

@MainActor
final class AppStore: ObservableObject {
    @Published var projects: [Project] = []
    @Published var selectedProjectID: Project.ID?
    /// When set, the detail column shows all keys for this provider (grouped by project). Cleared when picking a project from the list.
    @Published var selectedSidebarProvider: String?
    @Published private(set) var isVaultReady = false
    @Published var lastVaultError: String?

    private let appSupportFolder: URL
    private let vaultURL: URL
    private let plaintextURL: URL
    private var dataEncryptionKey: SymmetricKey?
    private var isLocked = true
    private var terminateObserver: NSObjectProtocol?

    init() {
        AppSupportMigration.migrateAppSupportFolderIfNeeded()
        self.appSupportFolder = AppSupportMigration.appSupportFolder()
        try? FileManager.default.createDirectory(at: appSupportFolder, withIntermediateDirectories: true)
        self.vaultURL = AppSupportMigration.vaultURL(in: appSupportFolder)
        self.plaintextURL = AppSupportMigration.plaintextURL(in: appSupportFolder)

        terminateObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.save()
        }
    }

    deinit {
        if let terminateObserver {
            NotificationCenter.default.removeObserver(terminateObserver)
        }
    }

    /// Loads or creates the DEK and decrypts the vault. Call after successful Touch ID.
    @discardableResult
    func unlock(context: LAContext) -> Bool {
        lastVaultError = nil

        do {
            let vaultExists = FileManager.default.fileExists(atPath: vaultURL.path)
            let plaintextExists = FileManager.default.fileExists(atPath: plaintextURL.path)

            let dek: SymmetricKey
            if let existing = try VaultKeychain.loadDEK(context: context) {
                dek = existing
            } else if vaultExists {
                // Orphan vault from a prior failed unlock — remove and recreate cleanly.
                logger.warning("Removing orphan vault with no Keychain DEK.")
                try? FileManager.default.removeItem(at: vaultURL)
                let newKey = VaultCrypto.generateDEK()
                try VaultKeychain.storeDEK(newKey, context: context)
                dek = newKey
            } else {
                let newKey = VaultCrypto.generateDEK()
                try VaultKeychain.storeDEK(newKey, context: context)
                dek = newKey
            }

            dataEncryptionKey = dek
            isLocked = false

            let selectedID = selectedProjectID
            let selectedProvider = selectedSidebarProvider

            if vaultExists && FileManager.default.fileExists(atPath: vaultURL.path) {
                try loadFromVault(using: dek)
            } else if plaintextExists {
                try migratePlaintextToVault(using: dek)
            } else {
                projects = [Project(name: "Default Project")]
                selectedProjectID = projects.first?.id
                save()
            }

            if selectedProjectID == nil {
                selectedProjectID = projects.first?.id
            } else {
                selectedProjectID = selectedID
                selectedSidebarProvider = selectedProvider
            }

            isVaultReady = true
            return true
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            logger.error("Unlock error: \(message, privacy: .public)")
            lastVaultError = message
            projects = []
            selectedProjectID = nil
            selectedSidebarProvider = nil
            dataEncryptionKey = nil
            isLocked = true
            isVaultReady = false
            return false
        }
    }

    /// Clears in-memory projects and the DEK. Call after saving on lock.
    func lock() {
        for pIdx in projects.indices {
            for sIdx in projects[pIdx].secrets.indices {
                projects[pIdx].secrets[sIdx].value = ""
            }
        }
        projects = []
        selectedProjectID = nil
        selectedSidebarProvider = nil
        dataEncryptionKey = nil
        isLocked = true
        isVaultReady = false
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

    func save() {
        guard let key = dataEncryptionKey, isVaultReady, !isLocked else {
            if isVaultReady == false && !projects.isEmpty {
                logger.error("Save skipped: vault is not ready (DEK unavailable).")
            }
            return
        }
        do {
            let data = try VaultCrypto.encrypt(projects: projects, key: key)
            try data.write(to: vaultURL, options: .atomic)
        } catch {
            logger.error("Save error: \(error.localizedDescription, privacy: .public)")
            lastVaultError = error.localizedDescription
        }
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
        selectedSidebarProvider = nil
        selectedProjectID = project.id
        save()
    }

    func deleteProjects(at offsets: IndexSet) {
        let removedIDs = offsets.map { projects[$0].id }
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
        let secret = SecretEntry(key: "NEW_KEY", value: "", provider: "OpenAI", providerIcon: "brain")
        projects[idx].secrets.append(secret)
        touchProject(at: idx)
        save()
    }

    func addProvider(name: String, icon: String) {
        guard let idx = selectedProjectIndex else { return }
        let placeholder = SecretEntry(key: "", value: "", provider: name, providerIcon: icon, isPlaceholder: true)
        projects[idx].secrets.append(placeholder)
        touchProject(at: idx)
        save()
    }

    func addSecret(to provider: String, icon: String) {
        guard let idx = selectedProjectIndex else { return }
        projects[idx].secrets.removeAll { $0.provider == provider && $0.isPlaceholder }
        let secret = SecretEntry(key: "NEW_KEY", value: "", provider: provider, providerIcon: icon)
        projects[idx].secrets.append(secret)
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
        let icon = providerPresets.first(where: { $0.name.caseInsensitiveCompare(prov) == .orderedSame })?.icon ?? "network"
        projects[idx].secrets.removeAll { $0.provider == prov && $0.isPlaceholder }
        let secret = SecretEntry(key: name, value: secretValue, provider: prov, providerIcon: icon)
        projects[idx].secrets.append(secret)
        touchProject(at: idx)
        save()
    }

    func deleteSecrets(at offsets: IndexSet) {
        guard let idx = selectedProjectIndex else { return }
        projects[idx].secrets.remove(atOffsets: offsets)
        removeEmptySecrets(projectIndex: idx)
        touchProject(at: idx)
        save()
    }

    func deleteSecrets(withIDs ids: [SecretEntry.ID]) {
        let idSet = Set(ids)
        var changed = false
        for pIdx in projects.indices {
            let beforeCount = projects[pIdx].secrets.count
            projects[pIdx].secrets.removeAll { idSet.contains($0.id) }
            guard projects[pIdx].secrets.count != beforeCount else { continue }
            removeEmptySecrets(projectIndex: pIdx)
            touchProject(at: pIdx)
            changed = true
        }
        if changed { save() }
    }

    func updateSecret(_ secretID: SecretEntry.ID, key: String, value: String, provider: String, providerIcon: String) {
        guard let (pIdx, sIdx) = indicesForSecret(secretID) else { return }
        projects[pIdx].secrets[sIdx].key = key
        projects[pIdx].secrets[sIdx].value = value
        projects[pIdx].secrets[sIdx].provider = provider
        projects[pIdx].secrets[sIdx].providerIcon = providerIcon
        removeEmptySecrets(projectIndex: pIdx)
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
        projects[idx].secrets.removeAll { $0.provider == name }
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

    private func loadFromVault(using key: SymmetricKey) throws {
        guard let data = try? Data(contentsOf: vaultURL) else {
            throw VaultCryptoError.vaultFileMissing
        }
        projects = try VaultCrypto.decrypt(data: data, key: key)
    }

    private func migratePlaintextToVault(using key: SymmetricKey) throws {
        projects = AppSupportMigration.loadPlaintextProjects(from: plaintextURL) ?? []
        _ = KeychainMigration.migrateSecrets(into: &projects, from: plaintextURL)
        let data = try VaultCrypto.encrypt(projects: projects, key: key)
        try data.write(to: vaultURL, options: .atomic)
        try? FileManager.default.removeItem(at: plaintextURL)
        AppSupportMigration.markEncryptedVaultMigrated()
    }

    private func removeEmptySecrets(projectIndex: Int) {
        guard projects.indices.contains(projectIndex) else { return }
        projects[projectIndex].secrets.removeAll { secret in
            secret.key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            secret.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }
}
