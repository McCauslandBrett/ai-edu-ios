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
                    if !student.summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(student.summary)
                            .font(.body).foregroundStyle(.white.opacity(0.9))
                            .padding(.top, 5)
                    }
                }
                .padding(22)
                .foregroundStyle(.white)
                .background(LinearGradient(colors: [.indigo, Color(red: 0.12, green: 0.16, blue: 0.38)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 24))

                HStack {
                    Text("Subject progress").font(.title2.bold())
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

                DashboardActivitySection(events: profiles.activity(for: student.id))
            }
            .padding(20)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .background(Color(uiColor: .systemGroupedBackground))
    }

    private var studentDetails: String {
        var details = ["Age \(student.age.map(String.init) ?? "not set")"]
        if !student.gradeLevel.isEmpty { details.append(student.gradeLevel) }
        details.append(student.subjects.isEmpty ? "No subjects yet" : student.subjects.joined(separator: ", "))
        return details.joined(separator: " · ")
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
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Recent activity").font(.title2.bold())
                    Text("Assignment submissions and assessments")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "calendar.badge.clock")
                    .font(.title2).foregroundStyle(.indigo)
            }

            HStack(spacing: 12) {
                ActivityCountCard(title: "Assignments this week", count: thisWeek.filter { $0.kind == .assignment }.count)
                ActivityCountCard(title: "Assessments this week", count: thisWeek.filter { $0.kind == .assessment }.count)
            }

            if events.isEmpty {
                ContentUnavailableView(
                    "No activity recorded yet",
                    systemImage: "checklist",
                    description: Text("Grading completed work records its submission date here.")
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

                if events.count > 8 {
                    Button(showsAllActivity ? "Show less" : "Show all \(events.count) records") {
                        showsAllActivity.toggle()
                    }
                    .font(.subheadline.weight(.semibold))
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(.quaternary))
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
        event.kind == .assessment ? "Assessment taken" : "Assignment submitted"
    }

    private var resultText: String {
        if event.kind == .assessment {
            return "\(event.score.formatted()) / \(event.total.formatted()) points · \(event.correctQuestions)/\(event.questionCount) correct"
        }
        let outcome = event.passed == true ? "Passed" : "Needs another attempt"
        return "\(outcome) · \(event.correctQuestions)/\(event.questionCount) correct"
    }

    private var resultColor: Color {
        event.kind == .assessment ? .indigo : (event.passed == true ? .green : .orange)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: event.kind == .assessment ? "checkmark.seal.fill" : "doc.text.fill")
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
