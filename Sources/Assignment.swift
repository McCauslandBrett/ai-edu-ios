import Foundation

struct Assignment: Identifiable, Hashable {
    let id: String
    let subject: String
    let title: String
    let dueDate: String
    let points: Int
    let prompt: String
    let questions: [String]
    let status: String

    static let samples: [Assignment] = [
        Assignment(
            id: "fractions-01",
            subject: "Mathematics",
            title: "Fraction Review Worksheet",
            dueDate: "Nov 6",
            points: 20,
            prompt: "Compare fractions, model equivalent values, and justify your answer.",
            questions: ["1. 3/4 ___ 2/3", "2. 5/8 + 1/4 = ___", "3. Explain how you know your answer is correct."],
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
            status: "In progress"
        )
    ]
}
