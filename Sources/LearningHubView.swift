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
    private var plan: StudentLearningPlan { .forStudent(student.id, subject: student.subjects.first ?? "Mathematics") }
    private var progress: [SubjectProgress] {
        student.subjects.flatMap { StudentLearningPlan.forStudent(student.id, subject: $0).progress }.prefix(6).map { $0 }
    }

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
                            Text("Age \(student.age.map(String.init) ?? "not set") · \(student.gradeLevel) · " + student.subjects.joined(separator: ", "))
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
                ForEach(progress) { item in ProgressRow(progress: item) }

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
    @State private var showingSubjectForm = false
    let student: StudentProfile

    var body: some View {
        List {
            Section {
                ForEach(student.subjects, id: \.self) { subject in
                    let saved = profiles.subjectPlan(for: student.id, subject: subject)
                    let fallback = StudentLearningPlan.forStudent(student.id, subject: subject)
                    NavigationLink {
                        SubjectPlanView(
                            student: student,
                            subject: subject,
                            saved: saved,
                            fallback: fallback,
                            assignments: profiles.assignments(for: student, subject: subject)
                        )
                    } label: {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Label(subject, systemImage: icon(for: subject)).font(.headline)
                                Spacer()
                                if let saved {
                                    Text("\(saved.plan.progress.first?.completion ?? 0, specifier: "%.0f")%")
                                        .font(.caption.weight(.bold)).foregroundStyle(.indigo)
                                } else {
                                    Text("Plan template").font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            if let saved {
                                let average = saved.plan.progress.isEmpty ? 0 :
                                    saved.plan.progress.map(\.completion).reduce(0, +) / Double(saved.plan.progress.count)
                                ProgressView(value: average, total: 100).tint(.indigo)
                                Text(saved.plan.objective).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                            } else {
                                Text(fallback.focus).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
                .onDelete { offsets in
                    var profile = student
                    profile.subjects.remove(atOffsets: offsets)
                    profiles.save(profile)
                }
            } header: {
                Text("\(student.name)'s subjects")
            } footer: {
                Text("Tap a subject to view its plan and assignments. Add a subject to generate a personalized four-week plan.")
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button { showingSubjectForm = true } label: {
                Label("Add subject and generate plan", systemImage: "sparkles")
                    .font(.headline)
                    .frame(maxWidth: 600)
                    .padding(.vertical, 14)
                    .background(.indigo, in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(.white)
            }
            .padding()
        }
        .sheet(isPresented: $showingSubjectForm) {
            SubjectPlanCreationView(student: student) { newPlan in
                profiles.saveSubjectPlan(newPlan)
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
}

private struct SubjectPlanCreationView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var profiles: StudentProfileStore
    let student: StudentProfile
    let onCreate: (StudentSubjectPlan) -> Void

    @State private var subject = ""
    @State private var targetedSkills = ""
    @State private var learningOutcome = ""
    @State private var highestAssessmentLevel = ""
    @State private var priorResults = ""
    @State private var instructorContext = ""
    @State private var isGenerating = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                if isGenerating {
                    Section {
                        HStack(spacing: 12) {
                            ProgressView()
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Generating your four-week plan…")
                                    .font(.headline)
                                Text("Building weekly lessons, assignments, and assessments. This can take a few minutes.")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                if let errorMessage {
                    Section("Plan was not created") {
                        Text(errorMessage).foregroundStyle(.red)
                        Button("Try again") {
                            Task { await generatePlan() }
                        }
                        .disabled(isGenerating)
                    }
                }

                Section("Student context") {
                    LabeledContent("Student", value: student.name)
                    LabeledContent("Age", value: student.age.map(String.init) ?? "Not set")
                    LabeledContent("School grade", value: student.gradeLevel)
                    Text("Edit the student profile first if age or grade needs updating.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                Section("Subject and goals") {
                    TextField("Subject name", text: $subject)
                    TextField("Targeted skills (comma or line separated)", text: $targetedSkills, axis: .vertical)
                        .lineLimit(2...4)
                    TextField("Learning outcome for this month", text: $learningOutcome, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section("Assessment history") {
                    TextField("Highest previous assessment or exam level (optional)", text: $highestAssessmentLevel)
                    TextEditor(text: $priorResults)
                        .frame(minHeight: 80)
                        .overlay(alignment: .topLeading) {
                            if priorResults.isEmpty {
                                Text("Prior assessment results, strengths, or struggles")
                                    .foregroundStyle(.tertiary)
                                    .padding(.top, 8)
                                    .padding(.leading, 5)
                                    .allowsHitTesting(false)
                            }
                        }
                }

                Section("Instructor or parent guidance") {
                    TextEditor(text: $instructorContext)
                        .frame(minHeight: 160)
                        .overlay(alignment: .topLeading) {
                            if instructorContext.isEmpty {
                                Text("Describe what you want the child to learn, what has been difficult, preferred teaching approaches, or any other context.")
                                    .foregroundStyle(.tertiary)
                                    .padding(.top, 8)
                                    .padding(.leading, 5)
                                    .allowsHitTesting(false)
                            }
                        }
                }

            }
            .navigationTitle("Create subject plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.disabled(isGenerating)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await generatePlan() }
                    } label: {
                        if isGenerating { Text("Generating…") }
                        else { Text("Generate plan") }
                    }
                    .disabled(isGenerating || subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                              learningOutcome.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .overlay {
                if isGenerating {
                    ZStack {
                        Color.black.opacity(0.32)
                            .ignoresSafeArea()

                        VStack(spacing: 18) {
                            ProgressView()
                                .controlSize(.large)
                                .scaleEffect(1.35)
                                .tint(.indigo)
                                .padding(.bottom, 4)

                            VStack(spacing: 7) {
                                Text("Creating your four-week plan")
                                    .font(.title3.weight(.bold))
                                    .multilineTextAlignment(.center)
                                Text("The AI is preparing lessons, assignments, and weekly assessments for \(student.name).")
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                                Text("This may take a few minutes. Keep the app open.")
                                    .font(.footnote.weight(.medium))
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.top, 3)
                            }
                        }
                        .padding(28)
                        .frame(maxWidth: 390)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
                        .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.35)))
                        .shadow(color: .black.opacity(0.18), radius: 24, y: 10)
                        .padding(24)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Creating your four-week plan. This may take a few minutes. Keep the app open.")
                    }
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: isGenerating)
        }
    }

    @MainActor
    private func generatePlan() async {
        isGenerating = true
        errorMessage = nil
        defer { isGenerating = false }

        let cleanedSubject = subject.trimmingCharacters(in: .whitespacesAndNewlines)
        let skills = targetedSkills
            .components(separatedBy: CharacterSet(charactersIn: ",\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let results = priorResults
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let outcome = learningOutcome.trimmingCharacters(in: .whitespacesAndNewlines)
        let context = instructorContext.trimmingCharacters(in: .whitespacesAndNewlines)

        let previous = profiles.subjectPlan(for: student.id, subject: cleanedSubject)?.inputs
        let combinedResults = (previous?.priorAssessmentResults ?? []) + results
        let combinedSkills = skills.isEmpty ? (previous?.targetedSkills ?? []) : skills
        let assessmentLevel = highestAssessmentLevel.trimmingCharacters(in: .whitespacesAndNewlines)
        let combinedAssessmentLevel = assessmentLevel.isEmpty ? (previous?.highestAssessmentLevel ?? "") : assessmentLevel
        let profileContext = "Student learning profile: \(student.summary)\nPrevious instructor context: \(previous?.instructorContext ?? "")\nCurrent instructor or parent guidance: \(context)"
        let inputs = SubjectPlanInputs(
            targetedSkills: combinedSkills,
            learningOutcome: outcome,
            highestAssessmentLevel: combinedAssessmentLevel,
            priorAssessmentResults: combinedResults,
            instructorContext: context
        )
        let request = LearningPlanGenerationRequest(
            student: AIStudentContext(name: student.name, age: student.age, gradeLevel: student.gradeLevel),
            subject: cleanedSubject,
            objective: outcome,
            monthlyWindow: "4 weeks",
            targetedSkills: combinedSkills,
            highestAssessmentLevel: inputs.highestAssessmentLevel,
            priorResults: combinedResults,
            instructorContext: profileContext
        )

        do {
            let plan = try await LearningAIService().generatePlan(request)
            onCreate(StudentSubjectPlan(
                studentID: student.id,
                subject: cleanedSubject,
                inputs: inputs,
                plan: plan
            ))
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct SubjectPlanView: View {
    let student: StudentProfile
    let subject: String
    let saved: StudentSubjectPlan?
    let fallback: StudentLearningPlan
    let assignments: [Assignment]

    var body: some View {
        List {
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

            if let saved {
                Section("Tracked skills") {
                    ForEach(saved.plan.progress) { item in
                        ProgressRow(progress: SubjectProgress(
                            subject: item.subject,
                            completion: Int(item.completion.rounded()),
                            nextMilestone: item.nextMilestone,
                            status: item.status
                        ))
                    }
                }

                ForEach(saved.plan.weeks) { week in
                    Section("Week \(week.weekNumber) · \(week.theme)") {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Tutor lecture prompt", systemImage: "bubble.left.and.bubble.right")
                                .font(.headline).foregroundStyle(.indigo)
                            Text(week.lecturePrompt).font(.subheadline)
                        }
                        .padding(.vertical, 6)

                        NavigationLink {
                            AssignmentWorkspaceView(assignment: week.assessment.makeAssignment(
                                studentID: student.id, subject: subject, weekNumber: week.weekNumber, assessment: true
                            ))
                        } label: {
                            Label(assessmentTitle(for: week.weekNumber), systemImage: "checkmark.seal")
                                .foregroundStyle(.orange)
                        }

                        ForEach(week.assignments) { activity in
                            NavigationLink {
                                AssignmentWorkspaceView(assignment: activity.makeAssignment(
                                    studentID: student.id, subject: subject, weekNumber: week.weekNumber
                                ))
                            } label: {
                                Label(activity.title, systemImage: "doc.text")
                            }
                        }
                    }
                }
            } else {
                Section("Plan template") {
                    Text("This is a preview. Add this subject with the form to generate a personalized four-week AI plan.")
                        .font(.subheadline).foregroundStyle(.secondary)
                    ForEach(fallback.progress) { ProgressRow(progress: $0) }
                }
            }

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
        .navigationTitle(subject)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func assessmentTitle(for week: Int) -> String {
        switch week {
        case 1: return "Baseline assessment"
        case 4: return "Final assessment"
        default: return "Week \(week) assessment"
        }
    }
}

private struct AssignmentListTab: View {
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
                        Text("Age \(student.age.map(String.init) ?? "not set") · \(student.gradeLevel)").foregroundStyle(.secondary)
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
    @State private var age: String
    @State private var grade: String
    @State private var summary: String

    init(profile: StudentProfile?, onSave: @escaping (StudentProfile) -> Void) {
        original = profile
        self.onSave = onSave
        _name = State(initialValue: profile?.name ?? "")
        _age = State(initialValue: profile?.age.map(String.init) ?? "")
        _grade = State(initialValue: profile?.gradeLevel ?? "Grade 3")
        _summary = State(initialValue: profile?.summary ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Student") {
                    TextField("Name", text: $name)
                    TextField("Age", text: $age).keyboardType(.numberPad)
                    TextField("School grade level", text: $grade)
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
                            age: Int(age),
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
