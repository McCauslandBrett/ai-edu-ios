import Foundation

import Foundation
import Combine

struct StudentProfile: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var age: Int?
    var gradeLevel: String
    var subjects: [String]
    var summary: String

    static let examples: [StudentProfile] = [
        .init(id: "student-1", name: "Avery Johnson", age: 10, gradeLevel: "Grade 5", subjects: ["Mathematics", "Science", "Reading"], summary: "Strong in reading and consistent in science. Fractions and problem-solving need extra practice."),
        .init(id: "student-2", name: "Mateo Ruiz", age: 9, gradeLevel: "Grade 4", subjects: ["Reading", "Writing", "Social Studies"], summary: "Reading comprehension is strong and writing remains steady. More structure will help in science explanations."),
        .init(id: "student-3", name: "Sofia Patel", age: 11, gradeLevel: "Grade 6", subjects: ["Algebra", "Biology", "Research"], summary: "Consistently resilient in problem-solving. Algebraic reasoning is improving with guided practice.")
    ]
}

struct SubjectProgress: Identifiable, Hashable {
    var id: String { subject }
    let subject: String
    let completion: Int
    let nextMilestone: String
    let status: String
}

struct LearningMilestone: Identifiable, Hashable {
    let id: String
    let title: String
    let date: String
    let kind: String
}

struct StudentActivityEvent: Identifiable, Codable, Hashable {
    enum Kind: String, Codable {
        case assignment
        case assessment
        case tutorSession
    }

    let id: String
    let studentID: String
    let kind: Kind
    let title: String
    let subject: String
    let recordedAt: Date
    let score: Double
    let total: Double
    let correctQuestions: Int
    let questionCount: Int
    let passed: Bool?
    let completionNote: String?

    init(studentID: String, assignment: Assignment, grade: AssignmentGrade, recordedAt: Date = .now) {
        id = UUID().uuidString
        self.studentID = studentID
        kind = assignment.isHomework ? .assignment : .assessment
        title = assignment.title
        subject = assignment.subject
        self.recordedAt = recordedAt
        score = grade.score
        total = grade.total
        correctQuestions = grade.correctCount
        questionCount = grade.questionCount
        passed = assignment.isHomework ? grade.isPassing : nil
        completionNote = nil
    }

    init(
        studentID: String,
        subject: String,
        weekNumber: Int,
        tutorTurnCount: Int,
        completionReason: String,
        recordedAt: Date = .now
    ) {
        id = UUID().uuidString
        self.studentID = studentID
        kind = .tutorSession
        title = "Week \(weekNumber) whiteboard tutor"
        self.subject = subject
        self.recordedAt = recordedAt
        score = 0
        total = 0
        correctQuestions = 0
        questionCount = tutorTurnCount
        passed = nil
        completionNote = completionReason
    }
}
