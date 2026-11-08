import SwiftUI

struct AssignmentListTab: View {
    @EnvironmentObject private var profiles: StudentProfileStore
    let student: StudentProfile
    private let gradeStore = AssignmentGradeStore()

    private var assignments: [Assignment] {
        profiles.assignments(for: student)
    }

    var body: some View {
        List {
            Section("\(student.name)'s work") {
                if assignments.isEmpty {
                    ContentUnavailableView("No assignments yet", systemImage: "doc.text", description: Text("Assignments for this student's subjects will appear here."))
                }
                ForEach(assignments) { assignment in
                    let complete = profiles.isAssignmentComplete(assignment, studentID: student.id)
                    NavigationLink {
                        AssignmentWorkspaceView(assignment: assignment)
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "doc.text")
                                .font(.title2).foregroundStyle(complete ? Color.green : Color.indigo)
                                .frame(width: 44, height: 44)
                                .background((complete ? Color.green : Color.indigo).opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                            VStack(alignment: .leading, spacing: 4) {
                                Text(assignment.subject.uppercased()).font(.caption.weight(.bold)).foregroundStyle(.secondary)
                                Text(assignment.title).font(.headline)
                                Text("Due \(assignment.dueDate) · \(assignment.points) points").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(status(for: assignment))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(statusColor(for: assignment))
                        }
                        .padding(.vertical, 6)
                    }
                }
            }
        }
    }

    private func status(for assignment: Assignment) -> String {
        if profiles.isAssignmentComplete(assignment, studentID: student.id) { return "Complete" }
        guard let grade = gradeStore.load(assignmentID: assignment.id), assignment.isHomework else {
            return assignment.status
        }
        return grade.isPassing ? "Passed" : "Failed"
    }

    private func statusColor(for assignment: Assignment) -> Color {
        if profiles.isAssignmentComplete(assignment, studentID: student.id) { return .green }
        guard let grade = gradeStore.load(assignmentID: assignment.id), assignment.isHomework else {
            return .orange
        }
        return grade.isPassing ? .green : .red
    }
}
