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
        let formValues = cleanedFormValues(
            subject: subject,
            targetedSkillsText: targetedSkillsText,
            learningOutcome: learningOutcome,
            highestAssessmentLevel: highestAssessmentLevel,
            priorResultsText: priorResultsText,
            instructorContext: instructorContext
        )
        let inputs = mergeHistory(formValues, previous: previous)
        let request = makeRequest(student: student, formValues: formValues, inputs: inputs, previous: previous)
        return SubjectPlanSubmission(inputs: inputs, request: request)
    }

    private struct FormValues {
        let subject: String
        let targetedSkills: [String]
        let learningOutcome: String
        let highestAssessmentLevel: String
        let priorResults: [String]
        let instructorContext: String
    }

    private static func cleanedFormValues(
        subject: String,
        targetedSkillsText: String,
        learningOutcome: String,
        highestAssessmentLevel: String,
        priorResultsText: String,
        instructorContext: String
    ) -> FormValues {
        FormValues(
            subject: subject.trimmingCharacters(in: .whitespacesAndNewlines),
            targetedSkills: values(from: targetedSkillsText, separators: CharacterSet(charactersIn: ",\n")),
            learningOutcome: learningOutcome.trimmingCharacters(in: .whitespacesAndNewlines),
            highestAssessmentLevel: highestAssessmentLevel.trimmingCharacters(in: .whitespacesAndNewlines),
            priorResults: values(from: priorResultsText, separators: .newlines),
            instructorContext: instructorContext.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    private static func mergeHistory(_ form: FormValues, previous: SubjectPlanInputs?) -> SubjectPlanInputs {
        SubjectPlanInputs(
            targetedSkills: form.targetedSkills.isEmpty ? (previous?.targetedSkills ?? []) : form.targetedSkills,
            learningOutcome: form.learningOutcome,
            highestAssessmentLevel: form.highestAssessmentLevel.isEmpty
                ? (previous?.highestAssessmentLevel ?? "")
                : form.highestAssessmentLevel,
            priorAssessmentResults: (previous?.priorAssessmentResults ?? []) + form.priorResults,
            instructorContext: form.instructorContext
        )
    }

    private static func makeRequest(
        student: StudentProfile,
        formValues: FormValues,
        inputs: SubjectPlanInputs,
        previous: SubjectPlanInputs?
    ) -> LearningPlanGenerationRequest {
        let profileContext = [
            "Student learning profile: \(student.summary)",
            "Previous instructor context: \(previous?.instructorContext ?? "")",
            "Current instructor or parent guidance: \(formValues.instructorContext)"
        ].joined(separator: "\n")

        return LearningPlanGenerationRequest(
            student: AIStudentContext(name: student.name, age: student.age, gradeLevel: student.gradeLevel),
            subject: formValues.subject,
            objective: inputs.learningOutcome,
            monthlyWindow: "4 weeks",
            targetedSkills: inputs.targetedSkills,
            highestAssessmentLevel: inputs.highestAssessmentLevel,
            priorResults: inputs.priorAssessmentResults,
            instructorContext: profileContext
        )
    }

    private static func values(from text: String, separators: CharacterSet) -> [String] {
        text.components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}
