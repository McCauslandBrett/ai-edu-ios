/// Sends requests for original assignments and returns the generated assignment models.
struct AssignmentGenerationService: AssignmentGenerationProviding {
    private let client: LearningAIHTTPClient

    init(client: LearningAIHTTPClient = LearningAIHTTPClient()) {
        self.client = client
    }

    func generate(_ request: AssignmentGenerationRequest) async throws -> [GeneratedAssignment] {
        let response: GeneratedAssignmentsResponse = try await client.post("api/assignments/generate", body: request)
        return response.assignments
    }
}
