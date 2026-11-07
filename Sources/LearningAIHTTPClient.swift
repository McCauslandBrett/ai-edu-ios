import Foundation

enum LearningAIServiceError: LocalizedError {
    case noWriting
    case invalidImage
    case service(String)

    var errorDescription: String? {
        switch self {
        case .noWriting: return "Write on the assignment before asking for a grade."
        case .invalidImage: return "The handwriting image could not be prepared."
        case .service(let message): return message
        }
    }
}

/// Owns base URL configuration, JSON encoding, HTTP calls, and API error decoding.
struct LearningAIHTTPClient {
    private static let requestTimeout: TimeInterval = 600
    private let baseURL: URL
    private let session: URLSession

    init(baseURL: URL? = nil) {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = Self.requestTimeout
        configuration.timeoutIntervalForResource = Self.requestTimeout
        self.session = URLSession(configuration: configuration)
        let configured = Bundle.main.object(forInfoDictionaryKey: "GRADING_API_BASE_URL") as? String
            ?? "http://192.168.1.211:3100"
        self.baseURL = baseURL ?? URL(string: configured) ?? URL(string: "http://192.168.1.211:3100")!
    }

    func post<Body: Encodable, Result: Decodable>(_ path: String, body: Body) async throws -> Result {
        let endpoint = baseURL.appendingPathComponent(path)
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = Self.requestTimeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError {
            throw map(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw LearningAIServiceError.service("The AI service returned an invalid response.")
        }
        guard (200..<300).contains(http.statusCode) else {
            let message = (try? JSONDecoder().decode(LearningAIServiceErrorResponse.self, from: data).error)
                ?? "AI service error (HTTP \(http.statusCode))."
            throw LearningAIServiceError.service(message)
        }
        do {
            return try JSONDecoder().decode(Result.self, from: data)
        } catch {
            throw LearningAIServiceError.service("The AI service response could not be read.")
        }
    }

    private func map(_ error: URLError) -> LearningAIServiceError {
        switch error.code {
        case .timedOut:
            return .service("The Learning AI Service did not finish within 10 minutes. Check its Terminal window for an error, then try again.")
        case .cannotConnectToHost, .cannotFindHost, .networkConnectionLost, .notConnectedToInternet:
            return .service("Can't reach the Learning AI Service at \(baseURL.absoluteString). Start it with start-learning-ai-service.command and keep that Terminal window open.")
        default:
            return .service(error.localizedDescription)
        }
    }
}


struct LearningAIServiceErrorResponse: Decodable {
    let error: String
}
