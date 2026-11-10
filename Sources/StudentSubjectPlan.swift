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
    var plan: GeneratedLearningPlan
    var prebuiltSubjectID: String? = nil
    var prebuiltContentVersion: Int? = nil
    var planInstanceID: String? = nil
    var competencyResults: [String: [Bool]]? = nil

    var id: String { Self.key(studentID: studentID, subject: subject) }

    static func key(studentID: String, subject: String) -> String {
        studentID + "::" + subject.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

struct MEPSubject: Identifiable {
    struct Resource: Identifiable {
        let title: String
        let url: String
        let category: String
        var id: String { url }
    }
    let id: String
    let name: String
    let resources: [Resource]

    static var catalog: [MEPSubject] { MEPSubjectCatalog.subjects }

}
