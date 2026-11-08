import SwiftUI
import UIKit

struct SubjectPlanView: View {
    let student: StudentProfile
    let subject: String
    let saved: StudentSubjectPlan?
    let fallback: StudentLearningPlan
    let assignments: [Assignment]

    var body: some View {
        List {
            SubjectPlanOverviewSection(student: student, subject: subject, saved: saved, fallback: fallback)
            if let curriculum = prebuiltCurriculum {
                Section("MEP curriculum") {
                    NavigationLink("Open workbooks and teaching materials") {
                        MEPResourceView(subject: curriculum, onAdd: nil)
                    }
                }
            }
            if let saved {
                TrackedSkillsSection(progress: saved.plan.progress)
                ForEach(saved.plan.weeks) { week in
                    SubjectWeekSection(
                        student: student,
                        subject: subject,
                        week: week,
                        trackedSkills: saved.plan.progress.map(\.subject),
                        fullYearWeekCount: saved.plan.monthlyWindow.hasPrefix("Full-year") ? saved.plan.weeks.count : nil,
                        prebuiltSubject: prebuiltCurriculum
                    )
                }
            } else {
                PlanTemplateSection(fallback: fallback)
            }
            SubjectAssignmentsSection(subject: subject, assignments: assignments)
        }
        .navigationTitle(subject)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var prebuiltCurriculum: MEPSubject? {
        guard let id = saved?.prebuiltSubjectID else { return nil }
        return MEPSubject.catalog.first { $0.id == id }
    }
}

private struct SubjectPlanOverviewSection: View {
    let student: StudentProfile
    let subject: String
    let saved: StudentSubjectPlan?
    let fallback: StudentLearningPlan

    var body: some View {
        Section("Subject learning plan") {
            VStack(alignment: .leading, spacing: 10) {
                Text("\(student.name) · Age \(student.age.map(String.init) ?? "not set") · \(student.gradeLevel)")
                    .font(.caption.weight(.bold)).foregroundStyle(.indigo)
                Text(subject).font(.largeTitle.bold())
                Text(saved?.plan.objective ?? fallback.focus).font(.body).foregroundStyle(.secondary)
                Text(saved?.plan.monthlyWindow ?? fallback.month)
                    .font(.subheadline.weight(.medium)).foregroundStyle(.secondary)
                if let saved, !saved.inputs.targetedSkills.isEmpty {
                    Text("Target skills: " + saved.inputs.targetedSkills.joined(separator: ", "))
                        .font(.subheadline)
                }
            }
            .padding(.vertical, 8)
        }
    }
}

private struct TrackedSkillsSection: View {
    let progress: [GeneratedLearningPlan.Progress]

    var body: some View {
        Section("Tracked skills") {
            ForEach(progress) { item in
                ProgressRow(progress: SubjectProgress(
                    subject: item.subject,
                    completion: Int(item.completion.rounded()),
                    nextMilestone: item.nextMilestone,
                    status: item.status
                ))
            }
        }
    }
}

private struct SubjectWeekSection: View {
    @EnvironmentObject private var profiles: StudentProfileStore
    let student: StudentProfile
    let subject: String
    let week: GeneratedLearningPlan.Week
    let trackedSkills: [String]
    let fullYearWeekCount: Int?
    let prebuiltSubject: MEPSubject?
    @State private var didCopyPrompt = false
    @State private var showingTutorChat = false

    var body: some View {
        Section("Week \(week.weekNumber) · \(week.theme)") {
            Text(weekOverview)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Tutor lecture prompt", systemImage: "bubble.left.and.bubble.right")
                        .font(.headline).foregroundStyle(.indigo)
                    Spacer()
                    Button {
                        UIPasteboard.general.string = week.lecturePrompt
                        didCopyPrompt = true
                    } label: {
                        Label(didCopyPrompt ? "Copied" : "Copy prompt", systemImage: didCopyPrompt ? "checkmark" : "doc.on.doc")
                            .font(.subheadline.weight(.medium))
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(didCopyPrompt ? "Prompt copied" : "Copy tutor lecture prompt")
                }
                Text(week.lecturePrompt).font(.subheadline)
                if !weeklyVideos.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Weekly videos", systemImage: "play.rectangle.fill")
                            .font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                        ForEach(weeklyVideos, id: \.url) { video in
                            VisitedVideoLink(video: video, studentID: student.id)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                Button {
                    showingTutorChat = true
                } label: {
                    Label("Open whiteboard chat", systemImage: "scribble.variable")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.borderless)
            }
            .padding(.vertical, 6)
            .fullScreenCover(isPresented: $showingTutorChat) {
                TutorChatView(
                    student: student,
                    subject: subject,
                    weekNumber: week.weekNumber,
                    lecturePrompt: week.lecturePrompt
                )
            }

            let assessment = week.assessment.makeAssignment(
                studentID: student.id, subject: subject, weekNumber: week.weekNumber,
                assessment: true, trackedSkills: trackedSkills)
            NavigationLink {
                AssignmentWorkspaceView(assignment: assessment)
            } label: {
                assignmentLabel(assessmentTitle, assignment: assessment, assessment: true)
            }

            ForEach(week.assignments) { activity in
                let assignment = activity.makeAssignment(
                    studentID: student.id, subject: subject, weekNumber: week.weekNumber,
                    trackedSkills: trackedSkills)
                NavigationLink {
                    AssignmentWorkspaceView(assignment: assignment)
                } label: {
                    assignmentLabel(activity.title, assignment: assignment)
                }
            }
        }
    }

    private func assignmentLabel(_ title: String, assignment: Assignment, assessment: Bool = false) -> some View {
        let complete = profiles.isAssignmentComplete(assignment, studentID: student.id)
        return Label {
            Text(title).foregroundStyle(assessment ? Color.orange : Color.primary)
        } icon: {
            Image(systemName: assessment ? "checkmark.seal" : "doc.text")
                .foregroundStyle(complete ? Color.green : (assessment ? Color.orange : Color.indigo))
        }
        .accessibilityValue(complete ? "Complete" : "Not complete")
    }

    private var weekOverview: String {
        if let prebuiltSubject {
            return MEPCurriculumPlanBuilder().overview(for: prebuiltSubject, weekNumber: week.weekNumber)
        }
        if let overview = week.overview, !overview.isEmpty {
            return overview
        }
        let assignmentCount = week.assignments.count
        let assignmentLabel = assignmentCount == 1 ? "practice assignment" : "practice assignments"
        return "Coverage: \(week.theme), with \(assignmentCount) planned \(assignmentLabel) and a weekly assessment."
    }

    private var weeklyVideos: [GeneratedLearningPlan.SuggestedVideo] {
        if let videos = week.youtubeVideos, !videos.isEmpty { return videos }
        return week.youtubeVideo.map { [$0] } ?? []
    }

    private var assessmentTitle: String {
        if let fullYearWeekCount {
            if week.weekNumber == 1 { return "Baseline assessment" }
            if week.weekNumber == fullYearWeekCount { return "Year-end assessment" }
            return "Week \(week.weekNumber) skills check"
        }
        switch week.weekNumber {
        case 1: return "Baseline assessment"
        case 4: return "Final assessment"
        default: return "Week \(week.weekNumber) assessment"
        }
    }
}

private struct PlanTemplateSection: View {
    let fallback: StudentLearningPlan

    var body: some View {
        Section("Plan template") {
            Text("This is a preview. Add this subject with the form to generate a personalized four-week AI plan.")
                .font(.subheadline).foregroundStyle(.secondary)
            ForEach(fallback.progress) { ProgressRow(progress: $0) }
        }
    }
}

private struct SubjectAssignmentsSection: View {
    @EnvironmentObject private var profiles: StudentProfileStore
    let subject: String
    let assignments: [Assignment]

    var body: some View {
        Section("All assignments · \(subject)") {
            if assignments.isEmpty {
                ContentUnavailableView(
                    "No assignments yet",
                    systemImage: "doc.text",
                    description: Text("Assignments generated for this subject will appear here.")
                )
            }
            ForEach(assignments) { assignment in
                NavigationLink {
                    AssignmentWorkspaceView(assignment: assignment)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(assignment.title).font(.headline)
                        if profiles.isAssignmentComplete(assignment, studentID: assignment.studentID ?? profiles.selectedStudent.id) {
                            Label("Complete", systemImage: "checkmark.circle.fill").font(.caption).foregroundStyle(.green)
                        }
                        Text("\(assignment.dueDate) · \(assignment.points) points")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

struct MEPResourceView: View {
    let subject: MEPSubject
    let onAdd: (() -> Void)?

    private var categories: [String] {
        var result: [String] = []
        for resource in subject.resources where !result.contains(resource.category) {
            result.append(resource.category)
        }
        return result
    }

    var body: some View {
        List {
            Section {
                Text("Mathematics Enhancement Programme · CIMT").font(.headline)
                Text("Start with Learning Objectives and the shared guidelines. Follow the lesson plans alongside the practice books at your child's pace.")
                if let onAdd {
                    Button("Add \(subject.name)", action: onAdd)
                        .font(.headline)
                }
            }
            ForEach(categories, id: \.self) { category in
                Section(category) {
                    ForEach(subject.resources.filter { $0.category == category }) { resource in
                        if let url = URL(string: resource.url) {
                            Link(destination: url) {
                                Label(resource.title, systemImage: "doc.text")
                            }
                        }
                    }
                }
            }
            Section {
                Link("Original MEP curriculum", destination: URL(string: "https://www.cimt.org.uk/projects/mepres/primary/index.htm")!)
                Text("Copyright belongs to the original creators. CIMT provides these materials for downloading and dissemination for non-profit making purposes only. Resources open from CIMT and require internet access.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .navigationTitle(subject.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// A successful link open marks the URL visited for this student, including in other weeks.
private struct VisitedVideoLink: View {
    @Environment(\.openURL) private var openURL
    @AppStorage private var visited: Bool
    let video: GeneratedLearningPlan.SuggestedVideo

    init(video: GeneratedLearningPlan.SuggestedVideo, studentID: String) {
        self.video = video
        _visited = AppStorage(wrappedValue: false, "visited-video::\(studentID)::\(video.url)")
    }

    var body: some View {
        if let destination = video.destination {
            Button {
                openURL(destination) { accepted in
                    if accepted { visited = true }
                }
            } label: {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(alignment: .firstTextBaseline) {
                        Label(video.title, systemImage: "play.fill")
                            .font(.subheadline.weight(.semibold))
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 8)
                        if visited {
                            Label("Visited", systemImage: "checkmark.circle.fill")
                                .font(.caption).foregroundStyle(.green)
                        }
                    }
                    Text("\(video.channel) · \(video.reason)")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background((visited ? Color.green : Color.red).opacity(0.08),
                            in: RoundedRectangle(cornerRadius: 12))
                .contentShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.indigo)
            .accessibilityValue(visited ? "Visited" : "Not visited")
        }
    }
}
