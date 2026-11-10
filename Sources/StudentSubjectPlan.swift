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

struct PrebuiltSubject: Identifiable {
    struct Resource: Identifiable {
        let title: String
        let url: String
        let category: String
        let pdfStartPage: Int

        init(title: String, url: String, category: String, pdfStartPage: Int = 1) {
            self.title = title
            self.url = url
            self.category = category
            self.pdfStartPage = pdfStartPage
        }

        var id: String { url }
    }

    let id: String
    let name: String
    let resources: [Resource]
    let publisher: String
    let summary: String
    let resourceIntroduction: String
    let sourceTitle: String
    let sourceURL: String
    let sourceNote: String
    let contentVersion: Int

    init(
        id: String,
        name: String,
        resources: [Resource],
        publisher: String = "Mathematics Enhancement Programme · CIMT",
        summary: String? = nil,
        resourceIntroduction: String = "Start with Learning Objectives and the shared guidelines. Follow the lesson plans alongside the practice books at your child's pace.",
        sourceTitle: String = "Original MEP curriculum",
        sourceURL: String = "https://www.cimt.org.uk/projects/mepres/primary/index.htm",
        sourceNote: String = "Copyright belongs to the original creators. CIMT provides these materials for downloading and dissemination for non-profit making purposes only. Resources open from CIMT and require internet access.",
        contentVersion: Int = 4
    ) {
        self.id = id
        self.name = name
        self.resources = resources
        self.publisher = publisher
        self.summary = summary ?? "\(resources.count) resources"
        self.resourceIntroduction = resourceIntroduction
        self.sourceTitle = sourceTitle
        self.sourceURL = sourceURL
        self.sourceNote = sourceNote
        self.contentVersion = contentVersion
    }

    func named(_ newName: String) -> PrebuiltSubject {
        PrebuiltSubject(
            id: id,
            name: newName,
            resources: resources,
            publisher: publisher,
            summary: summary,
            resourceIntroduction: resourceIntroduction,
            sourceTitle: sourceTitle,
            sourceURL: sourceURL,
            sourceNote: sourceNote,
            contentVersion: contentVersion
        )
    }

    static var catalog: [PrebuiltSubject] { PrebuiltSubjectCatalog.subjects }
}

typealias MEPSubject = PrebuiltSubject
