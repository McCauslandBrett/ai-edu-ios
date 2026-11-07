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

    func loadRetryAssignments() -> [Assignment] {
        guard let data = defaults.data(forKey: Key.retryAssignments),
              let saved = try? JSONDecoder().decode([Assignment].self, from: data) else {
            return []
        }
        return saved
    }

    func loadActivityEvents() -> [StudentActivityEvent] {
        guard let data = defaults.data(forKey: Key.activityEvents),
              let saved = try? JSONDecoder().decode([StudentActivityEvent].self, from: data) else {
            return []
        }
        return saved
    }

    func loadSelectedStudentID(fallback: String) -> String {
        defaults.string(forKey: Key.selectedStudentID) ?? fallback
    }

    func save(
        students: [StudentProfile],
        subjectPlans: [String: StudentSubjectPlan],
        retryAssignments: [Assignment],
        activityEvents: [StudentActivityEvent]
    ) {
        if let data = try? JSONEncoder().encode(students) {
            defaults.set(data, forKey: Key.students)
        }
        if let data = try? JSONEncoder().encode(subjectPlans) {
            defaults.set(data, forKey: Key.subjectPlans)
        }
        if let data = try? JSONEncoder().encode(retryAssignments) {
            defaults.set(data, forKey: Key.retryAssignments)
        }
        if let data = try? JSONEncoder().encode(activityEvents) {
            defaults.set(data, forKey: Key.activityEvents)
        }
    }

    func saveSelectedStudentID(_ id: String) {
        defaults.set(id, forKey: Key.selectedStudentID)
    }

    private enum Key {
        static let students = "studentProfiles"
        static let subjectPlans = "studentSubjectPlans"
        static let retryAssignments = "retryAssignments"
        static let activityEvents = "studentActivityEvents"
        static let selectedStudentID = "selectedStudentID"
    }
}
