import Foundation
import Combine

@MainActor
final class StudentProfileStore: ObservableObject {
    @Published private(set) var students: [StudentProfile]
    @Published private(set) var subjectPlans: [String: StudentSubjectPlan]
    @Published var selectedStudentID: String {
        didSet { persistence.saveSelectedStudentID(selectedStudentID) }
    }

    private let persistence: StudentProfilePersistence

    init(persistence: StudentProfilePersistence = StudentProfilePersistence()) {
        self.persistence = persistence
        let initialStudents = persistence.loadStudents()
        self.students = initialStudents
        self.subjectPlans = persistence.loadSubjectPlans()
        self.selectedStudentID = persistence.loadSelectedStudentID(fallback: initialStudents.first?.id ?? "student-1")
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

    func deleteSubject(studentID: String, subject: String) {
        guard let studentIndex = students.firstIndex(where: { $0.id == studentID }) else { return }
        students[studentIndex].subjects.removeAll { $0.caseInsensitiveCompare(subject) == .orderedSame }
        subjectPlans.removeValue(forKey: StudentSubjectPlan.key(studentID: studentID, subject: subject))
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
        persistence.save(students: students, subjectPlans: subjectPlans)
    }
}

