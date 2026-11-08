import Foundation

// Only the network error referenced by model validation is needed in this model-only runner.
enum LearningAIServiceError: Error { case service(String) }

@main
struct AssignmentCompletionTests {
    @MainActor
    static func main() throws {
        let suite = "AssignmentCompletionTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let persistence = StudentProfilePersistence(defaults: defaults)
        let store = StudentProfileStore(persistence: persistence)
        let student = store.selectedStudent
        let plan = MEPSubject.catalog[0].makePlan(studentID: student.id)
        store.saveSubjectPlan(plan)
        let assignment = store.assignments(for: student, subject: plan.subject)[0]
        let originalSkills = store.subjectPlan(for: student.id, subject: plan.subject)!.plan.progress.map(\.completion)
        assert(!store.isAssignmentComplete(assignment, studentID: student.id))
        store.setAssignmentComplete(true, for: assignment, studentID: student.id)
        store.setAssignmentComplete(true, for: assignment, studentID: student.id)
        assert(store.activity(for: student.id).filter { $0.manuallyCompleted == true }.count == 1)
        assert(store.isAssignmentComplete(assignment, studentID: student.id))
        assert(!store.isAssignmentComplete(assignment, studentID: "another-student"))
        assert(store.subjectPlan(for: student.id, subject: plan.subject)!.plan.progress.map(\.completion) == originalSkills)
        let restored = StudentProfileStore(persistence: persistence)
        assert(restored.isAssignmentComplete(assignment, studentID: student.id))
        let grade = AssignmentGrade(score: 0, total: 1, overallFeedback: "Review", needsHumanReview: false, items: [])
        restored.recordGrade(grade, for: assignment, studentID: student.id)
        restored.setAssignmentComplete(false, for: assignment, studentID: student.id)
        restored.setAssignmentComplete(false, for: assignment, studentID: student.id)
        assert(!restored.isAssignmentComplete(assignment, studentID: student.id))
        assert(restored.activity(for: student.id).count == 1, "Undo must preserve grade history")
        assert(!StudentProfileStore(persistence: persistence).isAssignmentComplete(assignment, studentID: student.id))
        // Old activity records remain decodable after adding optional completion fields.
        let event = StudentActivityEvent(studentID: student.id, assignment: assignment, grade: grade)
        var legacy = try JSONSerialization.jsonObject(with: JSONEncoder().encode(event)) as! [String: Any]
        legacy.removeValue(forKey: "assignmentID")
        legacy.removeValue(forKey: "manuallyCompleted")
        let decoded = try JSONDecoder().decode(StudentActivityEvent.self, from: JSONSerialization.data(withJSONObject: legacy))
        assert(decoded.manuallyCompleted == nil && decoded.assignmentID == nil)
        print("PASS: completion, duplicate prevention, student isolation, persistence, undo, grade separation, legacy decoding")
    }
}
