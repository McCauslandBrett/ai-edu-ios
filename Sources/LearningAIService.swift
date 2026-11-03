import Foundation
import PencilKit
import UIKit

struct AIStudentContext: Codable {
    let name: String
    let age: Int?
    let gradeLevel: String
}

struct AssignmentGrade: Codable, Equatable {
    struct Item: Codable, Equatable, Identifiable {
        var id: String { question }
        let question: String
        let studentAnswer: String
        let expectedAnswer: String
        let isCorrect: Bool
        let pointsAwarded: Double
        let feedback: String
    }

    let score: Double
    let total: Double
    let overallFeedback: String
    let needsHumanReview: Bool
    let items: [Item]
}

struct AssignmentGenerationRequest: Encodable {
    let student: AIStudentContext
    let subject: String
    let topic: String
    let objective: String
    let count: Int
    let pointsPerAssignment: Int
}

struct GeneratedAssignment: Codable, Identifiable {
    let id: String
    let title: String
    let subject: String
    let prompt: String
    let questions: [String]
    let answerKey: [String]
    let rubric: String
    let points: Int

    func makeAssignment(dueDate: String = "Unscheduled") -> Assignment {
        Assignment(
            id: id,
            subject: subject,
            title: title,
            dueDate: dueDate,
            points: points,
            prompt: prompt,
            questions: questions,
            answerKey: answerKey,
            rubric: rubric,
            status: "Not started"
        )
    }
}

struct GeneratedAssignmentsResponse: Decodable {
    let assignments: [GeneratedAssignment]
}

struct LearningPlanGenerationRequest: Encodable {
    let student: AIStudentContext
    let subject: String
    let objective: String
    let monthlyWindow: String
    let targetedSkills: [String]
    let highestAssessmentLevel: String
    let priorResults: [String]
    let instructorContext: String
}

struct GeneratedLearningPlan: Codable {
    struct Milestone: Codable, Identifiable {
        let id: String
        let title: String
        let date: String
        let kind: String
    }
    struct Progress: Codable, Identifiable {
        var id: String { subject }
        let subject: String
        let completion: Double
        let nextMilestone: String
        let status: String
    }

    let subject: String
    let objective: String
    let monthlyWindow: String
    struct PlannedActivity: Codable, Identifiable {
        let id: String
        let title: String
        let subject: String
        let prompt: String
        let questions: [String]
        let answerKey: [String]
        let rubric: String
        let points: Int

        func makeAssignment(studentID: String, subject: String, weekNumber: Int, assessment: Bool = false) -> Assignment {
            let safeSubject = subject.lowercased().unicodeScalars.map {
                CharacterSet.alphanumerics.contains($0) ? String($0) : "-"
            }.joined()
            return Assignment(
                id: ([studentID, safeSubject, String(weekNumber), id]).joined(separator: "-"),
                subject: subject,
                title: title,
                dueDate: "Week \(weekNumber)",
                points: points,
                prompt: prompt,
                questions: questions,
                answerKey: answerKey,
                rubric: rubric,
                status: assessment ? "Assessment" : "Not started"
            )
        }
    }

    struct Week: Codable, Identifiable {
        var id: Int { weekNumber }
        let weekNumber: Int
        let theme: String
        let lecturePrompt: String
        let assessment: PlannedActivity
        let assignments: [PlannedActivity]
    }

    let milestones: [Milestone]
    let progress: [Progress]
    let weeks: [Week]

    var learningPlan: StudentLearningPlan {
        StudentLearningPlan(
            subject: subject,
            focus: objective,
            month: monthlyWindow,
            milestones: milestones.map {
                LearningMilestone(id: $0.id, title: $0.title, date: $0.date, kind: $0.kind)
            },
            progress: progress.map {
                SubjectProgress(
                    subject: $0.subject,
                    completion: Int($0.completion.rounded()),
                    nextMilestone: $0.nextMilestone,
                    status: $0.status
                )
            }
        )
    }
}

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

struct LearningAIService {
    private let baseURL: URL

    init() {
        let configured = Bundle.main.object(forInfoDictionaryKey: "GRADING_API_BASE_URL") as? String
            ?? "http://192.168.1.211:3100"
        baseURL = URL(string: configured) ?? URL(string: "http://192.168.1.211:3100")!
    }

    func grade(_ assignment: Assignment, student: StudentProfile, drawing: PKDrawing) async throws -> AssignmentGrade {
        guard !drawing.bounds.isNull, !drawing.bounds.isEmpty else { throw LearningAIServiceError.noWriting }
        let bounds = drawing.bounds.insetBy(dx: -16, dy: -16)
        let renderer = UIGraphicsImageRenderer(size: bounds.size)
        let image = renderer.image { context in
            UIColor.white.setFill()
            context.cgContext.fill(CGRect(origin: .zero, size: bounds.size))
            drawing.image(from: bounds, scale: 2).draw(in: CGRect(origin: .zero, size: bounds.size))
        }
        guard let imageData = image.pngData() else { throw LearningAIServiceError.invalidImage }
        let body = GradeRequest(
            student: AIStudentContext(name: student.name, age: student.age, gradeLevel: student.gradeLevel),
            assignment: GradeRequest.AssignmentPayload(
                id: assignment.id,
                subject: assignment.subject,
                title: assignment.title,
                prompt: assignment.prompt,
                questions: assignment.questions,
                answerKey: assignment.answerKey,
                rubric: assignment.rubric,
                points: assignment.points
            ),
            imageBase64: imageData.base64EncodedString()
        )
        return try await post("api/grade", body: body)
    }

    func generateAssignments(_ request: AssignmentGenerationRequest) async throws -> [GeneratedAssignment] {
        let response: GeneratedAssignmentsResponse = try await post("api/assignments/generate", body: request)
        return response.assignments
    }

    func generatePlan(_ request: LearningPlanGenerationRequest) async throws -> GeneratedLearningPlan {
        let plan: GeneratedLearningPlan = try await post("api/plans/generate", body: request)
        guard plan.weeks.count == 4,
              plan.weeks.enumerated().allSatisfy({ $0.offset + 1 == $0.element.weekNumber && !$0.element.assignments.isEmpty }) else {
            throw LearningAIServiceError.service("The generated plan must include four complete weeks, each with an assessment, lecture prompt, and assignment.")
        }
        return plan
    }

    private func post<Body: Encodable, Result: Decodable>(_ path: String, body: Body) async throws -> Result {
        let endpoint = baseURL.appendingPathComponent(path)
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 300
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch let error as URLError {
            switch error.code {
            case .timedOut:
                throw LearningAIServiceError.service("The grader did not finish within five minutes. Check the Learning AI Service Terminal window for an error, then try again.")
            case .cannotConnectToHost, .cannotFindHost, .networkConnectionLost, .notConnectedToInternet:
                throw LearningAIServiceError.service("Can't reach the Learning AI Service at \(baseURL.host ?? "the configured address"):3100. Start it with start-learning-ai-service.command and keep that Terminal window open.")
            default:
                throw LearningAIServiceError.service(error.localizedDescription)
            }
        }
        guard let http = response as? HTTPURLResponse else {
            throw LearningAIServiceError.service("The AI service returned an invalid response.")
        }
        guard (200..<300).contains(http.statusCode) else {
            let message = (try? JSONDecoder().decode(ServiceError.self, from: data).error)
                ?? "AI service error (HTTP \(http.statusCode))."
            throw LearningAIServiceError.service(message)
        }
        do {
            return try JSONDecoder().decode(Result.self, from: data)
        } catch {
            throw LearningAIServiceError.service("The AI service response could not be read.")
        }
    }

    private struct GradeRequest: Encodable {
        struct AssignmentPayload: Encodable {
            let id: String
            let subject: String
            let title: String
            let prompt: String
            let questions: [String]
            let answerKey: [String]
            let rubric: String
            let points: Int
        }
        let student: AIStudentContext
        let assignment: AssignmentPayload
        let imageBase64: String
    }

    private struct ServiceError: Decodable { let error: String }
}
