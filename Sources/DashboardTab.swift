import SwiftUI

struct DashboardTab: View {
    @EnvironmentObject private var profiles: StudentProfileStore
    let student: StudentProfile
    let editProfile: () -> Void
    private var savedPlans: [StudentSubjectPlan] {
        profiles.subjectPlans.values
            .filter { $0.studentID == student.id }
            .sorted { $0.subject.localizedCaseInsensitiveCompare($1.subject) == .orderedAscending }
    }
    private var progress: [SubjectProgress] {
        savedPlans.flatMap { saved in
            saved.plan.progress.map { skill in
                SubjectProgress(
                    subject: "\(saved.subject) · \(skill.subject)",
                    completion: Int(skill.completion.rounded()),
                    nextMilestone: skill.nextMilestone,
                    status: skill.status
                )
            }
        }.prefix(6).map { $0 }
    }
    private var nextMilestone: (subject: String, milestone: GeneratedLearningPlan.Milestone)? {
        savedPlans.compactMap { saved in
            saved.plan.milestones.first.map { (saved.subject, $0) }
        }.first
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                studentOverview
                assignmentCompletionSection
                progressSection
                nextMilestoneSection
                DashboardActivitySection(events: profiles.activity(for: student.id))
            }
            .padding(20)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .background(Color(uiColor: .systemGroupedBackground))
    }

    private var studentOverview: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("STUDENT OVERVIEW")
                .font(.caption.weight(.bold)).tracking(1.1)
                .foregroundStyle(.white.opacity(0.72))
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(student.name).font(.largeTitle.bold())
                    Text(studentDetails)
                        .font(.subheadline).foregroundStyle(.white.opacity(0.78))
                }
                Spacer()
                Button(action: editProfile) {
                    Image(systemName: "square.and.pencil")
                        .font(.headline).foregroundStyle(.white)
                        .padding(10).background(.white.opacity(0.15), in: Circle())
                }
                .accessibilityLabel("Edit student profile")
            }
            if hasRealSummary {
                Text(student.summary)
                    .font(.body).foregroundStyle(.white.opacity(0.9))
                    .padding(.top, 5)
            }
        }
        .padding(22)
        .foregroundStyle(.white)
        .background(
            LinearGradient(
                colors: [.indigo, Color(red: 0.12, green: 0.16, blue: 0.38)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 24)
        )
    }

    private var assignmentCompletionSection: some View {
        let assignments = profiles.assignments(for: student)
        let completed = assignments.filter { profiles.isAssignmentComplete($0, studentID: student.id) }.count
        let subjects = Array(Set(assignments.map(\.subject))).sorted()
        return VStack(alignment: .leading, spacing: 14) {
            Text("Assignment completion").font(.title2.bold())
            Text("\(completed) of \(assignments.count) complete")
                .font(.headline).foregroundStyle(.indigo)
            Text("Use Mark complete at the bottom of an assignment. Skill progress below reflects graded answers.")
                .font(.caption).foregroundStyle(.secondary)
            if assignments.isEmpty {
                Text("Add a subject to start tracking assignments.").foregroundStyle(.secondary)
            }
            ForEach(subjects, id: \.self) { subject in
                let work = assignments.filter { $0.subject == subject }
                let done = work.filter { profiles.isAssignmentComplete($0, studentID: student.id) }.count
                VStack(alignment: .leading, spacing: 6) {
                    Text(subject).font(.headline)
                    ProgressView(value: Double(done), total: Double(max(work.count, 1)))
                        .tint(.green)
                        .accessibilityLabel("\(subject) assignment completion")
                        .accessibilityValue("\(done) of \(work.count) complete")
                    Text("\(done) of \(work.count) complete · \(Int(Double(done) / Double(max(work.count, 1)) * 100))%")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .padding(18)
        .background(.background, in: RoundedRectangle(cornerRadius: 20))
    }

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Skill progress").font(.title2.bold())
                Spacer()
                if let plan = savedPlans.first?.plan {
                    Text(plan.monthlyWindow).font(.subheadline.weight(.medium)).foregroundStyle(.secondary)
                }
            }
            if progress.isEmpty {
                ContentUnavailableView(
                    "No skill progress yet",
                    systemImage: "chart.bar",
                    description: Text("Add a subject and generate a learning plan to track real progress here.")
                )
                .frame(minHeight: 150)
            } else {
                ForEach(progress) { item in ProgressRow(progress: item) }
            }
        }
    }

    private var nextMilestoneSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Next milestone", systemImage: "sparkles")
                .font(.headline).foregroundStyle(.indigo)
            if let nextMilestone {
                Text(nextMilestone.milestone.title).font(.title3.bold())
                Text("\(nextMilestone.subject) · \(nextMilestone.milestone.date)")
                    .font(.subheadline).foregroundStyle(.secondary)
            } else {
                Text("No milestones yet").font(.title3.bold())
                Text("Milestones will appear after a subject plan is created.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(.quaternary))
    }

    private var studentDetails: String {
        var details = ["Age \(student.age.map(String.init) ?? "not set")"]
        let isUneditedStarterProfile = student.summary == "Keep building confidence with steady practice." &&
            student.gradeLevel == "Grade 3"
        if isUneditedStarterProfile {
            details.append("Grade not set")
        } else if !student.gradeLevel.isEmpty {
            details.append(student.gradeLevel)
        }
        let subjects = profiles.subjects(for: student)
        details.append(subjects.isEmpty ? "No subjects yet" : subjects.joined(separator: ", "))
        return details.joined(separator: " · ")
    }

    private var hasRealSummary: Bool {
        let summary = student.summary.trimmingCharacters(in: .whitespacesAndNewlines)
        return !summary.isEmpty && summary != "Keep building confidence with steady practice."
    }
}

private struct DashboardActivitySection: View {
    let events: [StudentActivityEvent]
    @State private var showsAllActivity = false

    private var thisWeek: [StudentActivityEvent] {
        events.filter { Calendar.current.isDate($0.recordedAt, equalTo: .now, toGranularity: .weekOfYear) }
    }

    private var visibleEvents: [StudentActivityEvent] {
        showsAllActivity ? events : Array(events.prefix(8))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            activityHeader
            weeklyCounts
            activityList
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(.quaternary))
    }

    private var activityHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Recent activity").font(.title2.bold())
                Text("Assignments, assessments, and tutor sessions")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "calendar.badge.clock")
                .font(.title2).foregroundStyle(.indigo)
        }
    }

    private func weeklyWorkCount(_ kind: StudentActivityEvent.Kind) -> Int {
        Set(thisWeek.filter { $0.kind == kind }.map { $0.assignmentID ?? $0.id }).count
    }

    private var weeklyCounts: some View {
        HStack(spacing: 12) {
            ActivityCountCard(title: "Assignments this week", count: weeklyWorkCount(.assignment))
            ActivityCountCard(title: "Assessments this week", count: weeklyWorkCount(.assessment))
            ActivityCountCard(title: "Tutor sessions this week", count: thisWeek.filter { $0.kind == .tutorSession }.count)
        }
    }

    @ViewBuilder
    private var activityList: some View {
        if events.isEmpty {
            ContentUnavailableView(
                "No activity recorded yet",
                systemImage: "checklist",
                description: Text("Mark an assignment complete or grade work to record activity here.")
            )
            .frame(minHeight: 140)
        } else {
            VStack(spacing: 0) {
                ForEach(visibleEvents) { event in
                    ActivityEventRow(event: event)
                    if event.id != visibleEvents.last?.id {
                        Divider().padding(.leading, 50)
                    }
                }
            }
            showAllActivityButton
        }
    }

    @ViewBuilder
    private var showAllActivityButton: some View {
        if events.count > 8 {
            Button(showsAllActivity ? "Show less" : "Show all \(events.count) records") {
                showsAllActivity.toggle()
            }
            .font(.subheadline.weight(.semibold))
        }
    }

}

private struct ActivityCountCard: View {
    let title: String
    let count: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(count)").font(.title2.bold()).foregroundStyle(.indigo)
            Text(title).font(.caption.weight(.medium)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.indigo.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct ActivityEventRow: View {
    let event: StudentActivityEvent

    private var headline: String {
        if event.manuallyCompleted == true {
            return event.kind == .assessment ? "Assessment completed" : "Assignment completed"
        }
        switch event.kind {
        case .assessment: return "Assessment taken"
        case .assignment: return "Assignment submitted"
        case .tutorSession: return "Tutor session completed"
        }
    }

    private var resultText: String {
        if event.manuallyCompleted == true { return "Marked complete · Grading tracked separately" }
        if event.kind == .tutorSession {
            return event.completionNote ?? "Lesson finished"
        } else if event.kind == .assessment {
            return "\(event.score.formatted()) / \(event.total.formatted()) points · \(event.correctQuestions)/\(event.questionCount) correct"
        }
        let outcome = event.passed == true ? "Passed" : "Needs another attempt"
        return "\(outcome) · \(event.correctQuestions)/\(event.questionCount) correct"
    }

    private var resultColor: Color {
        if event.manuallyCompleted == true { return .green }
        switch event.kind {
        case .assessment: return .indigo
        case .assignment: return event.passed == true ? .green : .orange
        case .tutorSession: return .green
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: event.kind == .assessment ? "checkmark.seal.fill" : event.kind == .tutorSession ? "bubble.left.and.bubble.right.fill" : "doc.text.fill")
                .font(.title3).foregroundStyle(resultColor)
                .frame(width: 38, height: 38)
                .background(resultColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 11))
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(headline).font(.subheadline.weight(.semibold))
                    Spacer(minLength: 8)
                    Text(event.recordedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption).foregroundStyle(.secondary)
                }
                Text(event.title).font(.body.weight(.medium))
                Text("\(event.subject) · \(resultText)")
                    .font(.caption).foregroundStyle(resultColor)
            }
        }
        .padding(.vertical, 10)
    }
}
