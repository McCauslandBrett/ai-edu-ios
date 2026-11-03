import Foundation

struct SubjectPlanInputs: Codable {
    let targetedSkills: [String]
    let learningOutcome: String
    let highestAssessmentLevel: String
    let priorAssessmentResults: [String]
    let instructorContext: String
}

struct StudentSubjectPlan: Codable, Identifiable {
    let studentID: String
    let subject: String
    let inputs: SubjectPlanInputs
    let plan: GeneratedLearningPlan

    var id: String { Self.key(studentID: studentID, subject: subject) }

    static func key(studentID: String, subject: String) -> String {
        studentID + "::" + subject.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
