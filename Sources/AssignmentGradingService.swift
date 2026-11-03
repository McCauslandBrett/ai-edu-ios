import PencilKit

/// Coordinates handwriting preparation and the assignment-grading API operation.
struct AssignmentGradingService {
    private let client: LearningAIHTTPClient

    init(client: LearningAIHTTPClient = LearningAIHTTPClient()) {
        self.client = client
    }

    func grade(_ assignment: Assignment, student: StudentProfile, drawing: PKDrawing) async throws -> AssignmentGrade {
        let imageData = try HandwritingImageEncoder.pngData(from: drawing)
        let request = GradeRequest(
            student: AIStudentContext(name: student.name, age: student.age, gradeLevel: student.gradeLevel),
            assignment: GradeRequest.AssignmentPayload(
                id: assignment.id,
                subject: assignment.subject,
                title: assignment.title,
                prompt: assignment.prompt,
                questions: assignment.questions,
                answerKey: assignment.answerKey,
                rubric: assignment.rubric,
                points: assignment.points
            ),
            imageBase64: imageData.base64EncodedString()
        )
        return try await client.post("api/grade", body: request)
    }
}
