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
            if let id = saved?.prebuiltSubjectID,
               let curriculum = MEPSubject.catalog.first(where: { $0.id == id }) {
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
                        trackedSkills: saved.plan.progress.map(\.subject)
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
    let student: StudentProfile
    let subject: String
    let week: GeneratedLearningPlan.Week
    let trackedSkills: [String]
    @State private var didCopyPrompt = false
    @State private var showingTutorChat = false

    var body: some View {
        Section("Week \(week.weekNumber) · \(week.theme)") {
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
                if let video = week.youtubeVideo, let destination = video.destination {
                    VStack(alignment: .leading, spacing: 5) {
                        Label("Weekly video", systemImage: "play.rectangle.fill")
                            .font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                        Link(destination: destination) {
                            Label(video.title, systemImage: "play.fill")
                                .font(.subheadline.weight(.semibold))
                                .multilineTextAlignment(.leading)
                        }
                        Text("\(video.channel) · \(video.reason)")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.red.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
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

            NavigationLink {
                AssignmentWorkspaceView(assignment: week.assessment.makeAssignment(
                    studentID: student.id,
                    subject: subject,
                    weekNumber: week.weekNumber,
                    assessment: true,
                    trackedSkills: trackedSkills
                ))
            } label: {
                Label(assessmentTitle, systemImage: "checkmark.seal").foregroundStyle(.orange)
            }

            ForEach(week.assignments) { activity in
                NavigationLink {
                    AssignmentWorkspaceView(assignment: activity.makeAssignment(
                        studentID: student.id,
                        subject: subject,
                        weekNumber: week.weekNumber,
                        trackedSkills: trackedSkills
                    ))
                } label: {
                    Label(activity.title, systemImage: "doc.text")
                }
            }
        }
    }

    private var assessmentTitle: String {
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
