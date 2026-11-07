import SwiftUI

struct AssignmentChangeRequestView: View {
    @Environment(\.dismiss) private var dismiss
    let onApply: (String) async throws -> Void

    @State private var request = ""
    @State private var isApplying = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Change request") {
                    TextEditor(text: $request).frame(minHeight: 130)
                    Text("Describe what to change and name an exercise or skill when possible.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section("Examples") {
                    Text("Add 5 more problems about counting by 10s.")
                    Text("Give exercise 2 twice as much writing space.")
                    Text("Add an illustration to exercise 3.")
                }
                if let errorMessage { Section { Text(errorMessage).foregroundStyle(.red) } }
            }
            .navigationTitle("Adjust worksheet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.disabled(isApplying)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button { Task { await applyRequest() } } label: {
                        if isApplying { ProgressView() } else { Text("Apply") }
                    }
                    .disabled(isApplying || request.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    @MainActor
    private func applyRequest() async {
        isApplying = true
        errorMessage = nil
        defer { isApplying = false }
        do {
            try await onApply(request.trimmingCharacters(in: .whitespacesAndNewlines))
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
