import Foundation

/// Converts the existing MEP resource catalogue into a year-long, skill-linked plan.
/// The source PDFs remain the curriculum; these companion worksheets make weekly work trackable in the app.
struct MEPCurriculumPlanBuilder {
    private let lessonsPerWeek = 4
    private let skills = [
        "Number and calculation",
        "Patterns and mathematical reasoning",
        "Geometry and spatial reasoning",
        "Measurement and data"
    ]

    func build(subject: MEPSubject, studentID: String) -> StudentSubjectPlan {
        let year = yearNumber(in: subject)
        let lessonCount = year == 6 ? 175 : 140
        let weekCount = Int(ceil(Double(lessonCount) / Double(lessonsPerWeek)))
        let objective = "Follow the MEP Year \(year) mathematics curriculum. Each week is organized around four sequential MEP lessons, with companion practice linked to the original workbook."
        let weeks = (1...weekCount).map { weekNumber in
            makeWeek(weekNumber, year: year, lessonCount: lessonCount, subject: subject)
        }
        let milestones = weeks.flatMap { week in
            let assignments = week.assignments.map { assignment in
                GeneratedLearningPlan.Milestone(
                    id: "mep-week-\(week.weekNumber)-\(assignment.id)",
                    title: assignment.title,
                    date: "Week \(week.weekNumber)",
                    kind: "assignment"
                )
            }
            return assignments + [
                GeneratedLearningPlan.Milestone(
                    id: "mep-week-\(week.weekNumber)-assessment",
                    title: week.assessment.title,
                    date: "Week \(week.weekNumber)",
                    kind: week.weekNumber == weekCount ? "final" : "assessment"
                )
            ]
        }
        let progress = skills.map {
            GeneratedLearningPlan.Progress(
                subject: $0,
                completion: 0,
                nextMilestone: "Complete and review weekly MEP practice",
                status: "Not assessed"
            )
        }
        let plan = GeneratedLearningPlan(
            subject: subject.name,
            objective: objective,
            monthlyWindow: "Full-year curriculum · \(weekCount) weeks · four lessons per week",
            milestones: milestones,
            progress: progress,
            weeks: weeks
        )
        return StudentSubjectPlan(
            studentID: studentID,
            subject: subject.name,
            inputs: SubjectPlanInputs(
                targetedSkills: skills,
                learningOutcome: objective,
                highestAssessmentLevel: "",
                priorAssessmentResults: [],
                instructorContext: "CIMT Mathematics Enhancement Programme · MEP Year \(year)"
            ),
            plan: plan,
            prebuiltSubjectID: subject.id
        )
    }

    private func makeWeek(
        _ weekNumber: Int,
        year: Int,
        lessonCount: Int,
        subject: MEPSubject
    ) -> GeneratedLearningPlan.Week {
        let firstLesson = (weekNumber - 1) * lessonsPerWeek + 1
        let lastLesson = min(weekNumber * lessonsPerWeek, lessonCount)
        let theme = "Lessons \(firstLesson)–\(lastLesson)"
        let weeklyVideo = video(for: year, weekNumber: weekNumber)
        let workbook = resource(in: subject, category: "Workbooks", covering: firstLesson)
        let lessonPlan = resource(in: subject, category: "Lesson plans", covering: firstLesson)
        let lecturePrompt = [
            "Teach the MEP Year \(year) material for lessons \(firstLesson) through \(lastLesson).",
            "Use the official lesson plan and practice book linked from this subject's MEP curriculum resources.",
            "Connect explanations to the student's age and school grade, model one example at a time, ask the student to explain their reasoning, and gently refocus the conversation if it drifts.",
            "Finish by inviting the student to complete the linked workbook pages and this week's companion worksheet."
        ].joined(separator: " ")

        let assignments = (1...4).map { assignmentNumber in
            makeActivity(
                year: year,
                weekNumber: weekNumber,
                assignmentNumber: assignmentNumber,
                lessonRange: firstLesson...lastLesson,
                assessment: false,
                resource: workbook
            )
        }
        let assessment = makeActivity(
            year: year,
            weekNumber: weekNumber,
            assignmentNumber: 0,
            lessonRange: firstLesson...lastLesson,
            assessment: true,
            resource: nil
        )

        // Include the lesson plan URL in the tutor prompt while leaving every original resource
        // available in MEPResourceView.
        let promptWithLessonPlan = lessonPlan.map { lecturePrompt + " Official lesson plan: \($0.url)" } ?? lecturePrompt
        return GeneratedLearningPlan.Week(
            weekNumber: weekNumber,
            theme: theme,
            lecturePrompt: promptWithLessonPlan,
            youtubeVideo: weeklyVideo,
            assessment: assessment,
            assignments: assignments
        )
    }

    private func video(for year: Int, weekNumber: Int) -> GeneratedLearningPlan.SuggestedVideo {
        let videos: [GeneratedLearningPlan.SuggestedVideo]
        switch year {
        case 1:
            videos = [
                video("Adding 1 vs. adding 10", "mKsKU0BAiRM", topic: "place value and adding tens"),
                video("Recognizing shapes", "10dTx1Zy_4w", topic: "naming and describing shapes"),
                video("Introduction to place value", "wx2gI8iwMCA", topic: "ones and tens")
            ]
        case 2:
            videos = [
                video("Adding 2-digit numbers without regrouping", "EV38zfiY6Vs", topic: "two-digit addition"),
                video("Addition and subtraction", "MwerJr42bQw", topic: "addition and subtraction stories"),
                video("Recognizing shapes", "10dTx1Zy_4w", topic: "naming and describing shapes"),
                video("Introduction to place value", "wx2gI8iwMCA", topic: "ones and tens")
            ]
        case 3:
            videos = [
                video("Practice finding patterns in numbers", "l-6uEtTBH7g", topic: "number patterns"),
                video("Properties and patterns for multiplication", "um2nlNVM_YM", topic: "multiplication patterns"),
                video("Finding perimeter when a side length is missing", "tmt5fXhU7Rs", topic: "perimeter and missing side lengths"),
                video("Intuition for grams", "zqduFg0s5Q4", topic: "measuring mass")
            ]
        case 4:
            videos = [
                video("Categorizing geometric shapes", "PiQxA9O7Rd8", topic: "classifying shapes and angles"),
                video("Input & output tables: identifying the rule", "Y9oW96dhzg0", topic: "number patterns and rules"),
                video("Metric system: units of distance", "I3kQJvR7ZIg", topic: "metric distance units"),
                video("Multiplying 1-digit numbers by 10, 100, and 1000", "SG4gX-VGzog", topic: "place value and multiplication")
            ]
        case 5:
            videos = [
                video("Number patterns: visualizing sequence relationships", "mqsIJucBn6c", topic: "number patterns"),
                video("Common Fractions and Decimals", "sSHo2OwSOIM", topic: "fractions and decimals"),
                video("Volume through decomposition", "feNWZEln6Nc", topic: "volume and measurement"),
                video("Units of measurement word problem: volume", "PdHSs5_kx24", topic: "volume word problems")
            ]
        default:
            videos = [
                video("Introduction to ratios", "bIKmw0aTmYc", topic: "ratios and comparing quantities"),
                video("Introduction to rates", "qGTYSAeLTOE", topic: "rates and unit comparisons"),
                video("Finding area by breaking up the shape", "loAA3TCNAvU", topic: "area and geometry"),
                video("How to interpret a histogram", "c02vjunQsJM", topic: "data and graphs")
            ]
        }
        return videos[(weekNumber - 1) % videos.count]
    }

    private func video(
        _ title: String,
        _ videoID: String,
        topic: String
    ) -> GeneratedLearningPlan.SuggestedVideo {
        GeneratedLearningPlan.SuggestedVideo(
            title: title,
            channel: "Khan Academy",
            url: "https://www.youtube.com/watch?v=\(videoID)",
            reason: "A grade-appropriate video about \(topic), one of this week's practice topics."
        )
    }

    private func makeActivity(
        year: Int,
        weekNumber: Int,
        assignmentNumber: Int,
        lessonRange: ClosedRange<Int>,
        assessment: Bool,
        resource: MEPSubject.Resource?
    ) -> GeneratedLearningPlan.PlannedActivity {
        let offset = assessment ? 3 : assignmentNumber - 1
        let questions = makeQuestions(year: year, weekNumber: weekNumber, offset: offset)
        let label = assessment ? "Weekly skills check" : "MEP practice \(assignmentNumber) of 4"
        return GeneratedLearningPlan.PlannedActivity(
            id: "mep-y\(year)-w\(weekNumber)-\(assessment ? "check" : "practice-\(assignmentNumber)")",
            title: "\(label) · Lessons \(lessonRange.lowerBound)–\(lessonRange.upperBound)",
            subject: "Year \(year) Math",
            prompt: assessment
                ? "Show your work on this short check for MEP Year \(year), lessons \(lessonRange.lowerBound)–\(lessonRange.upperBound)."
                : "Complete these companion problems, then work through MEP Year \(year), lessons \(lessonRange.lowerBound)–\(lessonRange.upperBound) in the linked official workbook.",
            questions: questions.questions,
            questionSkills: questions.questionSkills,
            questionIllustrations: questions.illustrations,
            writingSpaceMultipliers: Array(repeating: 1, count: questions.questions.count),
            resourceURL: resource?.url,
            resourceTitle: resource.map { "MEP workbook · \($0.title)" },
            answerKey: questions.answers,
            rubric: "Award credit for the correct answer and visible working. For drawing or reasoning, accept any mathematically valid response that demonstrates the linked skill.",
            points: 20
        )
    }

    private func makeQuestions(year: Int, weekNumber: Int, offset: Int) -> (questions: [String], answers: [String], illustrations: [String], questionSkills: [String]) {
        var questions: [String] = []
        var answers: [String] = []
        var illustrations: [String] = []
        var questionSkills: [String] = []

        // Five questions for each tracked skill. The same mapping is persisted on the
        // assignment so every graded response contributes to exactly one skill.
        for skillIndex in skills.indices {
            for variation in 0..<5 {
                let exerciseOffset = offset * 5 + variation
                questionSkills.append(skills[skillIndex])
                switch skillIndex {
                case 0:
                    let problem = arithmeticProblem(year: year, week: weekNumber, offset: exerciseOffset)
                    questions.append(problem.question)
                    answers.append(problem.answer)
                    illustrations.append(["🔢  🔢  🔢", "➕", "➖", "✖️", "➗"][variation])
                case 1:
                    let start = year * 2 + weekNumber + exerciseOffset
                    let step = max(2, year + (weekNumber % 4) + variation)
                    questions.append("Continue the pattern: \(start), \(start + step), \(start + 2 * step), ___. Write the rule and the next two numbers.")
                    answers.append("\(start + 3 * step), \(start + 4 * step); add \(step) each time.")
                    illustrations.append("🔢  ➡️  🔢  ➡️  ___")
                case 2:
                    let problem = geometryProblem(year: year, week: weekNumber, offset: exerciseOffset)
                    questions.append(problem.question)
                    answers.append(problem.answer)
                    illustrations.append(["△", "□", "▱", "📐", "🔷"][variation])
                default:
                    let problem = measurementProblem(year: year, week: weekNumber, offset: exerciseOffset)
                    questions.append(problem.question)
                    answers.append(problem.answer)
                    illustrations.append(["📏", "⚖️", "🕒", "🧪", "📐"][variation])
                }
            }
        }
        return (questions, answers, illustrations, questionSkills)
    }

    private func geometryProblem(year: Int, week: Int, offset: Int) -> (question: String, answer: String) {
        if year == 1 {
            return ("Draw a triangle and mark each side. How many sides does it have?", "A triangle has 3 sides.")
        }
        if year == 2 {
            return ("Draw a square and show one line of symmetry. How many lines of symmetry does a square have?", "A square has 4 lines of symmetry.")
        }
        let width = 2 + (week % 4)
        let length = max(width + 2, year + 5 + offset)
        return (
            "Draw a rectangle that is \(length) cm long and \(width) cm wide. Label both sides and find its perimeter.",
            "A rectangle with opposite sides \(length) cm and \(width) cm; perimeter = \(2 * (length + width)) cm."
        )
    }

    private func arithmeticProblem(year: Int, week: Int, offset: Int) -> (question: String, answer: String) {
        if year == 1 {
            let first = 3 + (week % 6) + offset
            let second = 2 + (week % 4)
            return ("Solve \(first) + \(second). Show or draw how you counted.", "\(first + second)")
        }
        if year == 2 {
            let first = 20 + (week * 3 % 50) + offset
            let second = 10 + (week * 2 % 25)
            return ("Calculate \(first) + \(second). Show your place-value steps.", "\(first + second)")
        }
        if year <= 4 {
            let first = 100 + week * 17 + offset
            let second = 40 + week * 6
            return ("Calculate \(first) − \(second). Show how you checked your answer.", "\(first - second)")
        }
        let factor = year + 3 + (week % 5) + offset
        let multiplier = 6 + (week % 7)
        return ("Calculate \(factor) × \(multiplier). Show a method that makes the calculation clear.", "\(factor * multiplier)")
    }

    private func measurementProblem(year: Int, week: Int, offset: Int) -> (question: String, answer: String) {
        if year == 1 {
            let startingLength = 5 + (week % 5) + offset
            let extra = 3 + (week % 4)
            return ("A ribbon is \(startingLength) cm long. You add \(extra) cm. How long is it now?", "\(startingLength + extra) cm")
        }
        if year == 2 {
            let pounds = 1 + (week % 4) + offset
            let pence = 20 + (week * 5 % 70)
            return ("A toy costs £\(pounds). You also spend \(pence)p. Write the total in pounds and pence.", "£\(pounds) and \(pence)p")
        }
        let metres = year == 3 ? 2 : (year == 4 ? 3 : (year == 5 ? 1 : 2))
        let centimetres = (week % 4) * 10 + offset * 10
        let total = metres * 100 + centimetres
        return ("A path is \(metres) m and \(centimetres) cm long. How many centimetres is that altogether?", "\(total) cm")
    }

    private func resource(in subject: MEPSubject, category: String, covering lesson: Int) -> MEPSubject.Resource? {
        subject.resources.first { resource in
            guard resource.category == category,
                  let range = numberRange(in: resource.title) else { return false }
            return range.contains(lesson)
        }
    }

    private func numberRange(in title: String) -> ClosedRange<Int>? {
        let numbers = title.split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) }
        guard numbers.count >= 2 else { return nil }
        return numbers[0]...numbers[1]
    }

    private func yearNumber(in subject: MEPSubject) -> Int {
        subject.id.split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) }.first ?? 1
    }
}
