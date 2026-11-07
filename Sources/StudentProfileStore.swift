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

        if let skills = assignment.questionSkills,
           skills.count == assignment.questions.count,
           grade.items.count == assignment.questions.count,
           let key = subjectPlans.keys.first(where: { candidate in
               guard let saved = subjectPlans[candidate] else { return false }
               return saved.studentID == studentID && saved.subject.caseInsensitiveCompare(assignment.subject) == .orderedSame
           }),
           var saved = subjectPlans[key] {
            var results = saved.competencyResults ?? [:]
            results[assignment.id] = grade.items.map(\.isCorrect)
            saved.competencyResults = results
            updateCompetencyProgress(in: &saved)
            subjectPlans[key] = saved
        }
        persist()
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
                let trackedSkills = saved.plan.progress.map(\.subject)
                return saved.plan.weeks.flatMap { week in
                    [week.assessment.makeAssignment(
                        studentID: student.id,
                        subject: saved.subject,
                        weekNumber: week.weekNumber,
                        assessment: true,
                        trackedSkills: trackedSkills
                    )] + week.assignments.map {
                        $0.makeAssignment(
                            studentID: student.id,
                            subject: saved.subject,
                            weekNumber: week.weekNumber,
                            trackedSkills: trackedSkills
                        )
                    }
                }
            }
        let retries = retryAssignments.filter { retry in
            retry.studentID == student.id && (subject.map {
                retry.subject.caseInsensitiveCompare($0) == .orderedSame
            } ?? true)
        }
        return samples + generated + retries
    }

    private func updateCompetencyProgress(in saved: inout StudentSubjectPlan) {
        let studentID = saved.studentID
        let subject = saved.subject
        let planAssignments = saved.plan.weeks.flatMap { week -> [Assignment] in
            let trackedSkills = saved.plan.progress.map(\.subject)
            return [week.assessment.makeAssignment(
                studentID: studentID,
                subject: subject,
                weekNumber: week.weekNumber,
                assessment: true,
                trackedSkills: trackedSkills
            )] + week.assignments.map {
                $0.makeAssignment(
                    studentID: studentID,
                    subject: subject,
                    weekNumber: week.weekNumber,
                    trackedSkills: trackedSkills
                )
            }
        }
        let relatedRetries = retryAssignments.filter {
            $0.studentID == studentID && $0.subject.caseInsensitiveCompare(subject) == .orderedSame
        }
        let allAssignments = planAssignments + relatedRetries
        let skillTotals = questionCounts(in: allAssignments)
        let results = saved.competencyResults ?? [:]

        for index in saved.plan.progress.indices {
            let skill = saved.plan.progress[index].subject
            let total = skillTotals[skill] ?? 0
            guard total > 0 else { continue }
            let gradedAssignments = allAssignments.filter { $0.questionSkills?.contains(skill) == true && results[$0.id] != nil }
            guard !gradedAssignments.isEmpty else { continue }
            let correct = gradedAssignments.reduce(0) { partial, assignment in
                let flags = results[assignment.id] ?? []
                let questionSkills = assignment.questionSkills ?? []
                return partial + flags.enumerated().filter { questionIndex, isCorrect in
                    isCorrect && questionSkills.indices.contains(questionIndex) && questionSkills[questionIndex] == skill
                }.count
            }
            let completion = min(100, Double(correct) / Double(total) * 100)
            saved.plan.progress[index].completion = completion
            saved.plan.progress[index].status = completion >= 80 ? "Competent" : "Developing"
            saved.plan.progress[index].nextMilestone = completion >= 80
                ? "Apply \(skill) in a new context"
                : "Practice more \(skill) questions"
        }
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

