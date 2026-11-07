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
    var questionIllustrations: [String]? = nil
    var writingSpaceMultipliers: [Double]? = nil
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
            parentAssignmentID: parentAssignmentID,
            questionIllustrations: questionIllustrations,
            writingSpaceMultipliers: writingSpaceMultipliers
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


struct AssignmentAdjustmentRequest: Encodable {
    let student: AIStudentContext
    let assignment: Assignment
    let changeRequest: String
}

struct AssignmentAdjustmentResponse: Decodable {
    let id: String
    let title: String
    let subject: String
    let dueDate: String
    let points: Int
    let prompt: String
    let questions: [String]
    let questionSkills: [String]
    let questionIllustrations: [String]?
    let writingSpaceMultipliers: [Double]?
    let answerKey: [String]
    let rubric: String
    let status: String
    let studentID: String?
    let parentAssignmentID: String?

    func makeAssignment() -> Assignment {
        Assignment(
            id: id, subject: subject, title: title, dueDate: dueDate, points: points,
            prompt: prompt, questions: questions, answerKey: answerKey, rubric: rubric, status: status,
            questionSkills: questionSkills, studentID: studentID, parentAssignmentID: parentAssignmentID,
            questionIllustrations: questionIllustrations, writingSpaceMultipliers: writingSpaceMultipliers
        )
    }
}
