import SwiftUI

struct LearningHubView: View {
    @EnvironmentObject private var profiles: StudentProfileStore
    @State private var showingAddStudent = false
    @State private var editingProfile: StudentProfile?

    private var student: StudentProfile { profiles.selectedStudent }

    var body: some View {
        TabView {
            NavigationStack {
                DashboardTab(student: student, editProfile: { editingProfile = student })
                    .navigationTitle("Learning AI")
                    .toolbar { studentPicker }
            }
            .tabItem { Label("Dashboard", systemImage: "house") }

            NavigationStack {
                SubjectsTab(student: student)
                    .navigationTitle("Subjects")
                    .toolbar { studentPicker }
            }
            .tabItem { Label("Subjects", systemImage: "square.grid.2x2") }

            NavigationStack {
                AssignmentListTab(student: student)
                    .navigationTitle("Assignments")
                    .toolbar { studentPicker }
            }
            .tabItem { Label("Assignments", systemImage: "doc.text") }

            NavigationStack {
                PlanTab(student: student)
                    .navigationTitle("Learning plan")
                    .toolbar { studentPicker }
            }
            .tabItem { Label("Plan", systemImage: "calendar") }

            NavigationStack {
                ProfileTab(student: student, onEdit: { editingProfile = student })
                    .navigationTitle("Profile")
                    .toolbar {
                        studentPicker
                        ToolbarItem(placement: .topBarTrailing) {
                            Button { showingAddStudent = true } label: { Image(systemName: "person.badge.plus") }
                                .accessibilityLabel("Add student")
                        }
                    }
            }
            .tabItem { Label("Profile", systemImage: "person.crop.circle") }
        }
        .tint(.indigo)
        .sheet(isPresented: $showingAddStudent) {
            ProfileEditor(profile: nil) { profiles.save($0) }
        }
        .sheet(item: $editingProfile) { profile in
            ProfileEditor(profile: profile) { profiles.save($0) }
        }
    }

    @ToolbarContentBuilder
    private var studentPicker: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                ForEach(profiles.students) { item in
                    Button {
                        profiles.selectedStudentID = item.id
                    } label: {
                        if item.id == student.id {
                            Label(item.name, systemImage: "checkmark")
                        } else {
                            Text(item.name)
                        }
                    }
                }
                Divider()
                Button { showingAddStudent = true } label: {
                    Label("Add student", systemImage: "person.badge.plus")
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "person.crop.circle.fill")
                    Text(student.name.components(separatedBy: " ").first ?? student.name)
                }
                .font(.subheadline.weight(.medium))
            }
            .accessibilityLabel("Selected student: \(student.name)")
        }
    }
}

private struct DashboardTab: View {
    let student: StudentProfile
    let editProfile: () -> Void
    private var plan: StudentLearningPlan { .forStudent(student.id) }

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
                            Text(student.gradeLevel + " · " + student.subjects.joined(separator: ", "))
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
                    Text(student.summary)
                        .font(.body).foregroundStyle(.white.opacity(0.9))
                        .padding(.top, 5)
                }
                .padding(22)
                .foregroundStyle(.white)
                .background(LinearGradient(colors: [.indigo, Color(red: 0.12, green: 0.16, blue: 0.38)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 24))

                HStack {
                    Text("Subject progress").font(.title2.bold())
                    Spacer()
                    Text(plan.month).font(.subheadline.weight(.medium)).foregroundStyle(.secondary)
                }
                ForEach(plan.progress) { item in ProgressRow(progress: item) }

                VStack(alignment: .leading, spacing: 8) {
                    Label("Next milestone", systemImage: "sparkles")
                        .font(.headline).foregroundStyle(.indigo)
                    Text(plan.milestones.first?.title ?? "Keep learning")
                        .font(.title3.bold())
                    Text(plan.milestones.first?.date ?? "")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.background, in: RoundedRectangle(cornerRadius: 18))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(.quaternary))
            }
            .padding(20)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .background(Color(uiColor: .systemGroupedBackground))
    }
}

private struct SubjectsTab: View {
    @EnvironmentObject private var profiles: StudentProfileStore
    @State private var subjectName = ""
    @State private var showingSubjectPrompt = false
    let student: StudentProfile
    private var progress: [SubjectProgress] { StudentLearningPlan.forStudent(student.id).progress }

    var body: some View {
        List {
            Section {
                ForEach(student.subjects, id: \.self) { subject in
                    let item = progress.first(where: { $0.subject.localizedCaseInsensitiveContains(subject) || subject.localizedCaseInsensitiveContains($0.subject) })
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Label(subject, systemImage: icon(for: subject))
                                .font(.headline)
                            Spacer()
                            Text(item?.status ?? "Active")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.indigo)
                        }
                        if let item {
                            ProgressView(value: Double(item.completion), total: 100).tint(color(for: item.status))
                            Text("\(item.completion)% · Next: \(item.nextMilestone)")
                                .font(.caption).foregroundStyle(.secondary)
                        } else {
                            Text("Learning progress will appear here.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                }
                .onDelete { offsets in
                    var profile = student
                    profile.subjects.remove(atOffsets: offsets)
                    profiles.save(profile)
                }
            } header: {
                Text("\(student.name)'s subjects")
            } footer: {
                Text("Swipe left on a subject to remove it.")
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button { showingSubjectPrompt = true } label: {
                Label("Add subject", systemImage: "plus")
                    .font(.headline)
                    .frame(maxWidth: 600)
                    .padding(.vertical, 14)
                    .background(.indigo, in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(.white)
            }
            .padding()
        }
        .alert("Add a subject", isPresented: $showingSubjectPrompt) {
            TextField("Subject name", text: $subjectName)
            Button("Cancel", role: .cancel) { subjectName = "" }
            Button("Add") {
                let cleaned = subjectName.trimmingCharacters(in: .whitespacesAndNewlines)
                if !cleaned.isEmpty {
                    var profile = student
                    if !profile.subjects.contains(where: { $0.caseInsensitiveCompare(cleaned) == .orderedSame }) {
                        profile.subjects.append(cleaned)
                        profiles.save(profile)
                    }
                }
                subjectName = ""
            }
        }
    }

    private func icon(for subject: String) -> String {
        let value = subject.lowercased()
        if value.contains("math") || value.contains("algebra") { return "function" }
        if value.contains("read") || value.contains("writing") { return "book" }
        if value.contains("science") || value.contains("biology") { return "atom" }
        return "text.book.closed"
    }

    private func color(for status: String) -> Color {
        status == "On track" ? .green : status == "Needs support" ? .orange : .indigo
    }
}

private struct AssignmentListTab: View {
    let student: StudentProfile

    private var assignments: [Assignment] {
        Assignment.samples.filter { item in
            student.subjects.contains(where: { $0.localizedCaseInsensitiveContains(item.subject) || item.subject.localizedCaseInsensitiveContains($0) })
        }
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

private struct PlanTab: View {
    let student: StudentProfile
    private var plan: StudentLearningPlan { .forStudent(student.id) }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("MONTHLY FOCUS").font(.caption.weight(.bold)).tracking(1).foregroundStyle(.indigo)
                    Text(plan.focus).font(.headline)
                    Text(plan.month).font(.subheadline).foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
            }
            Section("Timeline") {
                ForEach(plan.milestones) { milestone in
                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: milestone.kind == "Assessment" ? "checkmark.seal" : milestone.kind == "Assignment" ? "doc.text" : "calendar")
                            .foregroundStyle(.indigo)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(milestone.title).font(.headline)
                            Text("\(milestone.kind) · \(milestone.date)").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 5)
                }
            }
            Section("Skill progress") {
                ForEach(plan.progress) { ProgressRow(progress: $0) }
            }
        }
    }
}

private struct ProfileTab: View {
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
                        Text(student.gradeLevel).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 8)
                Button("Edit profile", systemImage: "square.and.pencil", action: onEdit)
            }
            Section("Student summary") {
                Text(student.summary)
                    .foregroundStyle(.secondary)
                LabeledContent("Subjects", value: "\(student.subjects.count)")
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

private struct ProgressRow: View {
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

private struct ProfileEditor: View {
    @Environment(\.dismiss) private var dismiss
    let original: StudentProfile?
    let onSave: (StudentProfile) -> Void
    @State private var name: String
    @State private var grade: String
    @State private var summary: String

    init(profile: StudentProfile?, onSave: @escaping (StudentProfile) -> Void) {
        original = profile
        self.onSave = onSave
        _name = State(initialValue: profile?.name ?? "")
        _grade = State(initialValue: profile?.gradeLevel ?? "Grade 3")
        _summary = State(initialValue: profile?.summary ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Student") {
                    TextField("Name", text: $name)
                    TextField("Grade level", text: $grade)
                }
                Section("Learning summary") {
                    TextEditor(text: $summary).frame(minHeight: 120)
                }
            }
            .navigationTitle(original == nil ? "Add student" : "Edit profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !cleaned.isEmpty else { return }
                        let value = StudentProfile(
                            id: original?.id ?? UUID().uuidString,
                            name: cleaned,
                            gradeLevel: grade.isEmpty ? "Grade 3" : grade,
                            subjects: original?.subjects ?? ["Reading", "Mathematics"],
                            summary: summary.isEmpty ? "Keep building confidence with steady practice." : summary
                        )
                        onSave(value)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
