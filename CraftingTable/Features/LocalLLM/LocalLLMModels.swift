import Foundation

enum LocalLLMModelSource: String, Codable, CaseIterable {
    case huggingFace
    case customURL
    case githubRelease

    var title: String {
        switch self {
        case .huggingFace:
            return "Hugging Face"
        case .customURL:
            return "Custom URL"
        case .githubRelease:
            return "GitHub Release"
        }
    }
}

enum LocalLLMDownloadState: String, Codable {
    case notDownloaded
    case downloading
    case downloaded
    case failed
}

enum LocalLLMVerificationState: String, Codable {
    case unverified
    case verifying
    case verified
    case failed
}

enum LocalLLMActivationState: String, Codable {
    case inactive
    case activating
    case active
    case failed
}

enum LocalLLMRuntimeCompatibility: String, Codable {
    case unknown
    case compatible
    case incompatible
}

struct LocalLLMModelRecord: Identifiable, Codable, Equatable {
    var id: String
    var displayName: String
    var source: LocalLLMModelSource
    var repositoryID: String?
    var revision: String?
    var filename: String
    var downloadURL: URL
    var license: String?
    var fileSize: Int64?
    var sha256: String?
    var localPath: String?
    var downloadState: LocalLLMDownloadState
    var verificationState: LocalLLMVerificationState
    var activationState: LocalLLMActivationState
    var runtimeCompatibility: LocalLLMRuntimeCompatibility
    var createdAt: Date
    var updatedAt: Date
}

extension LocalLLMModelRecord {
    static func huggingFaceGGUF(
        repositoryID: String,
        revision: String,
        filename: String,
        displayName: String? = nil,
        license: String? = nil,
        fileSize: Int64? = nil,
        sha256: String? = nil,
        now: Date = Date()
    ) -> LocalLLMModelRecord {
        let encodedFilename = filename
            .split(separator: "/")
            .map { String($0).addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? String($0) }
            .joined(separator: "/")
        let url = URL(string: "https://huggingface.co/\(repositoryID)/resolve/\(revision)/\(encodedFilename)")!

        return LocalLLMModelRecord(
            id: "hf:\(repositoryID):\(revision):\(filename)",
            displayName: displayName ?? filename.replacingOccurrences(of: ".gguf", with: ""),
            source: .huggingFace,
            repositoryID: repositoryID,
            revision: revision,
            filename: filename,
            downloadURL: url,
            license: license,
            fileSize: fileSize,
            sha256: sha256,
            localPath: nil,
            downloadState: .notDownloaded,
            verificationState: .unverified,
            activationState: .inactive,
            runtimeCompatibility: .unknown,
            createdAt: now,
            updatedAt: now
        )
    }
}

struct LocalLLMGenerationRequest: Equatable {
    var modelID: String?
    var input: String
    var instructions: String?
    var maxOutputTokens: Int?
    var temperature: Double?
    var topP: Double?
}

struct LocalLLMGenerationResult: Equatable {
    var modelID: String
    var outputText: String
    var inputTokens: Int?
    var outputTokens: Int?
}

enum LocalLLMServerState: Equatable {
    case stopped
    case starting
    case listening(URL)
    case generating(URL)
    case failed(String)
}
