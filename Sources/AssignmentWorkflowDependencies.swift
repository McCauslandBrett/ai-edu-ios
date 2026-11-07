import PencilKit

protocol AssignmentGradingProviding {
    func grade(_ assignment: Assignment, student: StudentProfile, drawing: PKDrawing) async throws -> AssignmentGrade
}

protocol AssignmentGenerationProviding {
    func generate(_ request: AssignmentGenerationRequest) async throws -> [GeneratedAssignment]
}

protocol AssignmentAdjusting {
    func adjust(_ assignment: Assignment, for student: StudentProfile, request: String) async throws -> Assignment
}

protocol AssignmentGradePersisting {
    func load(assignmentID: String) -> AssignmentGrade?
    func save(_ grade: AssignmentGrade, assignmentID: String)
    func delete(assignmentID: String)
}

struct AssignmentWorkspaceDependencies {
    let grader: any AssignmentGradingProviding
    let generator: any AssignmentGenerationProviding
    let adjuster: any AssignmentAdjusting
    let gradeStore: any AssignmentGradePersisting

    static let live = AssignmentWorkspaceDependencies(
        grader: AssignmentGradingService(),
        generator: AssignmentGenerationService(),
        adjuster: AssignmentAdjustmentService(),
        gradeStore: AssignmentGradeStore()
    )
}
