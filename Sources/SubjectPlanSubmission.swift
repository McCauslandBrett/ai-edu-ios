import Foundation

struct SubjectPlanSubmission {
    let inputs: SubjectPlanInputs
    let request: LearningPlanGenerationRequest
}

/// Builds the AI request from parent form values and saved subject history.
enum SubjectPlanSubmissionBuilder {
    static func build(
        student: StudentProfile,
        subject: String,
        targetedSkillsText: String,
        learningOutcome: String,
        highestAssessmentLevel: String,
        priorResultsText: String,
        instructorContext: String,
        previous: SubjectPlanInputs?
    ) -> SubjectPlanSubmission {
        let cleanedSubject = subject.trimmingCharacters(in: .whitespacesAndNewlines)
        let outcome = learningOutcome.trimmingCharacters(in: .whitespacesAndNewlines)
        let skills = values(from: targetedSkillsText, separators: CharacterSet(charactersIn: ",\n"))
        let newResults = values(from: priorResultsText, separators: .newlines)
        let instructorNotes = instructorContext.trimmingCharacters(in: .whitespacesAndNewlines)

        let combinedSkills = skills.isEmpty ? (previous?.targetedSkills ?? []) : skills
        let combinedResults = (previous?.priorAssessmentResults ?? []) + newResults
        let enteredAssessmentLevel = highestAssessmentLevel.trimmingCharacters(in: .whitespacesAndNewlines)
        let combinedAssessmentLevel = enteredAssessmentLevel.isEmpty
            ? (previous?.highestAssessmentLevel ?? "")
            : enteredAssessmentLevel
        let profileContext = [
            "Student learning profile: \(student.summary)",
            "Previous instructor context: \(previous?.instructorContext ?? "")",
            "Current instructor or parent guidance: \(instructorNotes)"
        ].joined(separator: "\n")

        let inputs = SubjectPlanInputs(
            targetedSkills: combinedSkills,
            learningOutcome: outcome,
            highestAssessmentLevel: combinedAssessmentLevel,
            priorAssessmentResults: combinedResults,
            instructorContext: instructorNotes
        )
        let request = LearningPlanGenerationRequest(
            student: AIStudentContext(name: student.name, age: student.age, gradeLevel: student.gradeLevel),
            subject: cleanedSubject,
            objective: outcome,
            monthlyWindow: "4 weeks",
            targetedSkills: combinedSkills,
            highestAssessmentLevel: combinedAssessmentLevel,
            priorResults: combinedResults,
            instructorContext: profileContext
        )
        return SubjectPlanSubmission(inputs: inputs, request: request)
    }

    private static func values(from text: String, separators: CharacterSet) -> [String] {
        text.components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}
