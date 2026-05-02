import Foundation
import Network

final class LocalLLMHTTPServer {
    typealias ModelsProvider = () async -> [LocalLLMModelRecord]
    typealias GenerateHandler = (LocalLLMGenerationRequest) async throws -> LocalLLMGenerationResult

    enum ServerError: LocalizedError {
        case invalidPort
        case missingRequestLine
        case invalidRequest
        case unauthorized
        case unsupportedRoute
        case unsupportedMethod
        case malformedBody

        var errorDescription: String? {
            switch self {
            case .invalidPort:
                return "The HTTP server port is invalid."
            case .missingRequestLine:
                return "The HTTP request is missing a request line."
            case .invalidRequest:
                return "The HTTP request is invalid."
            case .unauthorized:
                return "Bearer authorization is required."
            case .unsupportedRoute:
                return "The requested route is not supported."
            case .unsupportedMethod:
                return "The HTTP method is not supported for this route."
            case .malformedBody:
                return "The request body could not be decoded."
            }
        }
    }

    private var listener: NWListener?
    private let queue = DispatchQueue(label: "dev.lanzhijiang.CraftingTable.LocalLLMHTTPServer")

    private var bearerToken: String = ""
    private var modelsProvider: ModelsProvider = { [] }
    private var generateHandler: GenerateHandler = { _ in
        throw ServerError.unsupportedRoute
    }

    var isListening: Bool {
        listener != nil
    }

    func start(
        port: UInt16,
        bearerToken: String,
        modelsProvider: @escaping ModelsProvider,
        generateHandler: @escaping GenerateHandler
    ) throws {
        guard let endpointPort = NWEndpoint.Port(rawValue: port) else {
            throw ServerError.invalidPort
        }

        stop()

        self.bearerToken = bearerToken
        self.modelsProvider = modelsProvider
        self.generateHandler = generateHandler

        let listener = try NWListener(using: .tcp, on: endpointPort)
        listener.newConnectionHandler = { [weak self] connection in
            self?.handle(connection)
        }
        listener.start(queue: queue)
        self.listener = listener
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    private func handle(_ connection: NWConnection) {
        connection.start(queue: queue)
        receiveRequest(on: connection, buffer: Data())
    }

    private func receiveRequest(on connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, isComplete, error in
            guard let self else {
                connection.cancel()
                return
            }

            if error != nil || isComplete {
                connection.cancel()
                return
            }

            var nextBuffer = buffer
            if let data {
                nextBuffer.append(data)
            }

            if let request = HTTPRequest(data: nextBuffer) {
                Task {
                    let response = await self.route(request)
                    self.send(response, on: connection)
                }
            } else {
                self.receiveRequest(on: connection, buffer: nextBuffer)
            }
        }
    }

    private func route(_ request: HTTPRequest) async -> HTTPResponse {
        do {
            guard request.isAuthorized(with: bearerToken) else {
                throw ServerError.unauthorized
            }

            switch (request.method, request.path) {
            case ("GET", "/health"):
                return .json(status: 200, body: HealthResponse(status: "ok"))
            case ("GET", "/v1/models"):
                let models = await modelsProvider()
                return .json(status: 200, body: OpenAIModelsListResponse.from(models: models))
            case ("POST", "/v1/responses"):
                let createRequest = try request.decodeBody(OpenAIResponseCreateRequest.self)
                let result = try await generateHandler(createRequest.generationRequest())
                return .json(status: 200, body: OpenAIResponseObject.completed(from: result))
            case (_, "/health"), (_, "/v1/models"), (_, "/v1/responses"):
                throw ServerError.unsupportedMethod
            default:
                throw ServerError.unsupportedRoute
            }
        } catch ServerError.unauthorized {
            return .json(status: 401, body: ErrorResponse(error: "unauthorized", message: ServerError.unauthorized.localizedDescription))
        } catch ServerError.unsupportedMethod {
            return .json(status: 405, body: ErrorResponse(error: "method_not_allowed", message: ServerError.unsupportedMethod.localizedDescription))
        } catch ServerError.unsupportedRoute {
            return .json(status: 404, body: ErrorResponse(error: "not_found", message: ServerError.unsupportedRoute.localizedDescription))
        } catch {
            return .json(status: 400, body: ErrorResponse(error: "bad_request", message: error.localizedDescription))
        }
    }

    private func send(_ response: HTTPResponse, on connection: NWConnection) {
        connection.send(content: response.data, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
}

private struct HTTPRequest {
    var method: String
    var path: String
    var headers: [String: String]
    var body: Data

    init?(data: Data) {
        guard let headerRange = data.range(of: Data("\r\n\r\n".utf8)) else {
            return nil
        }

        let headerData = data[..<headerRange.lowerBound]
        guard let headerText = String(data: headerData, encoding: .utf8) else {
            return nil
        }

        let lines = headerText.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else {
            return nil
        }

        let requestParts = requestLine.split(separator: " ", maxSplits: 2).map(String.init)
        guard requestParts.count >= 2 else {
            return nil
        }

        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            let parts = line.split(separator: ":", maxSplits: 1).map(String.init)
            guard parts.count == 2 else {
                continue
            }

            headers[parts[0].lowercased()] = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let bodyStart = headerRange.upperBound
        let bodyLength = Int(headers["content-length"] ?? "0") ?? 0
        guard data.count >= bodyStart + bodyLength else {
            return nil
        }

        self.method = requestParts[0]
        self.path = URLComponents(string: requestParts[1])?.path ?? requestParts[1]
        self.headers = headers
        self.body = Data(data[bodyStart..<(bodyStart + bodyLength)])
    }

    func isAuthorized(with token: String) -> Bool {
        guard token.isEmpty == false,
              let authorization = headers["authorization"]
        else {
            return false
        }

        return authorization == "Bearer \(token)"
    }

    func decodeBody<T: Decodable>(_ type: T.Type) throws -> T {
        guard body.isEmpty == false else {
            throw LocalLLMHTTPServer.ServerError.malformedBody
        }

        return try JSONDecoder().decode(T.self, from: body)
    }
}

private struct HTTPResponse {
    var data: Data

    static func json<T: Encodable>(status: Int, body: T) -> HTTPResponse {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let bodyData = (try? encoder.encode(body)) ?? Data()
        let reason = HTTPStatusReason.reason(for: status)
        let headers = [
            "HTTP/1.1 \(status) \(reason)",
            "Content-Type: application/json; charset=utf-8",
            "Content-Length: \(bodyData.count)",
            "Connection: close",
            "",
            ""
        ].joined(separator: "\r\n")

        var data = Data(headers.utf8)
        data.append(bodyData)
        return HTTPResponse(data: data)
    }
}

private enum HTTPStatusReason {
    static func reason(for status: Int) -> String {
        switch status {
        case 200:
            return "OK"
        case 400:
            return "Bad Request"
        case 401:
            return "Unauthorized"
        case 404:
            return "Not Found"
        case 405:
            return "Method Not Allowed"
        default:
            return "Internal Server Error"
        }
    }
}

private struct HealthResponse: Encodable {
    var status: String
}

private struct ErrorResponse: Encodable {
    var error: String
    var message: String
}

struct OpenAIModelsListResponse: Encodable, Equatable {
    struct Model: Encodable, Equatable {
        var id: String
        var object: String
        var created: Int
        var ownedBy: String

        enum CodingKeys: String, CodingKey {
            case id
            case object
            case created
            case ownedBy = "owned_by"
        }
    }

    var object: String
    var data: [Model]
}

extension OpenAIModelsListResponse {
    static func from(models: [LocalLLMModelRecord], date: Date = Date()) -> OpenAIModelsListResponse {
        OpenAIModelsListResponse(
            object: "list",
            data: models.map { model in
                Model(
                    id: model.id,
                    object: "model",
                    created: Int(model.createdAt.timeIntervalSince1970),
                    ownedBy: model.source.title
                )
            }
        )
    }
}
