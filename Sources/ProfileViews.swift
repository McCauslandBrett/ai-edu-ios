import SwiftUI

struct ProfileTab: View {
    @EnvironmentObject private var profiles: StudentProfileStore
    let student: StudentProfile
    let onEdit: () -> Void

    var body: some View {
        List {
            Section {
                HStack(spacing: 16) {
                    Text(initials(student.name))
                        .font(.title2.bold()).foregroundStyle(.indigo)
                        .frame(width: 64, height: 64)
                        .background(.indigo.opacity(0.12), in: Circle())
                    VStack(alignment: .leading, spacing: 5) {
                        Text(student.name).font(.title3.bold())
                        Text("Age \(student.age.map(String.init) ?? "not set") · \(student.gradeLevel)").foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 8)
                Button("Edit profile", systemImage: "square.and.pencil", action: onEdit)
            }
            Section("Student summary") {
                Text(student.summary)
                    .foregroundStyle(.secondary)
                LabeledContent("Subjects", value: "\(profiles.subjects(for: student).count)")
            }
            Section("Profiles") {
                Text("Use the student menu in the top right to switch profiles or add another student.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }

    private func initials(_ name: String) -> String {
        name.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined()
    }
}

struct ProgressRow: View {
    let progress: SubjectProgress

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(progress.subject).font(.headline)
                Spacer()
                Text("\(progress.completion)%").font(.subheadline.weight(.bold)).foregroundStyle(.indigo)
            }
            ProgressView(value: Double(progress.completion), total: 100).tint(.indigo)
            Text(progress.nextMilestone).font(.caption).foregroundStyle(.secondary)
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.quaternary))
    }
}

struct ProfileEditor: View {
    @Environment(\.dismiss) private var dismiss
    let original: StudentProfile?
    let canDeleteStudent: Bool
    let onDelete: (StudentProfile) -> Void
    let onSave: (StudentProfile) -> Void
    @State private var confirmingDelete = false
    @State private var name: String
    @State private var age: String
    @State private var grade: String
    @State private var summary: String

    init(
        profile: StudentProfile?,
        canDeleteStudent: Bool = false,
        onDelete: @escaping (StudentProfile) -> Void = { _ in },
        onSave: @escaping (StudentProfile) -> Void
    ) {
        original = profile
        self.canDeleteStudent = canDeleteStudent
        self.onDelete = onDelete
        self.onSave = onSave
        _name = State(initialValue: profile?.name ?? "")
        _age = State(initialValue: profile?.age.map(String.init) ?? "")
        _grade = State(initialValue: profile?.gradeLevel ?? "")
        _summary = State(initialValue: profile?.summary ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                studentSection
                learningSummarySection
                deleteStudentSection
            }
            .navigationTitle(original == nil ? "Add student" : "Edit profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { editorToolbar }
            .confirmationDialog(
                "Delete \(original?.name ?? "student")?",
                isPresented: $confirmingDelete,
                titleVisibility: .visible
            ) {
                deleteConfirmationActions
            } message: {
                deleteConfirmationMessage
            }
        }
    }

    private var studentSection: some View {
        Section("Student") {
            TextField("Name", text: $name)
            TextField("Age", text: $age).keyboardType(.numberPad)
            TextField("School grade level", text: $grade)
        }
    }

    private var learningSummarySection: some View {
        Section("Learning summary") {
            TextEditor(text: $summary).frame(minHeight: 120)
        }
    }

    @ViewBuilder
    private var deleteStudentSection: some View {
        if let original {
            Section("Delete student") {
                Button("Delete \(original.name)", role: .destructive) {
                    confirmingDelete = true
                }
                .disabled(!canDeleteStudent)

                if !canDeleteStudent {
                    Text("Add another student before deleting the only profile.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    @ToolbarContentBuilder
    private var editorToolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
            Button("Save", action: saveProfile)
                .disabled(cleanedName.isEmpty)
        }
    }

    @ViewBuilder
    private var deleteConfirmationActions: some View {
        Button("Delete Student", role: .destructive, action: deleteOriginalStudent)
        Button("Cancel", role: .cancel) { }
    }

    private var deleteConfirmationMessage: some View {
        Text("This permanently deletes the student's profile, plans, progress, activity, grades, and handwritten work from this iPad.")
    }

    private var cleanedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var cleanedGradeLevel: String {
        let value = grade.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? "Not set" : value
    }

    private func saveProfile() {
        guard let profile = makeProfile() else { return }
        onSave(profile)
        dismiss()
    }

    private func makeProfile() -> StudentProfile? {
        guard !cleanedName.isEmpty else { return nil }
        return StudentProfile(
            id: original?.id ?? UUID().uuidString,
            name: cleanedName,
            age: Int(age),
            gradeLevel: cleanedGradeLevel,
            subjects: original?.subjects ?? [],
            summary: summary.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    private func deleteOriginalStudent() {
        guard let original else { return }
        onDelete(original)
        dismiss()
    }
}
