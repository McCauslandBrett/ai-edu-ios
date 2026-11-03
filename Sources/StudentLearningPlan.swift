import Foundation

struct StudentLearningPlan {
    let subject: String
    let focus: String
    let month: String
    let milestones: [LearningMilestone]
    let progress: [SubjectProgress]
}
