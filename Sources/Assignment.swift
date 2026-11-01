import Foundation

struct Assignment: Identifiable, Hashable {
    let id: String
    let subject: String
    let title: String
    let dueDate: String
    let points: Int
    let prompt: String
    let questions: [String]

    static let samples: [Assignment] = [
        Assignment(
            id: "fractions-01",
            subject: "Math",
            title: "Equivalent fractions",
            dueDate: "Today",
            points: 10,
            prompt: "Show how you know each pair of fractions is equivalent.",
            questions: [
                "1. 1/2 = __/8",
                "2. 3/4 = __/12",
                "3. Explain the pattern you used."
            ]
        ),
        Assignment(
            id: "reading-01",
            subject: "Reading",
            title: "A character's point of view",
            dueDate: "Tomorrow",
            points: 8,
            prompt: "Use details from the passage to explain how the character feels.",
            questions: [
                "1. What does the character want?",
                "2. Which detail supports your answer?",
                "3. How does the character change?"
            ]
        )
    ]
}
