import Foundation

/// Calculates question-weighted skill mastery without owning student or persistence state.
struct SubjectCompetencyTracker {
    func update(_ plan: inout GeneratedLearningPlan, assignments: [Assignment], results: [String: [Bool]]) {
        let totals = questionCounts(in: assignments)
        for index in plan.progress.indices {
            let skill = plan.progress[index].subject
            guard let total = totals[skill], total > 0 else { continue }
            let gradedAssignments = assignments.filter {
                $0.questionSkills?.contains(skill) == true && results[$0.id] != nil
            }
            guard !gradedAssignments.isEmpty else { continue }

            let correct = correctAnswerCount(for: skill, in: gradedAssignments, results: results)
            let completion = min(100, Double(correct) / Double(total) * 100)
            plan.progress[index].completion = completion
            plan.progress[index].status = completion >= 80 ? "Competent" : "Developing"
            plan.progress[index].nextMilestone = completion >= 80
                ? "Apply \(skill) in a new context"
                : "Practice more \(skill) questions"
        }
    }

    private func questionCounts(in assignments: [Assignment]) -> [String: Int] {
        assignments.reduce(into: [:]) { counts, assignment in
            for skill in assignment.questionSkills ?? [] { counts[skill, default: 0] += 1 }
        }
    }

    private func correctAnswerCount(
        for skill: String,
        in assignments: [Assignment],
        results: [String: [Bool]]
    ) -> Int {
        assignments.reduce(0) { total, assignment in
            let flags = results[assignment.id] ?? []
            let skills = assignment.questionSkills ?? []
            let correct = flags.enumerated().filter { index, isCorrect in
                isCorrect && skills.indices.contains(index) && skills[index] == skill
            }.count
            return total + correct
        }
    }
}
