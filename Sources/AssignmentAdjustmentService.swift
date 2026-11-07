import Foundation

struct AssignmentAdjustmentService {
    private let client: LearningAIHTTPClient

    init(client: LearningAIHTTPClient = LearningAIHTTPClient()) {
        self.client = client
    }

    func adjust(_ assignment: Assignment, for student: StudentProfile, request: String) async throws -> Assignment {
        let body = AssignmentAdjustmentRequest(
            student: AIStudentContext(name: student.name, age: student.age, gradeLevel: student.gradeLevel),
            assignment: assignment,
            changeRequest: request
        )
        let response: AssignmentAdjustmentResponse = try await client.post("api/assignments/adjust", body: body)
        return response.makeAssignment()
    }
}
