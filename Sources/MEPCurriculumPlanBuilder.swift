import Foundation

protocol MEPCurriculumPlanBuilding: PrebuiltSubjectPlanBuilding {}

/// Converts the MEP catalogue into a four-week plan whose worksheet activities open
/// the original Practice Book pages. It does not invent substitute worksheet questions.
struct MEPCurriculumPlanBuilder: MEPCurriculumPlanBuilding {
    private let weeksPerCourse = 4
    private let worksheetsPerWeek = 4
    private let videoCatalog: any MEPWeeklyVideoProviding
    private let skills = [
        "Number and calculation",
        "Patterns and mathematical reasoning",
        "Geometry and spatial reasoning",
        "Measurement and data"
    ]

    init(videoCatalog: any MEPWeeklyVideoProviding = MEPVideoCatalog()) {
        self.videoCatalog = videoCatalog
    }

    func overview(for subject: MEPSubject, weekNumber: Int) -> String {
        let year = yearNumber(in: subject)
        let lessonCount = year == 6 ? 175 : 140
        let lessons = lessonRange(for: weekNumber, lessonCount: lessonCount)
        let pages = sampledPracticePages(in: lessons)
        return "Compressed month plan · MEP lessons \(lessons.lowerBound)–\(lessons.upperBound). This week uses original Practice Book pages \(pages.map(String.init).joined(separator: ", ")); each page includes its printed exercises, diagrams, and response areas."
    }

    func build(
        subject: MEPSubject,
        studentID: String,
        subjectName: String? = nil,
        planInstanceID: String? = nil
    ) -> StudentSubjectPlan {
        let planSubject = subject.named(subjectName ?? subject.name)
        let year = yearNumber(in: planSubject)
        let lessonCount = year == 6 ? 175 : 140
        let weekCount = weeksPerCourse
        let objective = "Complete a four-week accelerated survey of MEP Math Level \(year). Each week covers about one quarter of the level and uses four original Practice Book pages spaced across that material."
        let weeks = (1...weekCount).map { weekNumber in
            makeWeek(
                weekNumber,
                year: year,
                lessonCount: lessonCount,
                subject: planSubject,
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
            subject: planSubject.name,
            objective: objective,
            monthlyWindow: "4-week accelerated MEP Math Level \(year) plan · four Practice Book worksheets per week",
            milestones: milestones,
            progress: progress,
            weeks: weeks
        )
        return StudentSubjectPlan(
            studentID: studentID,
            subject: planSubject.name,
            inputs: SubjectPlanInputs(
                targetedSkills: skills,
                learningOutcome: objective,
                highestAssessmentLevel: "",
                priorAssessmentResults: [],
                instructorContext: "CIMT Mathematics Enhancement Programme · MEP Math Level \(year)"
            ),
            plan: plan,
            prebuiltSubjectID: planSubject.id,
            prebuiltContentVersion: subject.contentVersion,
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
        let weeklyVideos = videoCatalog.videos(for: year, weekNumber: weekNumber)
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
        let localPage = resource.flatMap { selectedResource in
            numberRange(in: selectedResource.title).map {
                selectedResource.pdfStartPage + pageNumber - $0.lowerBound
            }
        }
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
