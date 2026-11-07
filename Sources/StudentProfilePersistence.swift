import Foundation

/// Reads and writes the app's local student and subject-plan records.
struct StudentProfilePersistence {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadStudents() -> [StudentProfile] {
        guard let decoded = decode([StudentProfile].self, for: Key.students), !decoded.isEmpty else {
            return StudentProfile.examples
        }
        return migrateStarterProfiles(in: decoded)
    }

    private func migrateStarterProfiles(in profiles: [StudentProfile]) -> [StudentProfile] {
        var migrated = profiles
        var didChange = false
        for index in migrated.indices where isUneditedStarterProfile(migrated[index]) {
            migrated[index].gradeLevel = "Not set"
            migrated[index].subjects = []
            migrated[index].summary = ""
            didChange = true
        }
        if didChange {
            saveEncoded(migrated, for: Key.students)
        }
        return migrated
    }

    private func isUneditedStarterProfile(_ profile: StudentProfile) -> Bool {
        profile.gradeLevel == "Grade 3" &&
            profile.subjects == ["Reading", "Mathematics"] &&
            profile.summary == "Keep building confidence with steady practice."
    }

    func loadSubjectPlans() -> [String: StudentSubjectPlan] {
        decode([String: StudentSubjectPlan].self, for: Key.subjectPlans) ?? [:]
    }

    func loadRetryAssignments() -> [Assignment] {
        decode([Assignment].self, for: Key.retryAssignments) ?? []
    }

    func loadActivityEvents() -> [StudentActivityEvent] {
        decode([StudentActivityEvent].self, for: Key.activityEvents) ?? []
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
        saveEncoded(students, for: Key.students)
        saveEncoded(subjectPlans, for: Key.subjectPlans)
        saveEncoded(retryAssignments, for: Key.retryAssignments)
        saveEncoded(activityEvents, for: Key.activityEvents)
    }

    private func decode<Value: Decodable>(_ type: Value.Type, for key: String) -> Value? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private func saveEncoded<Value: Encodable>(_ value: Value, for key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: key)
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
