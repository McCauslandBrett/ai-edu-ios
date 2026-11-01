import Foundation
import Combine

struct StudentProfile: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var gradeLevel: String
    var subjects: [String]
    var summary: String

    static let examples: [StudentProfile] = [
        .init(id: "student-1", name: "Avery Johnson", gradeLevel: "Grade 5", subjects: ["Mathematics", "Science", "Reading"], summary: "Strong in reading and consistent in science. Fractions and problem-solving need extra practice."),
        .init(id: "student-2", name: "Mateo Ruiz", gradeLevel: "Grade 4", subjects: ["Reading", "Writing", "Social Studies"], summary: "Reading comprehension is strong and writing remains steady. More structure will help in science explanations."),
        .init(id: "student-3", name: "Sofia Patel", gradeLevel: "Grade 6", subjects: ["Algebra", "Biology", "Research"], summary: "Consistently resilient in problem-solving. Algebraic reasoning is improving with guided practice.")
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

struct StudentLearningPlan {
    let focus: String
    let month: String
    let milestones: [LearningMilestone]
    let progress: [SubjectProgress]

    static func forStudent(_ id: String) -> StudentLearningPlan {
        switch id {
        case "student-2":
            return .init(focus: "Increase inference and evidence-based reading comprehension.", month: "November 2026", milestones: [
                .init(id: "m5", title: "Reading baseline", date: "Nov 3", kind: "Assessment"),
                .init(id: "m6", title: "Close reading task", date: "Nov 8", kind: "Assignment"),
                .init(id: "m7", title: "Guided discussion", date: "Nov 12", kind: "Lesson"),
                .init(id: "m8", title: "Reading check-in", date: "Nov 25", kind: "Review")
            ], progress: [
                .init(subject: "Inference", completion: 78, nextMilestone: "Support answers with text evidence", status: "On track"),
                .init(subject: "Vocabulary", completion: 64, nextMilestone: "Use context clues", status: "Practice"),
                .init(subject: "Summarization", completion: 81, nextMilestone: "Write concise summaries", status: "On track")
            ])
        case "student-3":
            return .init(focus: "Improve algebraic thinking with expressions, variables, and equations.", month: "November 2026", milestones: [
                .init(id: "m9", title: "Algebra check", date: "Nov 1", kind: "Assessment"),
                .init(id: "m10", title: "Solving equations", date: "Nov 6", kind: "Assignment"),
                .init(id: "m11", title: "Coaching session", date: "Nov 13", kind: "Lesson"),
                .init(id: "m12", title: "Final assessment", date: "Nov 24", kind: "Review")
            ], progress: [
                .init(subject: "Variables", completion: 83, nextMilestone: "Translate word problems", status: "On track"),
                .init(subject: "Equations", completion: 58, nextMilestone: "Balance operations carefully", status: "Practice"),
                .init(subject: "Patterns", completion: 45, nextMilestone: "Explain sequence rules", status: "Needs support")
            ])
        default:
            return .init(focus: "Master fraction reasoning and measurement fluency.", month: "November 2026", milestones: [
                .init(id: "m1", title: "Initial assessment", date: "Nov 2", kind: "Assessment"),
                .init(id: "m2", title: "Fractions worksheet", date: "Nov 5", kind: "Assignment"),
                .init(id: "m3", title: "Tutor lesson", date: "Nov 9", kind: "Lesson"),
                .init(id: "m4", title: "Final check-in", date: "Nov 20", kind: "Review")
            ], progress: [
                .init(subject: "Fractions", completion: 62, nextMilestone: "Equivalent fractions practice", status: "Practice"),
                .init(subject: "Measurement", completion: 80, nextMilestone: "Compare units and lengths", status: "On track"),
                .init(subject: "Word problems", completion: 48, nextMilestone: "Build a solving strategy", status: "Needs support")
            ])
        }
    }
}

@MainActor
final class StudentProfileStore: ObservableObject {
    @Published private(set) var students: [StudentProfile]
    @Published var selectedStudentID: String {
        didSet { UserDefaults.standard.set(selectedStudentID, forKey: "selectedStudentID") }
    }

    init() {
        let initialStudents: [StudentProfile]
        if let data = UserDefaults.standard.data(forKey: "studentProfiles"),
           let saved = try? JSONDecoder().decode([StudentProfile].self, from: data), !saved.isEmpty {
            initialStudents = saved
        } else {
            initialStudents = StudentProfile.examples
        }
        self.students = initialStudents
        self.selectedStudentID = UserDefaults.standard.string(forKey: "selectedStudentID")
            ?? initialStudents.first?.id ?? "student-1"
    }

    var selectedStudent: StudentProfile {
        students.first(where: { $0.id == selectedStudentID }) ?? students[0]
    }

    func save(_ profile: StudentProfile) {
        if let index = students.firstIndex(where: { $0.id == profile.id }) {
            students[index] = profile
        } else {
            students.append(profile)
            selectedStudentID = profile.id
        }
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(students) {
            UserDefaults.standard.set(data, forKey: "studentProfiles")
        }
    }
}
