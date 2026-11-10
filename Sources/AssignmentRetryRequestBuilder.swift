import Foundation

/// Creates the follow-up assignment request from grading feedback and skill mappings.
enum AssignmentRetryRequestBuilder {
    static func build(assignment: Assignment, grade: AssignmentGrade, student: StudentProfile) -> AssignmentGenerationRequest {
        let skills = failedSkills(in: grade, assignment: assignment)
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

    private static func failedSkills(in grade: AssignmentGrade, assignment: Assignment) -> [String] {
        let mappedSkills = assignment.questionSkills ?? []
        let failed = grade.items.enumerated().compactMap { index, item -> String? in
            guard !item.isCorrect, mappedSkills.indices.contains(index) else { return nil }
            return mappedSkills[index]
        }
        let unique = Array(NSOrderedSet(array: failed)) as? [String] ?? failed
        return unique.isEmpty ? [assignment.subject] : Array(unique.prefix(12))
    }
}
