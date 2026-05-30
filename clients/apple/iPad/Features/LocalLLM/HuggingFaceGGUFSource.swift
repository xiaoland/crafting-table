import Foundation

struct HuggingFaceModelInfo: Decodable, Equatable {
    struct CardData: Decodable, Equatable {
        var license: String?
        var baseModel: String?

        enum CodingKeys: String, CodingKey {
            case license
            case baseModel = "base_model"
        }
    }

    struct Sibling: Decodable, Equatable {
        struct LFS: Decodable, Equatable {
            var sha256: String?
            var size: Int64?
        }

        var rfilename: String
        var size: Int64?
        var blobId: String?
        var lfs: LFS?
    }

    var id: String
    var sha: String?
    var privateRepository: Bool?
    var gated: BoolOrString?
    var tags: [String]?
    var cardData: CardData?
    var siblings: [Sibling]?

    enum CodingKeys: String, CodingKey {
        case id
        case sha
        case privateRepository = "private"
        case gated
        case tags
        case cardData
        case siblings
    }
}

extension HuggingFaceModelInfo {
    var isPublicUngated: Bool {
        privateRepository != true && gated?.isTruthy != true
    }

    var license: String? {
        cardData?.license ?? tags?
            .first { $0.hasPrefix("license:") }?
            .replacingOccurrences(of: "license:", with: "")
    }

    var ggufFiles: [HuggingFaceGGUFFile] {
        (siblings ?? [])
            .filter { $0.rfilename.lowercased().hasSuffix(".gguf") }
            .map { sibling in
                HuggingFaceGGUFFile(
                    repositoryID: id,
                    revision: sha ?? "main",
                    filename: sibling.rfilename,
                    fileSize: sibling.lfs?.size ?? sibling.size,
                    sha256: sibling.lfs?.sha256,
                    license: license
                )
            }
    }
}

struct HuggingFaceGGUFFile: Identifiable, Equatable {
    var repositoryID: String
    var revision: String
    var filename: String
    var fileSize: Int64?
    var sha256: String?
    var license: String?

    var id: String {
        "\(repositoryID):\(revision):\(filename)"
    }

    func modelRecord(now: Date = Date()) -> LocalLLMModelRecord {
        LocalLLMModelRecord.huggingFaceGGUF(
            repositoryID: repositoryID,
            revision: revision,
            filename: filename,
            license: license,
            fileSize: fileSize,
            sha256: sha256,
            now: now
        )
    }
}

enum BoolOrString: Decodable, Equatable {
    case bool(Bool)
    case string(String)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else {
            self = .string(try container.decode(String.self))
        }
    }

    var isTruthy: Bool {
        switch self {
        case .bool(let value):
            return value
        case .string(let value):
            return value.isEmpty == false && value.lowercased() != "false"
        }
    }
}
