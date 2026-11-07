import Foundation
import Combine

@MainActor
final class StudentProfileStore: ObservableObject {
    @Published private(set) var students: [StudentProfile]
    @Published private(set) var subjectPlans: [String: StudentSubjectPlan]
    @Published private(set) var retryAssignments: [Assignment]
    @Published private(set) var activityEvents: [StudentActivityEvent]
    @Published var selectedStudentID: String {
        didSet { persistence.saveSelectedStudentID(selectedStudentID) }
    }

    private let persistence: StudentProfilePersistence

    init(persistence: StudentProfilePersistence = StudentProfilePersistence()) {
        self.persistence = persistence
        let initialStudents = persistence.loadStudents()
        self.students = initialStudents
        self.subjectPlans = persistence.loadSubjectPlans()
        self.retryAssignments = persistence.loadRetryAssignments()
        self.activityEvents = persistence.loadActivityEvents()
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

    func addRetryAssignment(_ assignment: Assignment) {
        guard assignment.studentID != nil else { return }
        retryAssignments.append(assignment)
        persist()
    }

    func recordGrade(_ grade: AssignmentGrade, for assignment: Assignment, studentID: String) {
        activityEvents.append(StudentActivityEvent(studentID: studentID, assignment: assignment, grade: grade))
        updateSubjectPlanResults(grade, for: assignment, studentID: studentID)
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
        updateCompetencyProgress(in: &saved)
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
        subjectPlans.removeValue(forKey: StudentSubjectPlan.key(studentID: studentID, subject: subject))
        persist()
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
        sampleAssignments(for: student, subject: subject)
            + generatedAssignments(for: student, subject: subject)
            + retryAttempts(for: student, subject: subject)
    }

    private func sampleAssignments(for student: StudentProfile, subject: String?) -> [Assignment] {
        guard isExampleStudent(student) else { return [] }
        return Assignment.samples.filter { assignment in
            if let subject {
                return subjectsMatch(subject, assignment.subject)
            }
            return student.subjects.contains { subjectsMatch($0, assignment.subject) }
        }
    }

    private func generatedAssignments(for student: StudentProfile, subject: String?) -> [Assignment] {
        subjectPlans.values
            .filter { saved in
                saved.studentID == student.id && planMatchesSubject(saved, subject: subject)
            }
            .flatMap { assignments(from: $0) }
    }

    private func assignments(from saved: StudentSubjectPlan) -> [Assignment] {
        let trackedSkills = saved.plan.progress.map(\.subject)
        return saved.plan.weeks.flatMap { week in
            let assessment = week.assessment.makeAssignment(
                studentID: saved.studentID,
                subject: saved.subject,
                weekNumber: week.weekNumber,
                assessment: true,
                trackedSkills: trackedSkills
            )
            let assignments = week.assignments.map {
                $0.makeAssignment(
                    studentID: saved.studentID,
                    subject: saved.subject,
                    weekNumber: week.weekNumber,
                    trackedSkills: trackedSkills
                )
            }
            return [assessment] + assignments
        }
    }

    private func retryAttempts(for student: StudentProfile, subject: String?) -> [Assignment] {
        retryAssignments.filter { retry in
            retry.studentID == student.id && subjectMatches(retry.subject, requestedSubject: subject)
        }
    }

    private func isExampleStudent(_ student: StudentProfile) -> Bool {
        StudentProfile.examples.contains { $0.id == student.id }
    }

    private func planMatchesSubject(_ plan: StudentSubjectPlan, subject: String?) -> Bool {
        guard let subject else { return true }
        return plan.subject.caseInsensitiveCompare(subject) == .orderedSame
    }

    private func subjectMatches(_ subject: String, requestedSubject: String?) -> Bool {
        guard let requestedSubject else { return true }
        return subject.caseInsensitiveCompare(requestedSubject) == .orderedSame
    }

    private func subjectsMatch(_ lhs: String, _ rhs: String) -> Bool {
        lhs.localizedCaseInsensitiveContains(rhs) || rhs.localizedCaseInsensitiveContains(lhs)
    }

    private func updateCompetencyProgress(in saved: inout StudentSubjectPlan) {
        let planAssignments = assignments(from: saved)
        let relatedRetries = retryAssignments.filter {
            $0.studentID == saved.studentID && $0.subject.caseInsensitiveCompare(saved.subject) == .orderedSame
        }
        let allAssignments = planAssignments + relatedRetries
        let skillTotals = questionCounts(in: allAssignments)
        let results = saved.competencyResults ?? [:]

        for index in saved.plan.progress.indices {
            var progress = saved.plan.progress[index]
            let skill = progress.subject
            updateProgress(
                for: &progress,
                assignments: allAssignments,
                skillTotal: skillTotals[skill] ?? 0,
                results: results
            )
            saved.plan.progress[index] = progress
        }
    }

    private func updateProgress(
        for progress: inout GeneratedLearningPlan.Progress,
        assignments: [Assignment],
        skillTotal: Int,
        results: [String: [Bool]]
    ) {
        guard skillTotal > 0 else { return }
        let gradedAssignments = assignments.filter {
            $0.questionSkills?.contains(progress.subject) == true && results[$0.id] != nil
        }
        guard !gradedAssignments.isEmpty else { return }

        let correctCount = correctAnswers(
            for: progress.subject,
            in: gradedAssignments,
            results: results
        )
        let completion = min(100, Double(correctCount) / Double(skillTotal) * 100)
        progress.completion = completion
        progress.status = completion >= 80 ? "Competent" : "Developing"
        progress.nextMilestone = nextMilestone(for: progress.subject, completion: completion)
    }

    private func correctAnswers(
        for skill: String,
        in assignments: [Assignment],
        results: [String: [Bool]]
    ) -> Int {
        assignments.reduce(0) { total, assignment in
            let flags = results[assignment.id] ?? []
            let skills = assignment.questionSkills ?? []
            let correct = flags.enumerated().filter { questionIndex, isCorrect in
                isCorrect && skills.indices.contains(questionIndex) && skills[questionIndex] == skill
            }.count
            return total + correct
        }
    }

    private func nextMilestone(for skill: String, completion: Double) -> String {
        completion >= 80
            ? "Apply \(skill) in a new context"
            : "Practice more \(skill) questions"
    }

    private func questionCounts(in assignments: [Assignment]) -> [String: Int] {
        assignments.reduce(into: [:]) { counts, assignment in
            for skill in assignment.questionSkills ?? [] {
                counts[skill, default: 0] += 1
            }
        }
    }

    private func persist() {
        persistence.save(
            students: students,
            subjectPlans: subjectPlans,
            retryAssignments: retryAssignments,
            activityEvents: activityEvents
        )
    }
}

