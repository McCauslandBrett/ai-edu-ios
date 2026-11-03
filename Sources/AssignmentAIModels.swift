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

    var correctCount: Int { items.filter(\.isCorrect).count }
    var questionCount: Int { items.count }
    var isPassing: Bool {
        questionCount > 0 && Double(correctCount) / Double(questionCount) >= 0.8
    }
}

struct AssignmentGenerationRequest: Encodable {
    let student: AIStudentContext
    let subject: String
    let topic: String
    let objective: String
    let count: Int
    let pointsPerAssignment: Int
    let targetedSkills: [String]
}

struct GeneratedAssignment: Codable, Identifiable {
    let id: String
    let title: String
    let subject: String
    let prompt: String
    let questions: [String]
    let questionSkills: [String]
    let answerKey: [String]
    let rubric: String
    let points: Int

    func makeAssignment(
        dueDate: String = "Unscheduled",
        studentID: String? = nil,
        parentAssignmentID: String? = nil,
        titlePrefix: String = ""
    ) -> Assignment {
        Assignment(
            id: id,
            subject: subject,
            title: titlePrefix + title,
            dueDate: dueDate,
            points: points,
            prompt: prompt,
            questions: questions,
            answerKey: answerKey,
            rubric: rubric,
            status: "Not started",
            questionSkills: questionSkills,
            studentID: studentID,
            parentAssignmentID: parentAssignmentID
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
