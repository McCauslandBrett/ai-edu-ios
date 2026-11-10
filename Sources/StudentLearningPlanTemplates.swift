import Foundation

/// Provides placeholder plans while a subject is waiting for its first AI plan.
enum StudentLearningPlanTemplates {
    static func forStudent(_ id: String, subject: String) -> StudentLearningPlan {
        let base = forStudent(id)
        if base.subject.caseInsensitiveCompare(subject) == .orderedSame {
            return base
        }

        let key = subject.lowercased()
        let focus: String
        let skills: [String]
        if key.contains("science") || key.contains("biology") {
            focus = "Build strong explanations by connecting observations, concepts, and evidence in \(subject.lowercased())."
            skills = ["Core concepts", "Evidence and observations", "Scientific explanations"]
        } else if key.contains("writing") {
            focus = "Organize ideas clearly and support writing with details, revision, and strong sentences."
            skills = ["Organization", "Sentence craft", "Revision and evidence"]
        } else if key.contains("social") || key.contains("history") {
            focus = "Use sources and context to explain important people, places, and events in \(subject.lowercased())."
            skills = ["Key ideas", "Source evidence", "Cause and effect"]
        } else if key.contains("research") {
            focus = "Develop research questions, evaluate sources, and communicate findings clearly."
            skills = ["Research questions", "Source evaluation", "Share findings"]
        } else if key.contains("read") {
            focus = "Strengthen comprehension by using text evidence, vocabulary, and clear summaries."
            skills = ["Comprehension", "Vocabulary", "Text evidence"]
        } else {
            focus = "Build confidence in \(subject.lowercased()) through focused practice and reflection."
            skills = ["Foundations", "Guided practice", "Explain your thinking"]
        }

        return StudentLearningPlan(
            subject: subject,
            focus: focus,
            month: "November 2026",
            milestones: [
                .init(id: "\(id)-\(key)-1", title: "\(subject) baseline check", date: "Nov 4", kind: "Assessment"),
                .init(id: "\(id)-\(key)-2", title: "\(subject) guided practice", date: "Nov 11", kind: "Assignment"),
                .init(id: "\(id)-\(key)-3", title: "\(subject) progress review", date: "Nov 22", kind: "Review")
            ],
            progress: skills.enumerated().map { index, skill in
                let completion = [68, 57, 74][index]
                return SubjectProgress(
                    subject: skill,
                    completion: completion,
                    nextMilestone: ["Review key ideas", "Practice with examples", "Show what you learned"][index],
                    status: completion >= 70 ? "On track" : "Practice"
                )
            }
        )
    }

    static func forStudent(_ id: String) -> StudentLearningPlan {
        switch id {
        default:
            return .init(subject: "Mathematics", focus: "Master fraction reasoning and measurement fluency.", month: "November 2026", milestones: [
                .init(id: "m1", title: "Initial assessment", date: "Nov 2", kind: "Assessment"),
                .init(id: "m2", title: "Fractions worksheet", date: "Nov 5", kind: "Assignment"),
                .init(id: "m3", title: "Tutor lesson", date: "Nov 9", kind: "Lesson"),
                .init(id: "m4", title: "Final check-in", date: "Nov 20", kind: "Review")
            ], progress: [
                .init(subject: "Fractions", completion: 62, nextMilestone: "Equivalent fractions practice", status: "Practice"),
                .init(subject: "Measurement", completion: 80, nextMilestone: "Compare units and lengths", status: "On track"),
                .init(subject: "Word problems", completion: 48, nextMilestone: "Build a solving strategy", status: "Needs support")
            ])
        }
    }
}
