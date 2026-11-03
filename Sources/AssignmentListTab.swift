import SwiftUI

struct AssignmentListTab: View {
    @EnvironmentObject private var profiles: StudentProfileStore
    let student: StudentProfile

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
                    NavigationLink {
                        AssignmentWorkspaceView(assignment: assignment)
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "doc.text")
                                .font(.title2).foregroundStyle(.indigo)
                                .frame(width: 44, height: 44)
                                .background(.indigo.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                            VStack(alignment: .leading, spacing: 4) {
                                Text(assignment.subject.uppercased()).font(.caption.weight(.bold)).foregroundStyle(.secondary)
                                Text(assignment.title).font(.headline)
                                Text("Due \(assignment.dueDate) · \(assignment.points) points").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(assignment.status).font(.caption.weight(.semibold)).foregroundStyle(.orange)
                        }
                        .padding(.vertical, 6)
                    }
                }
            }
        }
    }
}
