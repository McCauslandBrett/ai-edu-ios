import Foundation

struct TutorChatMessage: Identifiable {
    enum Role: String, Equatable {
        case user
        case assistant
    }

    let id = UUID()
    let role: Role
    let text: String
    var isVisible = true
}

struct TutorChatRequest: Encodable {
    struct Message: Encodable {
        let role: String
        let content: String
    }

    let student: AIStudentContext
    let subject: String
    let weekNumber: Int
    let lecturePrompt: String
    let action: String?
    let tutorTurnCount: Int
    let messages: [Message]
    let canvasItems: [String]
    let imageBase64: String?
}

struct TutorChatResponse: Decodable {
    let reply: String
    let canvasItems: [String]
    let imageBase64: String?
    let imageError: String?
    let sessionComplete: Bool
    let completionReason: String?
}

private struct TutorTranscriptionRequest: Encodable {
    let audioBase64: String
    let mimeType = "audio/mp4"
}

private struct TutorTranscriptionResponse: Decodable {
    let text: String
}

struct TutorChatService {
    private let client: LearningAIHTTPClient

    init(client: LearningAIHTTPClient = LearningAIHTTPClient()) {
        self.client = client
    }

    func send(_ request: TutorChatRequest) async throws -> TutorChatResponse {
        try await client.post("api/tutor/chat", body: request)
    }

    func transcribe(audio: Data) async throws -> String {
        let request = TutorTranscriptionRequest(audioBase64: audio.base64EncodedString())
        let response: TutorTranscriptionResponse = try await client.post("api/tutor/transcribe", body: request)
        return response.text
    }
}
