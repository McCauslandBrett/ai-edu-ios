import Combine
import Foundation
import PencilKit
import UIKit

protocol TutorChatProviding {
    func send(_ request: TutorChatRequest) async throws -> TutorChatResponse
}

@MainActor
final class TutorChatSessionModel: ObservableObject {
    @Published private(set) var messages: [TutorChatMessage] = []
    @Published private(set) var canvasItems: [String] = []
    @Published private(set) var illustration: UIImage?
    @Published var drawing = PKDrawing()
    @Published private(set) var isSending = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var illustrationError: String?
    @Published private(set) var tutorTurnCount = 0
    @Published private(set) var sessionReadyToComplete = false
    @Published private(set) var completionReason: String?
    @Published private(set) var didCompleteSession = false

    private let student: StudentProfile
    private let subject: String
    private let weekNumber: Int
    private let lecturePrompt: String
    private let service: any TutorChatProviding
    private let maximumTutorTurns = 5

    init(
        student: StudentProfile,
        subject: String,
        weekNumber: Int,
        lecturePrompt: String,
        service: any TutorChatProviding = TutorChatService()
    ) {
        self.student = student
        self.subject = subject
        self.weekNumber = weekNumber
        self.lecturePrompt = lecturePrompt
        self.service = service
    }

    func beginLesson(speak: (String) -> Void) async {
        guard messages.isEmpty else { return }
        messages.append(TutorChatMessage(
            role: .user,
            text: "Start the lesson by greeting the student and asking one engaging first question.",
            isVisible: false
        ))
        await send(action: nil, imageBase64: nil, speak: speak)
    }

    @discardableResult
    func receiveTranscript(_ transcript: String) -> Bool {
        let text = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isSending else { return false }
        messages.append(TutorChatMessage(role: .user, text: text))
        errorMessage = nil
        return true
    }

    func send(action: String? = nil, imageBase64: String?, speak: (String) -> Void) async {
        guard !isSending, !sessionReadyToComplete else { return }
        isSending = true
        errorMessage = nil
        defer { isSending = false }

        let request = TutorChatRequest(
            student: AIStudentContext(name: student.name, age: student.age, gradeLevel: student.gradeLevel),
            subject: subject,
            weekNumber: weekNumber,
            lecturePrompt: lecturePrompt,
            action: action,
            tutorTurnCount: tutorTurnCount,
            messages: messages.suffix(24).map { TutorChatRequest.Message(role: $0.role.rawValue, content: $0.text) },
            canvasItems: canvasItems,
            imageBase64: imageBase64
        )

        do {
            let response = try await service.send(request)
            tutorTurnCount += 1
            if response.sessionComplete || tutorTurnCount >= maximumTutorTurns {
                sessionReadyToComplete = true
                completionReason = response.completionReason ?? "Finished after \(tutorTurnCount) tutor turns."
            }
            messages.append(TutorChatMessage(role: .assistant, text: response.reply))
            canvasItems = Array((canvasItems + response.canvasItems).suffix(12))
            speak(response.reply)
            if action != "check-whiteboard",
               let encodedImage = response.imageBase64,
               let imageData = Data(base64Encoded: encodedImage),
               let newIllustration = UIImage(data: imageData) {
                illustration = newIllustration
                drawing = PKDrawing()
            }
            illustrationError = response.imageError
        } catch {
            errorMessage = error.localizedDescription
            speak("I couldn't reach your tutor. Please ask a grown-up to help.")
        }
    }

    @discardableResult
    func complete(profiles: StudentProfileStore) -> Bool {
        guard sessionReadyToComplete, !didCompleteSession else { return false }
        didCompleteSession = true
        profiles.recordTutorSession(
            studentID: student.id,
            subject: subject,
            weekNumber: weekNumber,
            tutorTurnCount: tutorTurnCount,
            completionReason: completionReason ?? "Tutor session completed."
        )
        return true
    }
}
