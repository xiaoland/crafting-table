import Foundation

struct OpenAIResponseCreateRequest: Decodable, Equatable {
    var model: String?
    var input: OpenAIResponseInput
    var instructions: String?
    var maxOutputTokens: Int?
    var temperature: Double?
    var topP: Double?

    enum CodingKeys: String, CodingKey {
        case model
        case input
        case instructions
        case maxOutputTokens = "max_output_tokens"
        case temperature
        case topP = "top_p"
    }

    func generationRequest() -> LocalLLMGenerationRequest {
        LocalLLMGenerationRequest(
            modelID: model,
            input: input.plainText,
            instructions: instructions,
            maxOutputTokens: maxOutputTokens,
            temperature: temperature,
            topP: topP
        )
    }
}

enum OpenAIResponseInput: Decodable, Equatable {
    case text(String)
    case messages([OpenAIResponseMessage])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let text = try? container.decode(String.self) {
            self = .text(text)
        } else {
            self = .messages(try container.decode([OpenAIResponseMessage].self))
        }
    }

    var plainText: String {
        switch self {
        case .text(let text):
            return text
        case .messages(let messages):
            return messages
                .map { message in
                    let content = message.content.plainText
                    return content.isEmpty ? message.role : "\(message.role): \(content)"
                }
                .joined(separator: "\n")
        }
    }
}

struct OpenAIResponseMessage: Decodable, Equatable {
    var role: String
    var content: OpenAIResponseMessageContent
}

enum OpenAIResponseMessageContent: Decodable, Equatable {
    case text(String)
    case parts([OpenAIResponseContentPart])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let text = try? container.decode(String.self) {
            self = .text(text)
        } else {
            self = .parts(try container.decode([OpenAIResponseContentPart].self))
        }
    }

    var plainText: String {
        switch self {
        case .text(let text):
            return text
        case .parts(let parts):
            return parts.compactMap(\.text).joined(separator: "\n")
        }
    }
}

struct OpenAIResponseContentPart: Decodable, Equatable {
    var type: String?
    var text: String?
}

struct OpenAIResponseObject: Encodable, Equatable {
    struct OutputItem: Encodable, Equatable {
        var id: String
        var type: String
        var role: String
        var content: [ContentItem]
    }

    struct ContentItem: Encodable, Equatable {
        var type: String
        var text: String
    }

    struct Usage: Encodable, Equatable {
        var inputTokens: Int?
        var outputTokens: Int?
        var totalTokens: Int?

        enum CodingKeys: String, CodingKey {
            case inputTokens = "input_tokens"
            case outputTokens = "output_tokens"
            case totalTokens = "total_tokens"
        }
    }

    var id: String
    var object: String
    var createdAt: Int
    var status: String
    var model: String
    var output: [OutputItem]
    var outputText: String
    var usage: Usage?

    enum CodingKeys: String, CodingKey {
        case id
        case object
        case createdAt = "created_at"
        case status
        case model
        case output
        case outputText = "output_text"
        case usage
    }
}

extension OpenAIResponseObject {
    static func completed(from result: LocalLLMGenerationResult, date: Date = Date()) -> OpenAIResponseObject {
        OpenAIResponseObject(
            id: "resp_\(UUID().uuidString.lowercased())",
            object: "response",
            createdAt: Int(date.timeIntervalSince1970),
            status: "completed",
            model: result.modelID,
            output: [
                OutputItem(
                    id: "msg_\(UUID().uuidString.lowercased())",
                    type: "message",
                    role: "assistant",
                    content: [
                        ContentItem(type: "output_text", text: result.outputText)
                    ]
                )
            ],
            outputText: result.outputText,
            usage: Usage(
                inputTokens: result.inputTokens,
                outputTokens: result.outputTokens,
                totalTokens: totalTokens(input: result.inputTokens, output: result.outputTokens)
            )
        )
    }

    private static func totalTokens(input: Int?, output: Int?) -> Int? {
        guard input != nil || output != nil else {
            return nil
        }

        return (input ?? 0) + (output ?? 0)
    }
}
