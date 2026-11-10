import Foundation

/// Merges generated changes while preserving identity and source workbook metadata.
enum AssignmentAdjustmentMerger {
    static func merge(original: Assignment, adjusted: Assignment, studentID: String) -> Assignment {
        Assignment(
            id: original.id,
            subject: adjusted.subject,
            title: adjusted.title,
            dueDate: adjusted.dueDate,
            points: adjusted.points,
            prompt: adjusted.prompt,
            questions: adjusted.questions,
            answerKey: adjusted.answerKey,
            rubric: adjusted.rubric,
            status: adjusted.status,
            questionSkills: adjusted.questionSkills,
            studentID: studentID,
            parentAssignmentID: original.parentAssignmentID,
            questionIllustrations: adjusted.questionIllustrations,
            writingSpaceMultipliers: adjusted.writingSpaceMultipliers,
            resourceURL: original.resourceURL,
            resourceTitle: original.resourceTitle,
            resourcePageNumber: original.resourcePageNumber,
            printedPageNumber: original.printedPageNumber,
            answerKeyResourceURL: original.answerKeyResourceURL
        )
    }
}

