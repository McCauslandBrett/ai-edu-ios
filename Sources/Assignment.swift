import Foundation

struct Assignment: Identifiable, Codable, Hashable {
    let id: String
    let subject: String
    let title: String
    let dueDate: String
    let points: Int
    let prompt: String
    let questions: [String]
    let answerKey: [String]
    let rubric: String
    let status: String
    var questionSkills: [String]? = nil
    var studentID: String? = nil
    var parentAssignmentID: String? = nil
    var questionIllustrations: [String]? = nil
    var writingSpaceMultipliers: [Double]? = nil
    var resourceURL: String? = nil
    var resourceTitle: String? = nil
    /// One-based page number in the linked split Practice Book PDF.
    var resourcePageNumber: Int? = nil
    var printedPageNumber: Int? = nil
    var answerKeyResourceURL: String? = nil

    var isHomework: Bool { status != "Assessment" }

    func reidentified(as newID: String) -> Assignment {
        Assignment(
            id: newID,
            subject: subject,
            title: title,
            dueDate: dueDate,
            points: points,
            prompt: prompt,
            questions: questions,
            answerKey: answerKey,
            rubric: rubric,
            status: status,
            questionSkills: questionSkills,
            studentID: studentID,
            parentAssignmentID: parentAssignmentID,
            questionIllustrations: questionIllustrations,
            writingSpaceMultipliers: writingSpaceMultipliers,
            resourceURL: resourceURL,
            resourceTitle: resourceTitle,
            resourcePageNumber: resourcePageNumber,
            printedPageNumber: printedPageNumber,
            answerKeyResourceURL: answerKeyResourceURL
        )
    }

    static let samples: [Assignment] = [
        Assignment(
            id: "fractions-01",
            subject: "Mathematics",
            title: "Fraction Review Worksheet",
            dueDate: "Nov 6",
            points: 20,
            prompt: "Compare fractions, model equivalent values, and justify your answer.",
            questions: ["1. 3/4 ___ 2/3", "2. 5/8 + 1/4 = ___", "3. Explain how you know your answer is correct."],
            answerKey: ["3/4 > 2/3", "7/8", "Use a common denominator, benchmark, or number line and explain the comparison."],
            rubric: "Award partial credit for correct method and clear mathematical reasoning.",
            status: "Needs practice"
        ),
        Assignment(
            id: "reading-01",
            subject: "Reading",
            title: "Reading Response Practice",
            dueDate: "Nov 8",
            points: 15,
            prompt: "Answer each question using details and evidence from the passage.",
            questions: ["1. Why was the character nervous?", "2. Which detail supports your answer?", "3. What lesson can we learn?", "4. Use a quote to support your thinking."],
            answerKey: ["Answers vary; identify a reason grounded in the passage.", "A relevant detail from the passage.", "A reasonable lesson supported by events.", "A relevant quotation with an explanation."],
            rubric: "Evaluate comprehension, use of text evidence, and clarity. Accept reasonable interpretations supported by evidence.",
            status: "In progress"
        ),
        Assignment(
            id: "algebra-01",
            subject: "Algebra",
            title: "Solving Equations",
            dueDate: "Nov 6",
            points: 18,
            prompt: "Solve each equation and show the steps you used.",
            questions: ["1. x + 7 = 15", "2. 3y = 24", "3. Explain how you checked your answer."],
            answerKey: ["x = 8", "y = 8", "Substitute the value back into the original equation."],
            rubric: "Award partial credit for correct inverse operations and show-your-work reasoning.",
            status: "In progress"
        )
    ]
}
