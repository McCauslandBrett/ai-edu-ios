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

struct StudentLearningPlan {
    let subject: String
    let focus: String
    let month: String
    let milestones: [LearningMilestone]
    let progress: [SubjectProgress]

    static func forStudent(_ id: String, subject: String) -> StudentLearningPlan {
        let base = forStudent(id)
        if base.subject.caseInsensitiveCompare(subject) == .orderedSame {
            return base
        }

        let key = subject.lowercased()
        let focus: String
        let skills: [String]
        if key.contains("science") || key.contains("biology") {
            focus = "Build strong explanations by connecting observations, concepts, and evidence in \(subject.lowercased())."
            skills = ["Core concepts", "Evidence and observations", "Scientific explanations"]
        } else if key.contains("writing") {
            focus = "Organize ideas clearly and support writing with details, revision, and strong sentences."
            skills = ["Organization", "Sentence craft", "Revision and evidence"]
        } else if key.contains("social") || key.contains("history") {
            focus = "Use sources and context to explain important people, places, and events in \(subject.lowercased())."
            skills = ["Key ideas", "Source evidence", "Cause and effect"]
        } else if key.contains("research") {
            focus = "Develop research questions, evaluate sources, and communicate findings clearly."
            skills = ["Research questions", "Source evaluation", "Share findings"]
        } else if key.contains("read") {
            focus = "Strengthen comprehension by using text evidence, vocabulary, and clear summaries."
            skills = ["Comprehension", "Vocabulary", "Text evidence"]
        } else {
            focus = "Build confidence in \(subject.lowercased()) through focused practice and reflection."
            skills = ["Foundations", "Guided practice", "Explain your thinking"]
        }

        return StudentLearningPlan(
            subject: subject,
            focus: focus,
            month: "November 2026",
            milestones: [
                .init(id: "\(id)-\(key)-1", title: "\(subject) baseline check", date: "Nov 4", kind: "Assessment"),
                .init(id: "\(id)-\(key)-2", title: "\(subject) guided practice", date: "Nov 11", kind: "Assignment"),
                .init(id: "\(id)-\(key)-3", title: "\(subject) progress review", date: "Nov 22", kind: "Review")
            ],
            progress: skills.enumerated().map { index, skill in
                let completion = [68, 57, 74][index]
                return SubjectProgress(
                    subject: skill,
                    completion: completion,
                    nextMilestone: ["Review key ideas", "Practice with examples", "Show what you learned"][index],
                    status: completion >= 70 ? "On track" : "Practice"
                )
            }
        )
    }

    static func forStudent(_ id: String) -> StudentLearningPlan {
        switch id {
        case "student-2":
            return .init(subject: "Reading", focus: "Increase inference and evidence-based reading comprehension.", month: "November 2026", milestones: [
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
            return .init(subject: "Algebra", focus: "Improve algebraic thinking with expressions, variables, and equations.", month: "November 2026", milestones: [
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
            return .init(subject: "Mathematics", focus: "Master fraction reasoning and measurement fluency.", month: "November 2026", milestones: [
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


struct SubjectPlanInputs: Codable {
    let targetedSkills: [String]
    let learningOutcome: String
    let highestAssessmentLevel: String
    let priorAssessmentResults: [String]
    let instructorContext: String
}

struct StudentSubjectPlan: Codable, Identifiable {
    let studentID: String
    let subject: String
    let inputs: SubjectPlanInputs
    let plan: GeneratedLearningPlan

    var id: String { Self.key(studentID: studentID, subject: subject) }

    static func key(studentID: String, subject: String) -> String {
        studentID + "::" + subject.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

@MainActor
final class StudentProfileStore: ObservableObject {
    @Published private(set) var students: [StudentProfile]
    @Published private(set) var subjectPlans: [String: StudentSubjectPlan]
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
        if let data = UserDefaults.standard.data(forKey: "studentSubjectPlans"),
           let savedPlans = try? JSONDecoder().decode([String: StudentSubjectPlan].self, from: data) {
            self.subjectPlans = savedPlans
        } else {
            self.subjectPlans = [:]
        }
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

    func saveSubjectPlan(_ subjectPlan: StudentSubjectPlan) {
        subjectPlans[subjectPlan.id] = subjectPlan
        if var profile = students.first(where: { $0.id == subjectPlan.studentID }),
           !profile.subjects.contains(where: { $0.caseInsensitiveCompare(subjectPlan.subject) == .orderedSame }) {
            profile.subjects.append(subjectPlan.subject)
            if let index = students.firstIndex(where: { $0.id == profile.id }) {
                students[index] = profile
            }
        }
        persist()
    }

    func subjectPlan(for studentID: String, subject: String) -> StudentSubjectPlan? {
        subjectPlans[StudentSubjectPlan.key(studentID: studentID, subject: subject)]
    }

    func assignments(for student: StudentProfile, subject: String? = nil) -> [Assignment] {
        let matches: (String) -> Bool = { candidate in
            guard let subject else {
                return student.subjects.contains(where: {
                    $0.localizedCaseInsensitiveContains(candidate) || candidate.localizedCaseInsensitiveContains($0)
                })
            }
            return subject.localizedCaseInsensitiveContains(candidate) || candidate.localizedCaseInsensitiveContains(subject)
        }
        let samples = Assignment.samples.filter { matches($0.subject) }
        let generated = subjectPlans.values
            .filter { saved in
                saved.studentID == student.id && (subject.map { saved.subject.caseInsensitiveCompare($0) == .orderedSame } ?? true)
            }
            .flatMap { saved in
                saved.plan.weeks.flatMap { week in
                    week.assignments.map {
                        $0.makeAssignment(studentID: student.id, subject: saved.subject, weekNumber: week.weekNumber)
                    }
                }
            }
        return samples + generated
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(students) {
            UserDefaults.standard.set(data, forKey: "studentProfiles")
        }
        if let data = try? JSONEncoder().encode(subjectPlans) {
            UserDefaults.standard.set(data, forKey: "studentSubjectPlans")
        }
    }
}
