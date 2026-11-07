protocol LearningPlanGenerating {
    func generate(_ request: LearningPlanGenerationRequest) async throws -> GeneratedLearningPlan
}

/// Generates and validates the four-week plan returned by the curriculum API.
struct LearningPlanGenerationService: LearningPlanGenerating {
    private let client: LearningAIHTTPClient

    init(client: LearningAIHTTPClient = LearningAIHTTPClient()) {
        self.client = client
    }

    func generate(_ request: LearningPlanGenerationRequest) async throws -> GeneratedLearningPlan {
        let plan: GeneratedLearningPlan = try await client.post("api/plans/generate", body: request)
        try plan.validateFourWeekStructure()
        return plan
    }
}
