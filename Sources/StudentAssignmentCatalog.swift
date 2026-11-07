import Foundation

/// Builds the assignment list for one student from sample, plan, retry, and saved-edit data.
struct StudentAssignmentCatalog {
    func assignments(
        for student: StudentProfile,
        subject: String?,
        plans: [StudentSubjectPlan],
        retries: [Assignment],
        overrides: [String: Assignment]
    ) -> [Assignment] {
        let samples = sampleAssignments(for: student, subject: subject)
        let planned = plans
            .filter { $0.studentID == student.id && matches($0.subject, subject) }
            .flatMap(assignments(from:))
        let retryAttempts = retries.filter {
            $0.studentID == student.id && matches($0.subject, subject)
        }
        return applyOverrides(samples + planned + retryAttempts, studentID: student.id, overrides: overrides)
    }

    func assignments(from saved: StudentSubjectPlan) -> [Assignment] {
        let skills = saved.plan.progress.map(\.subject)
        return saved.plan.weeks.flatMap { week in
            let assessment = week.assessment.makeAssignment(
                studentID: saved.studentID,
                subject: saved.subject,
                weekNumber: week.weekNumber,
                assessment: true,
                trackedSkills: skills
            )
            let assignments = week.assignments.map {
                $0.makeAssignment(studentID: saved.studentID, subject: saved.subject, weekNumber: week.weekNumber, trackedSkills: skills)
            }
            return [assessment] + assignments
        }
    }

    func applyOverrides(
        _ assignments: [Assignment],
        studentID: String,
        overrides: [String: Assignment]
    ) -> [Assignment] {
        assignments.map { overrides[overrideKey($0.id, studentID: studentID)] ?? $0 }
    }

    func overrideKey(_ assignmentID: String, studentID: String) -> String {
        studentID + "::" + assignmentID
    }

    private func sampleAssignments(for student: StudentProfile, subject: String?) -> [Assignment] {
        guard StudentProfile.examples.contains(where: { $0.id == student.id }) else { return [] }
        return Assignment.samples.filter { assignment in
            if let subject { return subjectMatches(subject, assignment.subject) }
            return student.subjects.contains { subjectMatches($0, assignment.subject) }
        }
    }

    private func matches(_ value: String, _ requested: String?) -> Bool {
        guard let requested else { return true }
        return value.caseInsensitiveCompare(requested) == .orderedSame
    }

    private func subjectMatches(_ lhs: String, _ rhs: String) -> Bool {
        lhs.localizedCaseInsensitiveContains(rhs) || rhs.localizedCaseInsensitiveContains(lhs)
    }
}
