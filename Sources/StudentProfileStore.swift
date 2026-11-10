import Foundation
import Combine

@MainActor
final class StudentProfileStore: ObservableObject {
    @Published private(set) var students: [StudentProfile]
    @Published private(set) var subjectPlans: [String: StudentSubjectPlan]
    @Published private(set) var retryAssignments: [Assignment]
    @Published private(set) var activityEvents: [StudentActivityEvent]
    @Published private(set) var assignmentOverrides: [String: Assignment]
    @Published var selectedStudentID: String {
        didSet { persistence.saveSelectedStudentID(selectedStudentID) }
    }

    private let persistence: any StudentProfilePersisting
    private let assignmentCatalog = StudentAssignmentCatalog()
    private let assignmentStateCleaner = StudentAssignmentStateCleaner()
    private let curriculumPlanBuilder: any MEPCurriculumPlanBuilding

    init(
        persistence: any StudentProfilePersisting = StudentProfilePersistence(),
        curriculumPlanBuilder: any MEPCurriculumPlanBuilding = MEPCurriculumPlanBuilder()
    ) {
        self.persistence = persistence
        self.curriculumPlanBuilder = curriculumPlanBuilder
        var initialStudents = persistence.loadStudents()
        let loadedSubjectPlans = persistence.loadSubjectPlans()
        let migration = StudentSubjectPlanMigrator.migrate(
            loadedSubjectPlans,
            planBuilder: curriculumPlanBuilder
        )
        for studentIndex in initialStudents.indices {
            let studentID = initialStudents[studentIndex].id
            guard let renamedSubjects = migration.subjectRenames[studentID] else { continue }
            initialStudents[studentIndex].subjects = initialStudents[studentIndex].subjects.map { oldSubject in
                renamedSubjects.first(where: { $0.key.caseInsensitiveCompare(oldSubject) == .orderedSame })?.value ?? oldSubject
            }
        }
        self.students = initialStudents
        self.subjectPlans = migration.plans
        self.retryAssignments = persistence.loadRetryAssignments()
        self.activityEvents = persistence.loadActivityEvents()
        self.assignmentOverrides = persistence.loadAssignmentOverrides()
        self.selectedStudentID = persistence.loadSelectedStudentID(fallback: initialStudents.first?.id ?? "student-1")

        if migration.didChange {
            persistence.save(
                students: initialStudents,
                subjectPlans: migration.plans,
                retryAssignments: retryAssignments,
                activityEvents: activityEvents,
                assignmentOverrides: assignmentOverrides
            )
        }
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

    /// Adds a new prebuilt plan instance with its own subject name and activity identities.
    /// Selecting the same catalog item again therefore starts clean without changing earlier work.
    @discardableResult
    func addPrebuiltSubject(_ curriculum: MEPSubject, studentID: String) -> [Assignment] {
        guard students.contains(where: { $0.id == studentID }) else { return [] }
        let hasActiveLegacyCopy = subjectPlans.values.contains {
            $0.studentID == studentID && $0.prebuiltSubjectID == curriculum.id && $0.planInstanceID == nil
        }
        let legacyPlan = hasActiveLegacyCopy ? nil : curriculumPlanBuilder.build(
            subject: curriculum,
            studentID: studentID,
            subjectName: nil,
            planInstanceID: nil
        )
        let staleLegacyAssignments = legacyPlan.map {
            assignmentStateCleaner.assignmentsToClean(for: $0, retries: retryAssignments)
        } ?? []
        if let legacyPlan {
            removeAssignmentState(for: legacyPlan)
        }
        let usedNames = Set(
            students.first(where: { $0.id == studentID })?.subjects.map(normalizedSubjectName) ?? []
        ).union(
            subjectPlans.values
                .filter { $0.studentID == studentID }
                .map { normalizedSubjectName($0.subject) }
        )
        let subjectName = uniqueSubjectName(for: curriculum.name, usedNames: usedNames)
        let instanceID = UUID().uuidString.lowercased()
        saveSubjectPlan(curriculumPlanBuilder.build(
            subject: curriculum,
            studentID: studentID,
            subjectName: subjectName,
            planInstanceID: instanceID
        ))
        return staleLegacyAssignments
    }

    private func uniqueSubjectName(for baseName: String, usedNames: Set<String>) -> String {
        guard usedNames.contains(normalizedSubjectName(baseName)) else { return baseName }
        var copyNumber = 2
        while usedNames.contains(normalizedSubjectName("\(baseName) (\(copyNumber))")) {
            copyNumber += 1
        }
        return "\(baseName) (\(copyNumber))"
    }

    private func normalizedSubjectName(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    func saveAssignmentOverride(_ assignment: Assignment, studentID: String) {
        var studentAssignment = assignment
        studentAssignment.studentID = studentID
        assignmentOverrides[assignmentCatalog.overrideKey(assignment.id, studentID: studentID)] = studentAssignment
        if let index = retryAssignments.firstIndex(where: { $0.id == assignment.id && $0.studentID == studentID }) {
            retryAssignments[index] = studentAssignment
        }
        persist()
    }

    func assignmentWithSavedChanges(_ assignment: Assignment, studentID: String) -> Assignment {
        assignmentCatalog.applyOverrides(
            [assignment],
            studentID: studentID,
            overrides: assignmentOverrides
        ).first ?? assignment
    }

    func clearRecordedGrade(for assignment: Assignment, studentID: String) {
        guard let key = subjectPlanKey(for: assignment.subject, studentID: studentID),
              var saved = subjectPlans[key],
              var results = saved.competencyResults else { return }
        results.removeValue(forKey: assignment.id)
        saved.competencyResults = results
        refreshCompetencyProgress(in: &saved)
        subjectPlans[key] = saved
        persist()
    }

    func addRetryAssignment(_ assignment: Assignment) {
        guard assignment.studentID != nil else { return }
        retryAssignments.append(assignment)
        persist()
    }

    func isAssignmentComplete(_ assignment: Assignment, studentID: String) -> Bool {
        activityEvents.contains {
            $0.studentID == studentID && $0.assignmentID == assignment.id && $0.manuallyCompleted == true
        }
    }

    func setAssignmentComplete(_ complete: Bool, for assignment: Assignment, studentID: String) {
        guard assignment.studentID == nil || assignment.studentID == studentID else { return }
        guard isAssignmentComplete(assignment, studentID: studentID) != complete else { return }
        if complete {
            activityEvents.append(StudentActivityEvent(studentID: studentID, completedAssignment: assignment))
        } else {
            activityEvents.removeAll {
                $0.studentID == studentID && $0.assignmentID == assignment.id && $0.manuallyCompleted == true
            }
        }
        persist()
    }

    func recordGrade(_ grade: AssignmentGrade, for assignment: Assignment, studentID: String) {
        activityEvents.append(StudentActivityEvent(studentID: studentID, assignment: assignment, grade: grade))
        updateSubjectPlanResults(grade, for: assignment, studentID: studentID)
        persist()
    }

    func recordTutorSession(
        studentID: String,
        subject: String,
        weekNumber: Int,
        tutorTurnCount: Int,
        completionReason: String
    ) {
        activityEvents.append(StudentActivityEvent(
            studentID: studentID,
            subject: subject,
            weekNumber: weekNumber,
            tutorTurnCount: tutorTurnCount,
            completionReason: completionReason
        ))
        persist()
    }

    private func updateSubjectPlanResults(
        _ grade: AssignmentGrade,
        for assignment: Assignment,
        studentID: String
    ) {
        guard hasCompleteSkillMapping(for: assignment, grade: grade),
              let key = subjectPlanKey(for: assignment.subject, studentID: studentID),
              var saved = subjectPlans[key] else {
            return
        }

        var results = saved.competencyResults ?? [:]
        results[assignment.id] = grade.items.map(\.isCorrect)
        saved.competencyResults = results
        refreshCompetencyProgress(in: &saved)
        subjectPlans[key] = saved
    }

    private func hasCompleteSkillMapping(for assignment: Assignment, grade: AssignmentGrade) -> Bool {
        guard let skills = assignment.questionSkills else { return false }
        return skills.count == assignment.questions.count && grade.items.count == assignment.questions.count
    }

    private func subjectPlanKey(for subject: String, studentID: String) -> String? {
        subjectPlans.first(where: { entry in
            entry.value.studentID == studentID && entry.value.subject.caseInsensitiveCompare(subject) == .orderedSame
        })?.key
    }

    func activity(for studentID: String) -> [StudentActivityEvent] {
        activityEvents
            .filter { $0.studentID == studentID }
            .sorted { $0.recordedAt > $1.recordedAt }
    }

    func deleteSubject(studentID: String, subject: String) {
        guard let studentIndex = students.firstIndex(where: { $0.id == studentID }) else { return }
        students[studentIndex].subjects.removeAll { $0.caseInsensitiveCompare(subject) == .orderedSame }
        let planKey = StudentSubjectPlan.key(studentID: studentID, subject: subject)
        if let removedPlan = subjectPlans.removeValue(forKey: planKey) {
            removeAssignmentState(for: removedPlan)
        }
        retryAssignments.removeAll {
            $0.studentID == studentID && $0.subject.caseInsensitiveCompare(subject) == .orderedSame
        }
        activityEvents.removeAll {
            $0.studentID == studentID && $0.subject.caseInsensitiveCompare(subject) == .orderedSame
        }
        assignmentOverrides = assignmentOverrides.filter { _, assignment in
            assignment.studentID != studentID || assignment.subject.caseInsensitiveCompare(subject) != .orderedSame
        }
        persist()
    }

    private func removeAssignmentState(for plan: StudentSubjectPlan) {
        let currentState = StudentAssignmentState(
            retryAssignments: retryAssignments,
            activityEvents: activityEvents,
            overrides: assignmentOverrides
        )
        let cleanedState = assignmentStateCleaner.removingState(for: plan, from: currentState)
        retryAssignments = cleanedState.retryAssignments
        activityEvents = cleanedState.activityEvents
        assignmentOverrides = cleanedState.overrides
    }

    @discardableResult
    func deleteStudent(studentID: String) -> Bool {
        guard students.count > 1, students.contains(where: { $0.id == studentID }) else {
            return false
        }
        students.removeAll { $0.id == studentID }
        subjectPlans = subjectPlans.filter { $0.value.studentID != studentID }
        retryAssignments.removeAll { $0.studentID == studentID }
        activityEvents.removeAll { $0.studentID == studentID }
        assignmentOverrides = assignmentOverrides.filter { $0.value.studentID != studentID }
        if selectedStudentID == studentID, let nextStudent = students.first {
            selectedStudentID = nextStudent.id
        }
        persist()
        return true
    }

    func subjectPlan(for studentID: String, subject: String) -> StudentSubjectPlan? {
        subjectPlans[StudentSubjectPlan.key(studentID: studentID, subject: subject)]
    }

    func subjects(for student: StudentProfile) -> [String] {
        if StudentProfile.examples.contains(where: { $0.id == student.id }) {
            return student.subjects
        }
        return subjectPlans.values
            .filter { $0.studentID == student.id }
            .map(\.subject)
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    func assignments(for student: StudentProfile, subject: String? = nil) -> [Assignment] {
        assignmentCatalog.assignments(
            for: student,
            subject: subject,
            plans: Array(subjectPlans.values),
            retries: retryAssignments,
            overrides: assignmentOverrides
        )
    }

    private func refreshCompetencyProgress(in saved: inout StudentSubjectPlan) {
        let plannedAssignments = assignmentCatalog.assignments(from: saved)
        let relatedRetries = retryAssignments.filter {
            $0.studentID == saved.studentID && $0.subject.caseInsensitiveCompare(saved.subject) == .orderedSame
        }
        let allAssignments = assignmentCatalog.applyOverrides(
            plannedAssignments + relatedRetries,
            studentID: saved.studentID,
            overrides: assignmentOverrides
        )
        var plan = saved.plan
        SubjectCompetencyTracker().update(&plan, assignments: allAssignments, results: saved.competencyResults ?? [:])
        saved.plan = plan
    }

    private func persist() {
        persistence.save(
            students: students,
            subjectPlans: subjectPlans,
            retryAssignments: retryAssignments,
            activityEvents: activityEvents,
            assignmentOverrides: assignmentOverrides
        )
    }


}

