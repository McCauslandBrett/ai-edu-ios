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
