import Foundation

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

struct GradeRequest: Encodable {
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
