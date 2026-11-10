import Foundation

struct StudentAssignmentState {
    let retryAssignments: [Assignment]
    let activityEvents: [StudentActivityEvent]
    let overrides: [String: Assignment]
}

/// Removes only assignment history that belongs to a plan being replaced or deleted.
struct StudentAssignmentStateCleaner {
    private let assignmentCatalog: StudentAssignmentCatalog

    init(assignmentCatalog: StudentAssignmentCatalog = StudentAssignmentCatalog()) {
        self.assignmentCatalog = assignmentCatalog
    }

    func assignmentsToClean(for plan: StudentSubjectPlan, retries: [Assignment]) -> [Assignment] {
        var assignments = assignmentsIncludingLegacyIDs(for: plan)
        let planIDs = Set(assignments.map(\.id))
        assignments.append(contentsOf: retries.filter { assignment in
            guard assignment.studentID == plan.studentID else { return false }
            return planIDs.contains(assignment.id)
                || assignment.parentAssignmentID.map(planIDs.contains) == true
                || historicalSubjectNames(for: plan).contains(normalizedSubjectName(assignment.subject))
        })
        var addedIDs = Set<String>()
        return assignments.filter { addedIDs.insert($0.id).inserted }
    }

    func removingState(for plan: StudentSubjectPlan, from state: StudentAssignmentState) -> StudentAssignmentState {
        let assignmentIDs = Set(assignmentsIncludingLegacyIDs(for: plan).map(\.id))
        guard !assignmentIDs.isEmpty else { return state }
        let subjectNames = historicalSubjectNames(for: plan)
        let retries = state.retryAssignments.filter { assignment in
            guard assignment.studentID == plan.studentID else { return true }
            return !assignmentIDs.contains(assignment.id)
                && assignment.parentAssignmentID.map(assignmentIDs.contains) != true
                && !subjectNames.contains(normalizedSubjectName(assignment.subject))
        }
        let events = state.activityEvents.filter { event in
            guard event.studentID == plan.studentID else { return true }
            return event.assignmentID.map(assignmentIDs.contains) != true
                && !subjectNames.contains(normalizedSubjectName(event.subject))
        }
        let overrides = state.overrides.filter { _, assignment in
            assignment.studentID != plan.studentID || !assignmentIDs.contains(assignment.id)
        }
        return StudentAssignmentState(retryAssignments: retries, activityEvents: events, overrides: overrides)
    }

    private func assignmentsIncludingLegacyIDs(for plan: StudentSubjectPlan) -> [Assignment] {
        assignmentCatalog.assignments(from: plan).flatMap { assignment in
            let legacyID = assignment.id.replacingOccurrences(of: "-mep-v3-y", with: "-mep-y")
            guard legacyID != assignment.id else { return [assignment] }
            return [assignment, assignment.reidentified(as: legacyID)]
        }
    }

    private func historicalSubjectNames(for plan: StudentSubjectPlan) -> Set<String> {
        var names = [normalizedSubjectName(plan.subject)]
        guard let prebuiltID = plan.prebuiltSubjectID else { return Set(names) }
        let level = prebuiltID
            .replacingOccurrences(of: "mep-year-", with: "")
            .replacingOccurrences(of: "-math", with: "")
        names.append(normalizedSubjectName("Year \(level) Math"))
        return Set(names)
    }

    private func normalizedSubjectName(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

