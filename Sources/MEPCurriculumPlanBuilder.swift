import Foundation

/// Converts the MEP catalogue into a year-long plan whose worksheet activities open
/// the original Practice Book pages. It does not invent substitute worksheet questions.
struct MEPCurriculumPlanBuilder {
    private let weeksPerCourse = 4
    private let worksheetsPerWeek = 4
    private let skills = [
        "Number and calculation",
        "Patterns and mathematical reasoning",
        "Geometry and spatial reasoning",
        "Measurement and data"
    ]

    func overview(for subject: MEPSubject, weekNumber: Int) -> String {
        let year = yearNumber(in: subject)
        let lessonCount = year == 6 ? 175 : 140
        let lessons = lessonRange(for: weekNumber, lessonCount: lessonCount)
        let pages = sampledPracticePages(in: lessons)
        return "Compressed month plan · MEP lessons \(lessons.lowerBound)–\(lessons.upperBound). This week uses original Practice Book pages \(pages.map(String.init).joined(separator: ", ")); each page includes its printed exercises, diagrams, and response areas."
    }

    func build(subject: MEPSubject, studentID: String, planInstanceID: String? = nil) -> StudentSubjectPlan {
        let year = yearNumber(in: subject)
        let lessonCount = year == 6 ? 175 : 140
        let weekCount = weeksPerCourse
        let objective = "Complete a four-week accelerated survey of MEP Math Level \(year). Each week covers about one quarter of the level and uses four original Practice Book pages spaced across that material."
        let weeks = (1...weekCount).map { weekNumber in
            makeWeek(
                weekNumber,
                year: year,
                lessonCount: lessonCount,
                subject: subject,
                planInstanceID: planInstanceID
            )
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
                    id: "mep-week-\(week.weekNumber)-assessment\(planInstanceID.map { "-\($0)" } ?? "")",
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
            monthlyWindow: "4-week accelerated MEP Math Level \(year) plan · four Practice Book worksheets per week",
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
                instructorContext: "CIMT Mathematics Enhancement Programme · MEP Math Level \(year)"
            ),
            plan: plan,
            prebuiltSubjectID: subject.id,
            prebuiltContentVersion: 4,
            planInstanceID: planInstanceID
        )
    }

    private func makeWeek(
        _ weekNumber: Int,
        year: Int,
        lessonCount: Int,
        subject: MEPSubject,
        planInstanceID: String?
    ) -> GeneratedLearningPlan.Week {
        let lessonRange = lessonRange(for: weekNumber, lessonCount: lessonCount)
        let firstLesson = lessonRange.lowerBound
        let lastLesson = lessonRange.upperBound
        let theme = "Lessons \(firstLesson)–\(lastLesson)"
        let weeklyVideos = videos(for: year, weekNumber: weekNumber)
        let overview = overview(for: subject, weekNumber: weekNumber)
        let lessonPlans = resources(in: subject, category: "Lesson plans", overlapping: lessonRange)
        let lecturePrompt = [
            "Teach a compressed four-week survey of MEP Math Level \(year), lessons \(firstLesson) through \(lastLesson). Prioritize the central concepts and connect related lessons rather than trying to teach every lesson in full depth.",
            "Use the official lesson plans and original Practice Book pages linked from this subject's MEP curriculum resources.",
            "Connect explanations to the student's age and school grade, model one example at a time, ask the student to explain their reasoning, and gently refocus the conversation if it drifts.",
            "Finish by opening and completing this week's four selected original Practice Book pages. The student can write directly over each source page in the app."
        ].joined(separator: " ")

        let pages = sampledPracticePages(in: lessonRange)
        let assignments = pages.enumerated().map { offset, pageNumber in
            let workbook = resource(in: subject, category: "Workbooks", covering: pageNumber)
            return makeActivity(
                year: year,
                subjectName: subject.name,
                weekNumber: weekNumber,
                assignmentNumber: offset + 1,
                pageNumber: pageNumber,
                assessment: false,
                resource: workbook,
                planInstanceID: planInstanceID
            )
        }
        let assessmentPage = lastLesson
        let assessmentWorkbook = resource(in: subject, category: "Workbooks", covering: assessmentPage)
        let assessment = makeActivity(
            year: year,
            subjectName: subject.name,
            weekNumber: weekNumber,
            assignmentNumber: 0,
            pageNumber: assessmentPage,
            assessment: true,
            resource: assessmentWorkbook,
            planInstanceID: planInstanceID
        )

        // Link every lesson-plan segment crossed by this accelerated week's lesson range.
        let lessonPlanLinks = lessonPlans.map { "\($0.title): \($0.url)" }.joined(separator: " ")
        let promptWithLessonPlan = lessonPlanLinks.isEmpty
            ? lecturePrompt
            : lecturePrompt + " Official lesson plan resources: " + lessonPlanLinks
        return GeneratedLearningPlan.Week(
            weekNumber: weekNumber,
            theme: theme,
            lecturePrompt: promptWithLessonPlan,
            overview: overview,
            youtubeVideo: weeklyVideos.first,
            youtubeVideos: weeklyVideos,
            assessment: assessment,
            assignments: assignments
        )
    }

    private func videos(for year: Int, weekNumber: Int) -> [GeneratedLearningPlan.SuggestedVideo] {
        let videoLibrary: [GeneratedLearningPlan.SuggestedVideo]
        switch year {
        case 1:
            videoLibrary = [
                video("Adding 1 vs. adding 10", "mKsKU0BAiRM", topic: "place value and adding tens"),
                video("Recognizing shapes", "10dTx1Zy_4w", topic: "naming and describing shapes"),
                video("Introduction to place value", "wx2gI8iwMCA", topic: "ones and tens"),
                video("Counting in pictures", "leDYnoNSvD4", topic: "counting pictured objects"),
                video("Counting in order", "PEeUTQ0Gri8", topic: "counting objects in sequence"),
                video("Adding 8 + 7", "AK0NZITv5Ns", topic: "making ten to add"),
                video("Skip counting by 5", "UwWn84u6i8s", topic: "skip counting by fives"),
                video("Number grid", "9XZypM2Z3Ro", topic: "number patterns through 100"),
                video("Counting with small numbers", "y2-uaPiyoxc", topic: "counting small groups"),
                video("Halves and fourths", "0lSTXtwPuOU", topic: "sharing shapes into equal parts"),
                video("Adding 7 + 6", "ZgzpTx-s9Zo", topic: "making ten to add"),
                video("Comparison word problems", "osIFa9zcI-w", topic: "comparing quantities in story problems")
            ]
        case 2:
            videoLibrary = [
                video("Adding 2-digit numbers without regrouping", "EV38zfiY6Vs", topic: "two-digit addition"),
                video("Addition and subtraction", "MwerJr42bQw", topic: "addition and subtraction stories"),
                video("Subtracting a 1-digit number with regrouping", "zvetEuVJ0bE", topic: "regrouping when subtracting"),
                video("Subtracting two-digit numbers without regrouping", "RzEFGpe0rv4", topic: "subtracting tens and ones"),
                video("Subtracting 3-digit numbers without regrouping", "i8r7ZTUqB9w", topic: "hundreds, tens, and ones"),
                video("Subtracting with regrouping", "Ds226Vh7epg", topic: "subtracting by regrouping tens and ones"),
                video("Comparing inches and centimeters", "CSWPyCaIMsQ", topic: "measuring length in different units", channel: "YouTube"),
                video("Measuring with a broken ruler", "A6owsT9NBpQ", topic: "measuring length from a shifted starting point", channel: "YouTube"),
                video("Telling time to the nearest five minutes", "h6RNkQ7lU8Y", topic: "reading an analog clock", channel: "LearnZillion"),
                video("Line plot song", "VS1fLbeuRkU", topic: "organizing measurement data on a line plot", channel: "YouTube"),
                video("Creating a line plot", "xa2ICYALJ9Y", topic: "representing data on a line plot", channel: "YouTube"),
                video("Picture graphs and bar graphs", "_H0M0XzjmIA", topic: "reading picture and bar graphs", channel: "YouTube")
            ]
        case 3:
            videoLibrary = [
                video("Practice finding patterns in numbers", "l-6uEtTBH7g", topic: "number patterns"),
                video("Properties and patterns for multiplication", "um2nlNVM_YM", topic: "multiplication patterns"),
                video("Finding perimeter when a side length is missing", "tmt5fXhU7Rs", topic: "perimeter and missing side lengths"),
                video("Intuition for grams", "zqduFg0s5Q4", topic: "measuring mass"),
                video("Representing one-step word problems", "ZVXimuY5FkE", topic: "translating a story into operations"),
                video("Counting U.S. dollars and coins", "2E9ghvxEFTw", topic: "counting money and making totals"),
                video("Patterns in a multiplication table", "3y4N_5_R8ME", topic: "finding patterns in multiplication facts"),
                video("Representing word problems", "M7nJnjh0XKI", topic: "modeling a word problem"),
                video("Solving division word problems", "l6sqk4RFHMc", topic: "division in equal-group stories"),
                video("Solving another division word problem", "RiP6EgKEZNU", topic: "choosing division for a story problem"),
                video("Solving multiplication word problems", "fs_r0vViUb8", topic: "multiplication in equal-group stories"),
                video("Picture and bar graphs", "g-Xjkiiz1qw", topic: "representing and reading data")
            ]
        case 4:
            videoLibrary = [
                video("Categorizing geometric shapes", "PiQxA9O7Rd8", topic: "classifying shapes and angles"),
                video("Input & output tables: identifying the rule", "Y9oW96dhzg0", topic: "number patterns and rules"),
                video("Metric system: units of distance", "I3kQJvR7ZIg", topic: "metric distance units"),
                video("Multiplying 1-digit numbers by 10, 100, and 1000", "SG4gX-VGzog", topic: "place value and multiplication"),
                video("Measuring angles with a circular protractor", "Ttji2_wBSEo", topic: "measuring angles"),
                video("Calculating profit with multiplication", "iCA78yjz_HY", topic: "multiplication in a real-world problem"),
                video("Multiplying two-digit numbers", "DaQlieZH1kk", topic: "multiplying two-digit numbers"),
                video("Multiplying two-digit numbers with the distributive property", "3JmnxR8nEi8", topic: "breaking multiplication into place-value parts"),
                video("Common fractions and decimals", "lh2mp0aqSh8", topic: "connecting common fractions and decimals"),
                video("Comparing fractions visually with a bar", "ory05j2jgBM", topic: "comparing fractions with visual models"),
                video("Comparing with multiplication", "KFzcwWTEDDI", topic: "comparing quantities using multiplication"),
                video("Comparing with multiplication: another example", "hjnyAogBdBk", topic: "solving a multiplication comparison")
            ]
        case 5:
            videoLibrary = [
                video("Number patterns: visualizing sequence relationships", "mqsIJucBn6c", topic: "number patterns"),
                video("Common Fractions and Decimals", "sSHo2OwSOIM", topic: "fractions and decimals"),
                video("Volume through decomposition", "feNWZEln6Nc", topic: "volume and measurement"),
                video("Units of measurement word problem: volume", "PdHSs5_kx24", topic: "volume word problems"),
                video("Multiplying fractions: visualizing", "hr_mTd-oJ-M", topic: "visual models for fraction multiplication"),
                video("Dividing decimals with hundredths", "Hrjr5f5pZ84", topic: "decimal division"),
                video("Decimal multiplication with grids", "3Phgu3ExLmY", topic: "area models for multiplying decimals"),
                video("Creating volume expressions", "NDPTBKbWmy8", topic: "writing expressions for prism volume"),
                video("Using fractions as division to create mixed numbers", "g8yk6zQDAek", topic: "fractions as division"),
                video("Coordinate plane: graphing points", "4vNloi-zNjU", topic: "plotting points on a coordinate plane"),
                video("Volume in unit cubes by decomposing shape", "gm87omItizk", topic: "finding volume by splitting a solid into parts"),
                video("Adding decimals with thousandths", "_ayXtD83wBA", topic: "adding decimals by place value")
            ]
        default:
            videoLibrary = [
                video("Introduction to ratios", "bIKmw0aTmYc", topic: "ratios and comparing quantities"),
                video("Introduction to rates", "qGTYSAeLTOE", topic: "rates and unit comparisons"),
                video("Finding area by breaking up the shape", "loAA3TCNAvU", topic: "area and geometry"),
                video("How to interpret a histogram", "c02vjunQsJM", topic: "data and graphs"),
                video("Comparing negatives with variables", "kQkeayQke8A", topic: "comparing negative values on a number line"),
                video("Number opposites practice", "vRa6XxykfbY", topic: "opposites on a number line"),
                video("Sorting absolute values on a number line", "MFoXK57sw9k", topic: "ordering absolute values"),
                video("Comparing absolute values on a number line", "29P6bar7nHc", topic: "comparing absolute values"),
                video("Negative numbers in real life: temperature and elevation", "qKOojMSCkTA", topic: "interpreting negative numbers in context", channel: "YouTube"),
                video("Adding and subtracting negative numbers", "DBSviXhkubg", topic: "integer addition and subtraction", channel: "YouTube"),
                video("Comparing negative and positive numbers", "9-f9eAiEF7g", topic: "ordering positive and negative values", channel: "YouTube"),
                video("Thinking about shapes of data distributions", "2oJldeE4JcU", topic: "describing data distributions")
            ]
        }

        let videosPerWeek = 3
        precondition(videoLibrary.count == weeksPerCourse * videosPerWeek)
        precondition(Set(videoLibrary.map(\.url)).count == videoLibrary.count)
        guard (1...weeksPerCourse).contains(weekNumber) else { return [] }
        let startIndex = (weekNumber - 1) * videosPerWeek
        return Array(videoLibrary[startIndex..<(startIndex + videosPerWeek)])
    }

    private func video(
        _ title: String,
        _ videoID: String,
        topic: String,
        channel: String = "Khan Academy"
    ) -> GeneratedLearningPlan.SuggestedVideo {
        GeneratedLearningPlan.SuggestedVideo(
            title: title,
            channel: channel,
            url: "https://www.youtube.com/watch?v=\(videoID)",
            reason: "A grade-appropriate video about \(topic), one of this week's practice topics."
        )
    }

    private func makeActivity(
        year: Int,
        subjectName: String,
        weekNumber: Int,
        assignmentNumber: Int,
        pageNumber: Int,
        assessment: Bool,
        resource: MEPSubject.Resource?,
        planInstanceID: String?
    ) -> GeneratedLearningPlan.PlannedActivity {
        let label = assessment ? "Weekly Practice Book check" : "Practice Book page \(pageNumber)"
        let localPage = resource.flatMap { numberRange(in: $0.title)?.lowerBound }.map { pageNumber - $0 + 1 }
        let answerKey = resource.flatMap { workbook in
            subjectResourceAnswerKey(for: workbook, in: MEPSubject.catalog.first { $0.id == "mep-year-\(year)-math" })
        }
        return GeneratedLearningPlan.PlannedActivity(
            id: "mep-v3-y\(year)-w\(weekNumber)-\(assessment ? "check" : "practice-\(assignmentNumber)")\(planInstanceID.map { "-copy-\($0)" } ?? "")",
            title: "\(label) · Lesson \(pageNumber)",
            subject: subjectName,
            prompt: assessment
                ? "Complete this original MEP Practice Book page as the weekly check. Show your work on the page, then compare with the official answer key."
                : "Complete the original MEP Practice Book page shown below. Write directly on the page and use the linked answer key to review your work.",
            questions: [],
            questionSkills: [],
            questionIllustrations: [],
            writingSpaceMultipliers: [],
            resourceURL: resource?.url,
            resourceTitle: resource.map { _ in "\(subjectName) Practice Book · page \(pageNumber)" },
            resourcePageNumber: localPage,
            printedPageNumber: pageNumber,
            answerKeyResourceURL: answerKey?.url,
            answerKey: [],
            rubric: "Use the linked official MEP Practice Book answer key to review the student's work.",
            points: 0
        )
    }

    private func lessonRange(for weekNumber: Int, lessonCount: Int) -> ClosedRange<Int> {
        let baseCount = lessonCount / weeksPerCourse
        let remainder = lessonCount % weeksPerCourse
        let firstLesson = (weekNumber - 1) * baseCount + min(weekNumber - 1, remainder) + 1
        let lessonCountForWeek = baseCount + (weekNumber <= remainder ? 1 : 0)
        return firstLesson...(firstLesson + lessonCountForWeek - 1)
    }

    private func sampledPracticePages(in lessons: ClosedRange<Int>) -> [Int] {
        guard lessons.count > 1 else { return Array(repeating: lessons.lowerBound, count: worksheetsPerWeek) }
        return (0..<worksheetsPerWeek).map { index in
            lessons.lowerBound + ((lessons.count - 1) * index / (worksheetsPerWeek - 1))
        }
    }

    private func resources(
        in subject: MEPSubject,
        category: String,
        overlapping lessonRange: ClosedRange<Int>
    ) -> [MEPSubject.Resource] {
        subject.resources.filter { resource in
            guard resource.category == category,
                  let range = numberRange(in: resource.title) else { return false }
            return range.overlaps(lessonRange)
        }
    }

    private func subjectResourceAnswerKey(for workbook: MEPSubject.Resource, in subject: MEPSubject?) -> MEPSubject.Resource? {
        guard let range = numberRange(in: workbook.title), let subject else { return nil }
        return subject.resources.first { $0.category == "Answer keys" && numberRange(in: $0.title) == range }
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
