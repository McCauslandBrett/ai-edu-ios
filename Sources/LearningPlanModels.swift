import Foundation

struct LearningPlanGenerationRequest: Encodable {
    let student: AIStudentContext
    let subject: String
    let objective: String
    let monthlyWindow: String
    let targetedSkills: [String]
    let highestAssessmentLevel: String
    let priorResults: [String]
    let instructorContext: String
}

struct GeneratedLearningPlan: Codable {
    struct Milestone: Codable, Identifiable {
        let id: String
        let title: String
        let date: String
        let kind: String
    }
    struct Progress: Codable, Identifiable {
        var id: String { subject }
        let subject: String
        var completion: Double
        var nextMilestone: String
        var status: String
    }

    let subject: String
    let objective: String
    let monthlyWindow: String
    struct PlannedActivity: Codable, Identifiable {
        let id: String
        let title: String
        let subject: String
        let prompt: String
        let questions: [String]
        var questionSkills: [String]? = nil
        var questionIllustrations: [String]? = nil
        var writingSpaceMultipliers: [Double]? = nil
        var resourceURL: String? = nil
        var resourceTitle: String? = nil
        let answerKey: [String]
        let rubric: String
        let points: Int

        func makeAssignment(
            studentID: String,
            subject: String,
            weekNumber: Int,
            assessment: Bool = false,
            trackedSkills: [String] = []
        ) -> Assignment {
            let safeSubject = subject.lowercased().unicodeScalars.map {
                CharacterSet.alphanumerics.contains($0) ? String($0) : "-"
            }.joined()
            let linkedSkills = questionSkills?.count == questions.count
                ? questionSkills!
                : questions.indices.map { index in
                    trackedSkills.isEmpty ? "Unassigned" : trackedSkills[index % trackedSkills.count]
                }
            return Assignment(
                id: ([studentID, safeSubject, String(weekNumber), id]).joined(separator: "-"),
                subject: subject,
                title: title,
                dueDate: "Week \(weekNumber)",
                points: points,
                prompt: prompt,
                questions: questions,
                answerKey: answerKey,
                rubric: rubric,
                status: assessment ? "Assessment" : "Not started",
                questionSkills: linkedSkills,
                studentID: studentID,
                questionIllustrations: questionIllustrations,
                writingSpaceMultipliers: writingSpaceMultipliers,
                resourceURL: resourceURL,
                resourceTitle: resourceTitle
            )
        }
    }

    struct SuggestedVideo: Codable, Hashable {
        let title: String
        let channel: String
        let url: String
        let reason: String

        var destination: URL? { URL(string: url) }
    }

    struct Week: Codable, Identifiable {
        var id: Int { weekNumber }
        let weekNumber: Int
        let theme: String
        let lecturePrompt: String
        var youtubeVideo: SuggestedVideo? = nil
        let assessment: PlannedActivity
        let assignments: [PlannedActivity]
    }

    let milestones: [Milestone]
    var progress: [Progress]
    let weeks: [Week]

    func validateFourWeekStructure() throws {
        guard weeks.count == 4,
              weeks.enumerated().allSatisfy({ $0.offset + 1 == $0.element.weekNumber && !$0.element.assignments.isEmpty }) else {
            throw LearningAIServiceError.service("The generated plan must include four complete weeks, each with an assessment, lecture prompt, and assignment.")
        }
    }

    var learningPlan: StudentLearningPlan {
        StudentLearningPlan(
            subject: subject,
            focus: objective,
            month: monthlyWindow,
            milestones: milestones.map {
                LearningMilestone(id: $0.id, title: $0.title, date: $0.date, kind: $0.kind)
            },
            progress: progress.map {
                SubjectProgress(
                    subject: $0.subject,
                    completion: Int($0.completion.rounded()),
                    nextMilestone: $0.nextMilestone,
                    status: $0.status
                )
            }
        )
    }
}
