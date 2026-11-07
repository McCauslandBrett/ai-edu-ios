import SwiftUI

struct SubjectsTab: View {
    @EnvironmentObject private var profiles: StudentProfileStore
    @State private var showingSubjectForm = false
    @State private var subjectFormCloseRequested = false
    @State private var subjectPendingDeletion: String?
    let student: StudentProfile

    private var subjects: [String] {
        profiles.subjects(for: student)
    }

    var body: some View {
        List {
            Section {
                if subjects.isEmpty {
                    ContentUnavailableView(
                        "No subjects yet",
                        systemImage: "books.vertical",
                        description: Text("Add a subject to generate this student's first learning plan.")
                    )
                }
                ForEach(subjects, id: \.self) { subject in
                    SubjectListRow(
                        student: student,
                        subject: subject,
                        saved: profiles.subjectPlan(for: student.id, subject: subject),
                        fallback: StudentLearningPlanTemplates.forStudent(student.id, subject: subject),
                        assignments: profiles.assignments(for: student, subject: subject),
                        onDelete: { subjectPendingDeletion = subject }
                    )
                }
            } header: {
                Text("\(student.name)'s subjects")
            } footer: {
                Text("Tap a subject to view its plan and assignments. Add a subject to generate a personalized four-week plan.")
            }
        }
        .confirmationDialog(
            "Delete \(subjectPendingDeletion ?? "subject")?",
            isPresented: deletionConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("Delete Subject", role: .destructive) {
                if let subject = subjectPendingDeletion {
                    profiles.deleteSubject(studentID: student.id, subject: subject)
                }
                subjectPendingDeletion = nil
            }
            Button("Cancel", role: .cancel) { subjectPendingDeletion = nil }
        } message: {
            Text("This removes the subject and its generated learning plan from this student's profile. Saved handwritten assignment work is kept.")
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                subjectFormCloseRequested = false
                showingSubjectForm = true
            } label: {
                Label("Add subject and generate plan", systemImage: "sparkles")
                    .font(.headline)
                    .frame(maxWidth: 600)
                    .padding(.vertical, 14)
                    .background(.indigo, in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(.white)
            }
            .padding()
        }
        .fullScreenCover(isPresented: subjectFormPresentation) {
            SubjectPlanCreationView(
                student: student,
                onCreate: { profiles.saveSubjectPlan($0) },
                onClose: closeSubjectForm
            )
            .interactiveDismissDisabled()
        }
    }

    private var subjectFormPresentation: Binding<Bool> {
        Binding(
            get: { showingSubjectForm },
            set: { isPresented in
                if isPresented {
                    showingSubjectForm = true
                } else if subjectFormCloseRequested {
                    showingSubjectForm = false
                    subjectFormCloseRequested = false
                }
            }
        )
    }

    private func closeSubjectForm() {
        subjectFormCloseRequested = true
        showingSubjectForm = false
    }

    private var deletionConfirmationPresented: Binding<Bool> {
        Binding(
            get: { subjectPendingDeletion != nil },
            set: { if !$0 { subjectPendingDeletion = nil } }
        )
    }
}

private struct SubjectListRow: View {
    let student: StudentProfile
    let subject: String
    let saved: StudentSubjectPlan?
    let fallback: StudentLearningPlan
    let assignments: [Assignment]
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            NavigationLink {
                SubjectPlanView(
                    student: student,
                    subject: subject,
                    saved: saved,
                    fallback: fallback,
                    assignments: assignments
                )
            } label: {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Label(subject, systemImage: SubjectIconCatalog.icon(for: subject)).font(.headline)
                        Spacer()
                        planStatus
                    }
                    if let saved {
                        ProgressView(value: averageProgress(in: saved.plan.progress), total: 100).tint(.indigo)
                        Text(saved.plan.objective).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                    } else {
                        Text(fallback.focus).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                    }
                }
                .padding(.vertical, 8)
            }

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.body.weight(.medium))
                    .foregroundStyle(.red)
                    .frame(width: 40, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Delete \(subject)")
        }
    }

    @ViewBuilder
    private var planStatus: some View {
        if let saved {
            Text("\(saved.plan.progress.first?.completion ?? 0, specifier: "%.0f")%")
                .font(.caption.weight(.bold)).foregroundStyle(.indigo)
        } else {
            Text("Plan template").font(.caption).foregroundStyle(.secondary)
        }
    }

    private func averageProgress(in progress: [GeneratedLearningPlan.Progress]) -> Double {
        guard !progress.isEmpty else { return 0 }
        return progress.map(\.completion).reduce(0, +) / Double(progress.count)
    }
}

private enum SubjectIconCatalog {
    static func icon(for subject: String) -> String {
        let value = subject.lowercased()
        if value.contains("math") || value.contains("algebra") { return "function" }
        if value.contains("read") || value.contains("writing") { return "book" }
        if value.contains("science") || value.contains("biology") { return "atom" }
        return "text.book.closed"
    }
}
