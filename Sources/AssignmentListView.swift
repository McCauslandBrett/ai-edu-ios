import SwiftUI

struct AssignmentListView: View {
    @EnvironmentObject private var documents: AssignmentDocumentStore

    var body: some View {
        NavigationStack {
            List(Assignment.samples) { assignment in
                NavigationLink(value: assignment) {
                    AssignmentRow(assignment: assignment)
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }
            .listStyle(.plain)
            .navigationTitle("My assignments")
            .navigationDestination(for: Assignment.self) { assignment in
                AssignmentWorkspaceView(assignment: assignment)
            }
            .safeAreaInset(edge: .bottom) {
                Text("Handwriting saves automatically on this iPad")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(.bar)
            }
        }
    }
}

private struct AssignmentRow: View {
    let assignment: Assignment

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "doc.text")
                .font(.title2)
                .foregroundStyle(.indigo)
                .frame(width: 46, height: 46)
                .background(.indigo.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
                Text(assignment.subject.uppercased())
                    .font(.caption.weight(.semibold))
                    .tracking(0.7)
                    .foregroundStyle(.secondary)
                Text(assignment.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text("\(assignment.dueDate) · \(assignment.points) points")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.quaternary, lineWidth: 1))
    }
}
