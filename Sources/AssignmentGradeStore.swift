import Foundation

/// Persists AI grading results by assignment ID on this device.
struct AssignmentGradeStore {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load(assignmentID: String) -> AssignmentGrade? {
        guard let data = defaults.data(forKey: key(for: assignmentID)) else { return nil }
        return try? JSONDecoder().decode(AssignmentGrade.self, from: data)
    }

    func save(_ grade: AssignmentGrade, assignmentID: String) {
        guard let data = try? JSONEncoder().encode(grade) else { return }
        defaults.set(data, forKey: key(for: assignmentID))
    }

    func delete(assignmentID: String) {
        defaults.removeObject(forKey: key(for: assignmentID))
    }

    private func key(for assignmentID: String) -> String {
        "assignment-grade-\(assignmentID)"
    }
}
