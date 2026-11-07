import Foundation
import PencilKit
import Combine

@MainActor
final class AssignmentWorkspaceModel: ObservableObject {
    @Published private(set) var assignment: Assignment
    @Published private(set) var grade: AssignmentGrade?
    @Published private(set) var gradingError: String?
    @Published private(set) var retryError: String?
    @Published private(set) var retryAssignment: Assignment?
    @Published private(set) var isGrading = false
    @Published private(set) var isGeneratingRetry = false

    private let grader: any AssignmentGradingProviding
    private let generator: any AssignmentGenerationProviding
    private let adjuster: any AssignmentAdjusting
    private let gradeStore: any AssignmentGradePersisting
    private let maximumSkillCount = 12

    init(assignment: Assignment, dependencies: AssignmentWorkspaceDependencies = .live) {
        self.assignment = assignment
        self.grader = dependencies.grader
        self.generator = dependencies.generator
        self.adjuster = dependencies.adjuster
        self.gradeStore = dependencies.gradeStore
    }

    func restore(for profiles: StudentProfileStore, studentID: String) {
        assignment = profiles.assignmentWithSavedChanges(assignment, studentID: studentID)
        grade = gradeStore.load(assignmentID: assignment.id)
        retryAssignment = profiles.retryAssignments.last { $0.parentAssignmentID == assignment.id }
    }

    func gradeWork(student: StudentProfile, drawing: PKDrawing, profiles: StudentProfileStore) async {
        guard !isGrading else { return }
        isGrading = true
        gradingError = nil
        defer { isGrading = false }
        do {
            let result = try await grader.grade(assignment, student: student, drawing: drawing)
            grade = result
            gradeStore.save(result, assignmentID: assignment.id)
            profiles.recordGrade(result, for: assignment, studentID: student.id)
        } catch {
            gradingError = error.localizedDescription
        }
    }

    func applyChange(_ request: String, student: StudentProfile, profiles: StudentProfileStore) async throws {
        let adjusted = try await adjuster.adjust(assignment, for: student, request: request)
        let updated = Assignment(
            id: assignment.id,
            subject: adjusted.subject,
            title: adjusted.title,
            dueDate: adjusted.dueDate,
            points: adjusted.points,
            prompt: adjusted.prompt,
            questions: adjusted.questions,
            answerKey: adjusted.answerKey,
            rubric: adjusted.rubric,
            status: adjusted.status,
            questionSkills: adjusted.questionSkills,
            studentID: student.id,
            parentAssignmentID: assignment.parentAssignmentID,
            questionIllustrations: adjusted.questionIllustrations,
            writingSpaceMultipliers: adjusted.writingSpaceMultipliers
        )
        assignment = updated
        grade = nil
        gradeStore.delete(assignmentID: updated.id)
        profiles.clearRecordedGrade(for: updated, studentID: student.id)
        profiles.saveAssignmentOverride(updated, studentID: student.id)
    }

    func generateRetry(student: StudentProfile, profiles: StudentProfileStore) async {
        guard let grade, !isGeneratingRetry else { return }
        isGeneratingRetry = true
        retryError = nil
        defer { isGeneratingRetry = false }
        do {
            guard let generated = try await generator.generate(retryRequest(grade, student: student)).first else {
                throw LearningAIServiceError.service("The service did not return a new assignment attempt.")
            }
            let attempt = generated.makeAssignment(
                dueDate: "New attempt",
                studentID: student.id,
                parentAssignmentID: assignment.id,
                titlePrefix: "Retry · "
            )
            profiles.addRetryAssignment(attempt)
            retryAssignment = attempt
        } catch {
            retryError = error.localizedDescription
        }
    }

    private func retryRequest(_ grade: AssignmentGrade, student: StudentProfile) -> AssignmentGenerationRequest {
        let skills = failedSkills(in: grade)
        let feedback = grade.items
            .filter { !$0.isCorrect }
            .map { "Question: \($0.question). Feedback: \($0.feedback)" }
            .joined(separator: "\n")
        return AssignmentGenerationRequest(
            student: AIStudentContext(name: student.name, age: student.age, gradeLevel: student.gradeLevel),
            subject: assignment.subject,
            topic: assignment.title,
            objective: "Create a fresh new attempt. Focus on these skills: \(skills.joined(separator: ", ")). Use different questions from the original. Original assignment guidance: \(assignment.prompt). Grading feedback to address: \(feedback)",
            count: 1,
            pointsPerAssignment: assignment.points,
            targetedSkills: skills
        )
    }

    private func failedSkills(in grade: AssignmentGrade) -> [String] {
        let mappedSkills = assignment.questionSkills ?? []
        let failed = grade.items.enumerated().compactMap { index, item -> String? in
            guard !item.isCorrect, mappedSkills.indices.contains(index) else { return nil }
            return mappedSkills[index]
        }
        let unique = Array(NSOrderedSet(array: failed)) as? [String] ?? failed
        return unique.isEmpty ? [assignment.subject] : Array(unique.prefix(maximumSkillCount))
    }
}
