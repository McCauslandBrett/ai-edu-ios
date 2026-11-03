import Foundation

/// Reads and writes the app's local student and subject-plan records.
struct StudentProfilePersistence {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadStudents() -> [StudentProfile] {
        guard let data = defaults.data(forKey: Key.students),
              let saved = try? JSONDecoder().decode([StudentProfile].self, from: data),
              !saved.isEmpty else {
            return StudentProfile.examples
        }
        return saved
    }

    func loadSubjectPlans() -> [String: StudentSubjectPlan] {
        guard let data = defaults.data(forKey: Key.subjectPlans),
              let saved = try? JSONDecoder().decode([String: StudentSubjectPlan].self, from: data) else {
            return [:]
        }
        return saved
    }

    func loadSelectedStudentID(fallback: String) -> String {
        defaults.string(forKey: Key.selectedStudentID) ?? fallback
    }

    func save(students: [StudentProfile], subjectPlans: [String: StudentSubjectPlan]) {
        if let data = try? JSONEncoder().encode(students) {
            defaults.set(data, forKey: Key.students)
        }
        if let data = try? JSONEncoder().encode(subjectPlans) {
            defaults.set(data, forKey: Key.subjectPlans)
        }
    }

    func saveSelectedStudentID(_ id: String) {
        defaults.set(id, forKey: Key.selectedStudentID)
    }

    private enum Key {
        static let students = "studentProfiles"
        static let subjectPlans = "studentSubjectPlans"
        static let selectedStudentID = "selectedStudentID"
    }
}
