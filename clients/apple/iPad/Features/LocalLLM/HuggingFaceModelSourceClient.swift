import Foundation

struct HuggingFaceModelSourceClient {
    enum SourceError: LocalizedError {
        case invalidRepositoryID
        case privateOrGatedRepository(String)
        case noGGUFFiles(String)
        case requestFailed(Int)

        var errorDescription: String? {
            switch self {
            case .invalidRepositoryID:
                return "The Hugging Face repository id is invalid."
            case .privateOrGatedRepository(let repositoryID):
                return "\(repositoryID) is private or gated."
            case .noGGUFFiles(let repositoryID):
                return "\(repositoryID) has no GGUF files."
            case .requestFailed(let statusCode):
                return "Hugging Face request failed with status \(statusCode)."
            }
        }
    }

    var session: URLSession = .shared

    func ggufFiles(repositoryID: String) async throws -> [HuggingFaceGGUFFile] {
        let info = try await modelInfo(repositoryID: repositoryID)

        guard info.isPublicUngated else {
            throw SourceError.privateOrGatedRepository(repositoryID)
        }

        let files = info.ggufFiles
        guard files.isEmpty == false else {
            throw SourceError.noGGUFFiles(repositoryID)
        }

        return files
    }

    func modelInfo(repositoryID: String) async throws -> HuggingFaceModelInfo {
        guard let url = repoInfoURL(repositoryID: repositoryID) else {
            throw SourceError.invalidRepositoryID
        }

        let (data, response) = try await session.data(from: url)
        try validate(response)

        let decoder = JSONDecoder()
        return try decoder.decode(HuggingFaceModelInfo.self, from: data)
    }

    private func repoInfoURL(repositoryID: String) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "huggingface.co"
        components.path = "/api/models/\(repositoryID)"
        components.queryItems = [
            URLQueryItem(name: "blobs", value: "true")
        ]
        return components.url
    }

    private func validate(_ response: URLResponse) throws {
        guard let response = response as? HTTPURLResponse else {
            return
        }

        guard (200..<300).contains(response.statusCode) else {
            throw SourceError.requestFailed(response.statusCode)
        }
    }
}
