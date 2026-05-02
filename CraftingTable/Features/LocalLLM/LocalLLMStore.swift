import Foundation

struct LocalLLMManifest: Codable, Equatable {
    var schemaVersion: Int
    var models: [LocalLLMModelRecord]
    var activeModelID: String?
}

extension LocalLLMManifest {
    static let empty = LocalLLMManifest(
        schemaVersion: 1,
        models: [],
        activeModelID: nil
    )
}

@MainActor
final class LocalLLMStore: ObservableObject {
    @Published private(set) var manifest: LocalLLMManifest
    @Published private(set) var lastError: String?

    let manifestURL: URL
    let cacheDirectoryURL: URL

    private let sourceClient: HuggingFaceModelSourceClient
    private let fileManager: FileManager

    init(
        manifestURL: URL? = nil,
        cacheDirectoryURL: URL? = nil,
        sourceClient: HuggingFaceModelSourceClient = HuggingFaceModelSourceClient(),
        fileManager: FileManager = .default
    ) {
        self.manifestURL = manifestURL ?? Self.defaultManifestURL
        self.cacheDirectoryURL = cacheDirectoryURL ?? Self.defaultCacheDirectoryURL
        self.sourceClient = sourceClient
        self.fileManager = fileManager

        if fileManager.fileExists(atPath: self.manifestURL.path) {
            do {
                manifest = try Self.decodeManifest(from: self.manifestURL)
            } catch {
                manifest = .empty
                lastError = error.localizedDescription
            }
        } else {
            manifest = .empty
            persist()
        }
    }

    var models: [LocalLLMModelRecord] {
        manifest.models
    }

    var activeModel: LocalLLMModelRecord? {
        guard let activeModelID = manifest.activeModelID else {
            return nil
        }

        return manifest.models.first { $0.id == activeModelID }
    }

    func discoverHuggingFaceGGUF(repositoryID: String) async -> [HuggingFaceGGUFFile] {
        do {
            let files = try await sourceClient.ggufFiles(repositoryID: repositoryID)
            lastError = nil
            return files
        } catch {
            lastError = error.localizedDescription
            return []
        }
    }

    func addModel(_ record: LocalLLMModelRecord) {
        upsert(record)
    }

    func downloadAndVerify(modelID: String) async {
        guard let record = model(with: modelID) else {
            lastError = "Model not found."
            return
        }

        updateModel(modelID: modelID) { model in
            model.downloadState = .downloading
            model.verificationState = .unverified
            model.activationState = .inactive
            model.updatedAt = Date()
        }

        do {
            try fileManager.createDirectory(
                at: cacheDirectoryURL,
                withIntermediateDirectories: true
            )

            let (temporaryURL, response) = try await URLSession.shared.download(from: record.downloadURL)
            try validateDownload(response)

            let destinationURL = cacheURL(for: record)
            try fileManager.createDirectory(
                at: destinationURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )

            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }

            try fileManager.moveItem(at: temporaryURL, to: destinationURL)

            updateModel(modelID: modelID) { model in
                model.localPath = destinationURL.path
                model.downloadState = .downloaded
                model.verificationState = .verifying
                model.updatedAt = Date()
            }

            let verified = try verify(record: record, fileURL: destinationURL)
            updateModel(modelID: modelID) { model in
                model.verificationState = verified ? .verified : .failed
                model.runtimeCompatibility = verified ? .unknown : .incompatible
                model.updatedAt = Date()
            }
            lastError = verified ? nil : "Downloaded file did not match the expected SHA-256."
        } catch {
            updateModel(modelID: modelID) { model in
                model.downloadState = .failed
                model.verificationState = .failed
                model.updatedAt = Date()
            }
            lastError = error.localizedDescription
        }
    }

    func activate(modelID: String) {
        guard let index = manifest.models.firstIndex(where: { $0.id == modelID }) else {
            lastError = "Model not found."
            return
        }

        guard manifest.models[index].downloadState == .downloaded,
              manifest.models[index].verificationState == .verified,
              manifest.models[index].localPath != nil
        else {
            lastError = "Only downloaded and verified models can be activated."
            return
        }

        for modelIndex in manifest.models.indices {
            manifest.models[modelIndex].activationState = manifest.models[modelIndex].id == modelID ? .active : .inactive
            manifest.models[modelIndex].updatedAt = Date()
        }

        manifest.activeModelID = modelID
        persist()
    }

    func removeModel(modelID: String) {
        guard let index = manifest.models.firstIndex(where: { $0.id == modelID }) else {
            return
        }

        let record = manifest.models.remove(at: index)
        if let localPath = record.localPath,
           fileManager.fileExists(atPath: localPath) {
            try? fileManager.removeItem(atPath: localPath)
        }

        if manifest.activeModelID == modelID {
            manifest.activeModelID = nil
        }

        persist()
    }

    private func model(with id: String) -> LocalLLMModelRecord? {
        manifest.models.first { $0.id == id }
    }

    private func upsert(_ record: LocalLLMModelRecord) {
        if let index = manifest.models.firstIndex(where: { $0.id == record.id }) {
            manifest.models[index] = record
        } else {
            manifest.models.append(record)
        }

        persist()
    }

    private func updateModel(modelID: String, update: (inout LocalLLMModelRecord) -> Void) {
        guard let index = manifest.models.firstIndex(where: { $0.id == modelID }) else {
            return
        }

        update(&manifest.models[index])
        persist()
    }

    private func cacheURL(for record: LocalLLMModelRecord) -> URL {
        cacheDirectoryURL
            .appendingPathComponent(sanitizedFileComponent(record.id), isDirectory: true)
            .appendingPathComponent(record.filename)
    }

    private func sanitizedFileComponent(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_."))
        return value
            .unicodeScalars
            .map { allowed.contains($0) ? Character($0) : "-" }
            .reduce(into: "") { $0.append($1) }
    }

    private func verify(record: LocalLLMModelRecord, fileURL: URL) throws -> Bool {
        guard let sha256 = record.sha256, sha256.isEmpty == false else {
            return true
        }

        return try LocalLLMFileVerifier.verify(fileURL: fileURL, expectedSHA256: sha256)
    }

    private func validateDownload(_ response: URLResponse) throws {
        guard let response = response as? HTTPURLResponse else {
            return
        }

        guard (200..<300).contains(response.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }

    func persist() {
        do {
            try fileManager.createDirectory(
                at: manifestURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )

            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(manifest)
            try data.write(to: manifestURL, options: [.atomic])
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    private static var defaultManifestURL: URL {
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return baseURL
            .appendingPathComponent("CraftingTable", isDirectory: true)
            .appendingPathComponent("local-llm-manifest-v0.json")
    }

    private static var defaultCacheDirectoryURL: URL {
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return baseURL
            .appendingPathComponent("CraftingTable", isDirectory: true)
            .appendingPathComponent("LocalLLMModels", isDirectory: true)
    }

    private static func decodeManifest(from fileURL: URL) throws -> LocalLLMManifest {
        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(LocalLLMManifest.self, from: data)
    }
}
