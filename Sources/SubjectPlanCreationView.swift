import SwiftUI

struct SubjectPlanCreationView: View {
    @EnvironmentObject private var profiles: StudentProfileStore
    let student: StudentProfile
    let onCreate: (StudentSubjectPlan) -> Void
    let onClose: () -> Void

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
                generationStatusSection
                errorSection
                studentContextSection
                subjectGoalsSection
                assessmentHistorySection
                instructorGuidanceSection
            }
            .navigationTitle("Create subject plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { formToolbar }
            .overlay { generationOverlay }
            .animation(.easeInOut(duration: 0.2), value: isGenerating)
        }
    }

    @ViewBuilder
    private var generationStatusSection: some View {
        if isGenerating {
            Section {
                HStack(spacing: 12) {
                    ProgressView()
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Generating your four-week plan…").font(.headline)
                        Text("Building weekly lessons, assignments, and assessments. This can take a few minutes.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    @ViewBuilder
    private var errorSection: some View {
        if let errorMessage {
            Section("Plan was not created") {
                Text(errorMessage).foregroundStyle(.red)
                Button("Try again") { Task { await generatePlan() } }
                    .disabled(isGenerating)
            }
        }
    }

    private var studentContextSection: some View {
        Section("Student context") {
            LabeledContent("Student", value: student.name)
            LabeledContent("Age", value: student.age.map(String.init) ?? "Not set")
            LabeledContent("School grade", value: student.gradeLevel)
            Text("Edit the student profile first if age or grade needs updating.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var subjectGoalsSection: some View {
        Section("Subject and goals") {
            TextField("Subject name", text: $subject)
            TextField("Targeted skills (comma or line separated)", text: $targetedSkills, axis: .vertical)
                .lineLimit(2...4)
            TextField("Learning outcome for this month", text: $learningOutcome, axis: .vertical)
                .lineLimit(2...4)
        }
    }

    private var assessmentHistorySection: some View {
        Section("Assessment history") {
            TextField("Highest previous assessment or exam level (optional)", text: $highestAssessmentLevel)
            PlaceholderTextEditor(text: $priorResults, placeholder: "Prior assessment results, strengths, or struggles", minHeight: 80)
        }
    }

    private var instructorGuidanceSection: some View {
        Section("Instructor or parent guidance") {
            PlaceholderTextEditor(
                text: $instructorContext,
                placeholder: "Describe what you want the child to learn, what has been difficult, preferred teaching approaches, or any other context.",
                minHeight: 160
            )
        }
    }

    @ToolbarContentBuilder
    private var formToolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel", action: onClose).disabled(isGenerating)
        }
        ToolbarItem(placement: .confirmationAction) {
            Button {
                Task { await generatePlan() }
            } label: {
                Text(isGenerating ? "Generating…" : "Generate plan")
            }
            .disabled(isGenerating || subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                      learningOutcome.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    @ViewBuilder
    private var generationOverlay: some View {
        if isGenerating {
            PlanGenerationOverlay(studentName: student.name)
                .transition(.opacity)
        }
    }

    @MainActor
    private func generatePlan() async {
        guard !isGenerating else { return }
        isGenerating = true
        errorMessage = nil
        defer { isGenerating = false }

        let cleanedSubject = subject.trimmingCharacters(in: .whitespacesAndNewlines)
        let previous = profiles.subjectPlan(for: student.id, subject: cleanedSubject)?.inputs
        let submission = makeSubmission(subject: cleanedSubject, previous: previous)

        do {
            let plan = try await LearningPlanGenerationService().generate(submission.request)
            onCreate(StudentSubjectPlan(
                studentID: student.id,
                subject: cleanedSubject,
                inputs: submission.inputs,
                plan: plan
            ))
            onClose()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func makeSubmission(subject: String, previous: SubjectPlanInputs?) -> SubjectPlanSubmission {
        SubjectPlanSubmissionBuilder.build(
            student: student,
            subject: subject,
            targetedSkillsText: targetedSkills,
            learningOutcome: learningOutcome,
            highestAssessmentLevel: highestAssessmentLevel,
            priorResultsText: priorResults,
            instructorContext: instructorContext,
            previous: previous
        )
    }
}

private struct PlaceholderTextEditor: View {
    @Binding var text: String
    let placeholder: String
    let minHeight: CGFloat

    var body: some View {
        TextEditor(text: $text)
            .frame(minHeight: minHeight)
            .overlay(alignment: .topLeading) {
                if text.isEmpty {
                    Text(placeholder)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 8)
                        .padding(.leading, 5)
                        .allowsHitTesting(false)
                }
            }
    }
}

private struct PlanGenerationOverlay: View {
    let studentName: String

    var body: some View {
        ZStack {
            Color.black.opacity(0.32).ignoresSafeArea()
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
                    Text("The AI is preparing lessons, assignments, and weekly assessments for \(studentName).")
                        .font(.body).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    Text("This may take a few minutes. Keep the app open.")
                        .font(.footnote.weight(.medium)).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center).padding(.top, 3)
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
    }
}
