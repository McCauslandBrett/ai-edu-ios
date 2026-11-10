import Foundation

protocol PrebuiltSubjectPlanBuilding {
    func build(
        subject: PrebuiltSubject,
        studentID: String,
        subjectName: String?,
        planInstanceID: String?
    ) -> StudentSubjectPlan
}

/// Routes each catalogue subject to the plan builder that owns its curriculum rules.
struct PrebuiltSubjectPlanBuilder: PrebuiltSubjectPlanBuilding {
    private let mepBuilder: any PrebuiltSubjectPlanBuilding
    private let firstGradePrepBuilder: any PrebuiltSubjectPlanBuilding

    init(
        mepBuilder: any PrebuiltSubjectPlanBuilding = MEPCurriculumPlanBuilder(),
        firstGradePrepBuilder: any PrebuiltSubjectPlanBuilding = FirstGradePrepPlanBuilder()
    ) {
        self.mepBuilder = mepBuilder
        self.firstGradePrepBuilder = firstGradePrepBuilder
    }

    func build(
        subject: PrebuiltSubject,
        studentID: String,
        subjectName: String? = nil,
        planInstanceID: String? = nil
    ) -> StudentSubjectPlan {
        let builder = subject.id == FirstGradePrepPlanBuilder.subjectID
            ? firstGradePrepBuilder
            : mepBuilder
        return builder.build(
            subject: subject,
            studentID: studentID,
            subjectName: subjectName,
            planInstanceID: planInstanceID
        )
    }
}

/// Builds a four-week introduction from printed Practice Book pages 25–72.
/// Each week's four practice activities and its check open original PDF pages.
struct FirstGradePrepPlanBuilder: PrebuiltSubjectPlanBuilding {
    static let subjectID = "first-grade-prep"

    private struct WeekContent {
        let theme: String
        let overview: String
        let practicePages: [Int]
        let assessmentPage: Int
        let skill: String
    }

    private struct VideoContent {
        let title: String
        let id: String
        let channel: String
        let reason: String

        var suggestedVideo: GeneratedLearningPlan.SuggestedVideo {
            GeneratedLearningPlan.SuggestedVideo(
                title: title,
                channel: channel,
                url: "https://www.youtube.com/watch?v=\(id)",
                reason: reason
            )
        }
    }

    private static let skillNames = [
        "Addition and subtraction",
        "Measurement and comparison",
        "Geometry and spatial reasoning",
        "Money, place value, and data"
    ]

    private static let weeks: [WeekContent] = [
        WeekContent(
            theme: "Unit 3 · Lobster Legs & Whale Tails",
            overview: "Practice story problems with groups, make-ten addition, sums and differences within ten, money and time contexts, and adding or subtracting tens on a hundreds grid. Source pages 25–36.",
            practicePages: [25, 29, 31, 34],
            assessmentPage: 36,
            skill: "Addition and subtraction"
        ),
        WeekContent(
            theme: "Unit 4 · Penguins",
            overview: "Work with doubles and near-doubles, compare temperatures and heights, solve penguin story problems, skip-count by twos, and compare differences on a number line. Source pages 37–48.",
            practicePages: [37, 39, 42, 46],
            assessmentPage: 48,
            skill: "Measurement and comparison"
        ),
        WeekContent(
            theme: "Unit 5 · Pattern Blocks, Polydrons & Paper Quilts",
            overview: "Find missing numbers, practice addition and subtraction facts, identify shape attributes and polygons, and solve visual shape riddles. Source pages 49–60.",
            practicePages: [49, 51, 55, 58],
            assessmentPage: 60,
            skill: "Geometry and spatial reasoning"
        ),
        WeekContent(
            theme: "Unit 6 · My Little Farm",
            overview: "Solve farm story problems, use money while buying and selling, read a farm map with compass directions, work with number charts, and compare daily milk-production data. Source pages 61–72.",
            practicePages: [61, 63, 65, 70],
            assessmentPage: 72,
            skill: "Money, place value, and data"
        )
    ]

    // The selected links are distinct within this four-week plan and from the MEP video catalogue.
    private static let videos: [[VideoContent]] = [
        [
            VideoContent(title: "Skip Count Song: 2s, 5s, 10s, 25s, and 100s", id: "NCAWsawkJgo", channel: "Math Notes with Rocko", reason: "A movement-friendly introduction to the counting patterns used in this week's number stories."),
            VideoContent(title: "Make a 10 to Add · Grade 1", id: "Ceqo2Y3K3wA", channel: "MATH-N-ROLL", reason: "Models making ten as an addition strategy."),
            VideoContent(title: "Tens and Ones Magic!", id: "PP32l7T1QQc", channel: "Standards in Elementary", reason: "Shows how ones can be grouped into tens with base-ten blocks.")
        ],
        [
            VideoContent(title: "Measuring Length: Inches for Beginners!", id: "NqFamf2Ep9Y", channel: "Hi Friends!", reason: "Demonstrates measuring and comparing familiar objects with a ruler."),
            VideoContent(title: "Measure Length in Inches for Kids", id: "rwkZ3AZx97U", channel: "Kids Academy", reason: "Introduces measuring length with a ruler for first-grade learners."),
            VideoContent(title: "Subtraction Strategies: Subtracting Within 20", id: "tDzTg9RqQuA", channel: "Miacademy & MiaPrep Learning Channel", reason: "Practices visual strategies for subtraction story problems.")
        ],
        [
            VideoContent(title: "2D Shapes: Counting Vertices", id: "Jyh15pyQ1xc", channel: "Kids Academy", reason: "Counts corners on flat shapes, supporting this week's shape investigations."),
            VideoContent(title: "Geometry Review: Hexagons, Trapezoids, and More", id: "MLDrNdLxYUo", channel: "Kids Academy", reason: "Reviews the names and attributes of common polygons."),
            VideoContent(title: "Polygon Song for Kids", id: "-iTvYqlw1MA", channel: "Tiny Tunes", reason: "Reinforces polygon names and their sides through a short song.")
        ],
        [
            VideoContent(title: "Learn Coins for Kids: Penny, Nickel, Dime & Quarter", id: "TZa0DasdkS0", channel: "Hi Friends!", reason: "Introduces coin values for the farm buying and selling activities."),
            VideoContent(title: "Counting Dimes, Nickels, and Pennies", id: "jMV0KsTvDFA", channel: "Math Mammoth", reason: "Models combining coins to find a money total."),
            VideoContent(title: "North, South, East & West Song", id: "PUMXGsQ8mrE", channel: "YouTube", reason: "Practices the compass directions used to read the farm map.")
        ]
    ]

    private static let pageTitles: [Int: String] = [
        25: "Crab & Sea Star Problems",
        29: "Tuesday Afternoon Temperatures",
        31: "Make Ten Addition",
        34: "Hungry Shark Subtraction",
        36: "Adding & Subtracting Tens on a Hundreds Grid",
        37: "Doubles & Neighbors",
        39: "Bath Water & January Ocean Water Temperatures",
        42: "Comparing Penguin Heights",
        46: "Skip Counting by 2s",
        48: "Determining Differences on a Number Line",
        49: "What's Missing?",
        51: "Adding & Subtracting",
        55: "Which Shape Does Not Belong?",
        58: "Polygons & Nonpolygons",
        60: "Shape Riddles",
        61: "A Farmer's Morning",
        63: "Winter Farming: Buying Feed for Animals",
        65: "North, South, East & West on the Farm",
        70: "Selling Your Farm Products",
        72: "Daily Milk Production"
    ]

    func build(
        subject: PrebuiltSubject,
        studentID: String,
        subjectName: String? = nil,
        planInstanceID: String? = nil
    ) -> StudentSubjectPlan {
        let planSubject = subject.named(subjectName ?? subject.name)
        let allVideos = Self.videos.flatMap { $0.map(\.id) }
        precondition(Set(allVideos).count == allVideos.count, "First Grade Prep videos must not repeat.")

        let weeks = Self.weeks.enumerated().map { index, content in
            makeWeek(
                content,
                number: index + 1,
                subject: planSubject,
                videos: Self.videos[index].map(\.suggestedVideo),
                planInstanceID: planInstanceID
            )
        }
        let objective = "Build first-grade number sense and problem-solving through a four-week study of the original Bridges Grade 1 Practice Book, beginning at printed page 25."
        let milestones = weeks.flatMap { week in
            week.assignments.map {
                GeneratedLearningPlan.Milestone(
                    id: "first-grade-week-\(week.weekNumber)-\($0.id)",
                    title: $0.title,
                    date: "Week \(week.weekNumber)",
                    kind: "assignment"
                )
            } + [
                GeneratedLearningPlan.Milestone(
                    id: "first-grade-week-\(week.weekNumber)-assessment\(planInstanceID.map { "-\($0)" } ?? "")",
                    title: week.assessment.title,
                    date: "Week \(week.weekNumber)",
                    kind: week.weekNumber == Self.weeks.count ? "final" : "assessment"
                )
            ]
        }
        let progress = Self.skillNames.map {
            GeneratedLearningPlan.Progress(
                subject: $0,
                completion: 0,
                nextMilestone: "Complete the weekly Practice Book pages for this skill",
                status: "Not assessed"
            )
        }
        let plan = GeneratedLearningPlan(
            subject: planSubject.name,
            objective: objective,
            monthlyWindow: "Four-week First Grade Prep · four original Practice Book worksheets and one weekly check per week",
            milestones: milestones,
            progress: progress,
            weeks: weeks
        )
        return StudentSubjectPlan(
            studentID: studentID,
            subject: planSubject.name,
            inputs: SubjectPlanInputs(
                targetedSkills: Self.skillNames,
                learningOutcome: objective,
                highestAssessmentLevel: "",
                priorAssessmentResults: [],
                instructorContext: "First Grade Prep using The Math Learning Center's Bridges Grade 1 Practice Book, printed pages 25–72."
            ),
            plan: plan,
            prebuiltSubjectID: planSubject.id,
            prebuiltContentVersion: planSubject.contentVersion,
            planInstanceID: planInstanceID
        )
    }

    private func makeWeek(
        _ content: WeekContent,
        number: Int,
        subject: PrebuiltSubject,
        videos: [GeneratedLearningPlan.SuggestedVideo],
        planInstanceID: String?
    ) -> GeneratedLearningPlan.Week {
        let assignments = content.practicePages.enumerated().map { index, printedPage in
            makeActivity(
                printedPage: printedPage,
                weekNumber: number,
                assignmentNumber: index + 1,
                subject: subject,
                assessment: false,
                trackedSkill: content.skill,
                planInstanceID: planInstanceID
            )
        }
        let assessment = makeActivity(
            printedPage: content.assessmentPage,
            weekNumber: number,
            assignmentNumber: 0,
            subject: subject,
            assessment: true,
            trackedSkill: content.skill,
            planInstanceID: planInstanceID
        )
        let lecturePrompt = "Teach Week \(number) of First Grade Prep: \(content.overview) Use the student's age and grade to choose a gentle pace. Show one example at a time, invite the student to explain aloud or write on the page, and gently bring the conversation back to the math if attention wanders. Use the original Practice Book pages attached to this plan; do not invent replacement worksheets. Finish by reviewing the four practice pages and the weekly check together."
        return GeneratedLearningPlan.Week(
            weekNumber: number,
            theme: content.theme,
            lecturePrompt: lecturePrompt,
            overview: content.overview,
            youtubeVideo: videos.first,
            youtubeVideos: videos,
            assessment: assessment,
            assignments: assignments
        )
    }

    private func makeActivity(
        printedPage: Int,
        weekNumber: Int,
        assignmentNumber: Int,
        subject: PrebuiltSubject,
        assessment: Bool,
        trackedSkill: String,
        planInstanceID: String?
    ) -> GeneratedLearningPlan.PlannedActivity {
        let resource = subject.resources.first { $0.category == "Practice Book" }
        let pageTitle = Self.pageTitles[printedPage] ?? "Practice Book activity"
        let type = assessment ? "weekly-check" : "practice-\(assignmentNumber)"
        let label = assessment ? "Weekly check" : "Practice Book page \(printedPage)"
        return GeneratedLearningPlan.PlannedActivity(
            id: "first-grade-w\(weekNumber)-\(type)-p\(printedPage)\(planInstanceID.map { "-copy-\($0)" } ?? "")",
            title: "\(label) · \(pageTitle)",
            subject: subject.name,
            prompt: assessment
                ? "Complete the original Practice Book page \(printedPage) as this week's check. Write directly on the page, then review the work together."
                : "Complete the original Practice Book page \(printedPage): \(pageTitle). Write directly on the page in the app and show how you figured it out.",
            questions: [],
            questionSkills: [],
            questionIllustrations: [],
            writingSpaceMultipliers: [],
            resourceURL: resource?.url,
            resourceTitle: resource.map { _ in "Bridges Grade 1 Practice Book · page \(printedPage)" },
            resourcePageNumber: resource.map { $0.pdfStartPage + printedPage - 25 },
            printedPageNumber: printedPage,
            answerKeyResourceURL: nil,
            answerKey: [],
            rubric: "Review the student's completed source page with the instructor or parent, focusing on the tracked skill: \(trackedSkill).",
            points: 0
        )
    }
}
