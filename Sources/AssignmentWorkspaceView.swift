import SwiftUI
import UIKit
import PencilKit

struct AssignmentWorkspaceView: View {
    @EnvironmentObject private var documents: AssignmentDocumentStore
    @EnvironmentObject private var profiles: StudentProfileStore
    @Environment(\.scenePhase) private var scenePhase
    let assignment: Assignment

    @State private var revisedAssignment: Assignment?
    @State private var showingChangeRequest = false
    @State private var drawing = PKDrawing()
    @State private var isGrading = false
    @State private var isGeneratingRetry = false
    @State private var grade: AssignmentGrade?
    @State private var gradingError: String?
    @State private var retryError: String?
    @State private var retryAssignment: Assignment?
    private let gradeStore = AssignmentGradeStore()

    private var currentAssignment: Assignment { revisedAssignment ?? assignment }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                assignmentHeader

                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Label("Your work", systemImage: "pencil.tip.crop.circle")
                            .font(.headline)
                        Spacer()
                        Text(documents.status(for: currentAssignment.id))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    worksheet
                        .frame(minHeight: worksheetHeight)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(.gray.opacity(0.25), lineWidth: 1))
                }
                .padding(18)
                .background(.background, in: RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(.quaternary, lineWidth: 1))

                gradingPanel

                Label("AI grading is a suggestion. Review the result before using it to make learning decisions.", systemImage: "lock.shield")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
            }
            .padding(20)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .sheet(isPresented: $showingChangeRequest) {
            AssignmentChangeRequestView(assignment: currentAssignment, student: profiles.selectedStudent) { updated in
                revisedAssignment = updated
                grade = nil
                gradeStore.delete(assignmentID: updated.id)
                profiles.clearRecordedGrade(for: updated, studentID: profiles.selectedStudent.id)
                profiles.saveAssignmentOverride(updated, studentID: profiles.selectedStudent.id)
            }
        }
        .navigationTitle(currentAssignment.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            drawing = documents.drawing(for: currentAssignment.id)
            grade = gradeStore.load(assignmentID: currentAssignment.id)
            retryAssignment = profiles.retryAssignments.last { $0.parentAssignmentID == currentAssignment.id }
        }
        .onChange(of: drawing) { _, newDrawing in
            documents.updateDrawing(newDrawing, for: currentAssignment.id)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                documents.flushSave(for: currentAssignment.id)
            }
        }
    }

    private var gradingPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            gradingHeader
            if let gradingError {
                Text(gradingError).font(.subheadline).foregroundStyle(.red)
            }
            if let grade {
                gradeResult(grade)
            }
        }
        .padding(18)
        .background(.background, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(.quaternary))
    }

    private var gradingHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("AI grader").font(.headline)
                Text("Checks the handwriting against this assignment's answer key and rubric.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                Task { await gradeAssignment() }
            } label: {
                if isGrading {
                    ProgressView().tint(.white)
                } else {
                    Label(grade == nil ? "Grade work" : "Grade again", systemImage: "sparkles")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isGrading)
        }
    }

    private func gradeResult(_ grade: AssignmentGrade) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Suggested score").font(.headline)
                Spacer()
                Text("\(grade.score.formatted()) / \(grade.total.formatted())")
                    .font(.title3.bold()).foregroundStyle(.indigo)
            }
            Text(grade.overallFeedback).font(.body)
            homeworkOutcome(for: grade)
            if grade.needsHumanReview {
                Label("Some handwriting needs a human review.", systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline.weight(.semibold)).foregroundStyle(.orange)
            }
            ForEach(grade.items) { item in
                AssignmentGradeItemRow(item: item)
            }
        }
        .padding(14)
        .background(.indigo.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private func homeworkOutcome(for grade: AssignmentGrade) -> some View {
        if currentAssignment.isHomework {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: grade.isPassing ? "checkmark.seal.fill" : "xmark.seal.fill")
                    Text(grade.isPassing ? "PASSED" : "NOT PASSED")
                        .font(.headline.weight(.bold))
                    Text("· \(grade.correctCount)/\(grade.questionCount) correct · 80% required")
                        .font(.subheadline)
                }
                .foregroundStyle(grade.isPassing ? .green : .red)

                if !grade.isPassing {
                    retryAttemptControls
                }
            }
        }
    }

    private var retryAttemptControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                Task { await generateRetryAttempt() }
            } label: {
                if isGeneratingRetry {
                    ProgressView("Creating a new attempt…")
                } else {
                    Label("Generate new attempt", systemImage: "arrow.clockwise")
                }
            }
            .disabled(isGeneratingRetry)
            if let retryError {
                Text(retryError).font(.subheadline).foregroundStyle(.red)
            }
            if let retryAssignment {
                NavigationLink {
                    AssignmentWorkspaceView(assignment: retryAssignment)
                } label: {
                    Label("Open new attempt", systemImage: "doc.text")
                }
            }
        }
    }

    @MainActor
    private func gradeAssignment() async {
        isGrading = true
        gradingError = nil
        defer { isGrading = false }
        do {
            let result = try await AssignmentGradingService().grade(
                currentAssignment,
                student: profiles.selectedStudent,
                drawing: drawing
            )
            saveGrade(result)
        } catch {
            gradingError = error.localizedDescription
        }
    }

    private func saveGrade(_ result: AssignmentGrade) {
        grade = result
        gradeStore.save(result, assignmentID: currentAssignment.id)
        profiles.recordGrade(result, for: currentAssignment, studentID: profiles.selectedStudent.id)
    }

    @MainActor
    private func generateRetryAttempt() async {
        guard let grade else { return }
        isGeneratingRetry = true
        retryError = nil
        defer { isGeneratingRetry = false }

        do {
            let request = makeRetryRequest(for: grade)
            guard let generated = try await AssignmentGenerationService().generate(request).first else {
                throw LearningAIServiceError.service("The service did not return a new assignment attempt.")
            }
            saveRetryAttempt(generated)
        } catch {
            retryError = error.localizedDescription
        }
    }

    private func makeRetryRequest(for grade: AssignmentGrade) -> AssignmentGenerationRequest {
        let student = profiles.selectedStudent
        let skills = failedSkills(in: grade)
        let feedback = retryFeedback(in: grade)
        return AssignmentGenerationRequest(
            student: AIStudentContext(name: student.name, age: student.age, gradeLevel: student.gradeLevel),
            subject: currentAssignment.subject,
            topic: currentAssignment.title,
            objective: "Create a fresh new attempt. Focus on these skills: \(skills.joined(separator: ", ")). Use different questions from the original. Original assignment guidance: \(currentAssignment.prompt). Grading feedback to address: \(feedback)",
            count: 1,
            pointsPerAssignment: currentAssignment.points,
            targetedSkills: skills
        )
    }

    private func failedSkills(in grade: AssignmentGrade) -> [String] {
        var skills: [String] = []
        let mappedSkills = currentAssignment.questionSkills ?? []
        for (index, item) in grade.items.enumerated() where !item.isCorrect {
            guard mappedSkills.indices.contains(index) else { continue }
            let skill = mappedSkills[index]
            if !skills.contains(skill) { skills.append(skill) }
        }
        return skills.isEmpty ? [currentAssignment.subject] : skills
    }

    private func retryFeedback(in grade: AssignmentGrade) -> String {
        grade.items
            .filter { !$0.isCorrect }
            .map { "Question: \($0.question). Feedback: \($0.feedback)" }
            .joined(separator: "\n")
    }

    private func saveRetryAttempt(_ generated: GeneratedAssignment) {
        let studentID = profiles.selectedStudent.id
        let attempt = generated.makeAssignment(
            dueDate: "New attempt",
            studentID: studentID,
            parentAssignmentID: currentAssignment.id,
            titlePrefix: "Retry · "
        )
        profiles.addRetryAssignment(attempt)
        retryAssignment = attempt
    }

    private var assignmentHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(currentAssignment.subject.uppercased())
                .font(.caption.weight(.bold))
                .tracking(1)
                .foregroundStyle(.indigo)
            Text(currentAssignment.title)
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(.primary)
            Text("Due \(currentAssignment.dueDate) · \(currentAssignment.points) points")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(currentAssignment.prompt)
                .font(.body)
                .foregroundStyle(.primary)
                .padding(.top, 4)
            Button {
                showingChangeRequest = true
            } label: {
                Label("Adjust this worksheet", systemImage: "slider.horizontal.3")
            }
            .buttonStyle(.bordered)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(22)
        .background(.background, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(.quaternary, lineWidth: 1))
    }

    private let standardExerciseHeight: CGFloat = 220
    private let exercisesPerPage = 4
    private let standardPageHeight: CGFloat = 1_020

    private var pageCount: Int {
        max(1, Int(ceil(Double(currentAssignment.questions.count) / Double(exercisesPerPage))))
    }

    private var worksheetHeight: CGFloat {
        CGFloat(pageCount) * standardPageHeight
    }

    private var worksheet: some View {
        VStack(alignment: .leading, spacing: 0) {
            worksheetPageHeading(page: 1)

            ForEach(Array(currentAssignment.questions.enumerated()), id: \.offset) { index, question in
                if index > 0 && index.isMultiple(of: exercisesPerPage) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.18))
                        .frame(height: 2)
                        .padding(.vertical, 18)
                    worksheetPageHeading(page: index / exercisesPerPage + 1)
                }

                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top) {
                        Text("Exercise \(index + 1)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.indigo)
                        Spacer()
                        if let skill = currentAssignment.questionSkills, skill.indices.contains(index) {
                            Text(skill[index]).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    if let illustrations = currentAssignment.questionIllustrations,
                       illustrations.indices.contains(index), !illustrations[index].isEmpty {
                        Text(illustrations[index])
                            .font(.system(size: 34))
                            .accessibilityLabel("Exercise illustration")
                    }
                    Text(question)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    Rectangle()
                        .fill(Color.indigo.opacity(0.16))
                        .frame(height: 1)
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity)
                .frame(height: exerciseHeight(for: index), alignment: .topLeading)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, minHeight: worksheetHeight, alignment: .topLeading)
        .background(Color(uiColor: .systemBackground))
        .overlay {
            PencilCanvas(drawing: $drawing)
                .background(Color.clear)
                .padding(.top, 12)
        }
    }

    private func worksheetPageHeading(page: Int) -> some View {
        HStack {
            Text(page == 1 ? "WORKSHEET" : "WORKSHEET · PAGE \(page)")
                .font(.caption.weight(.bold))
                .tracking(1.1)
                .foregroundStyle(.secondary)
            Spacer()
            Text("\(currentAssignment.points) points")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .padding(.bottom, 18)
    }

    private func exerciseHeight(for index: Int) -> CGFloat {
        let saved = currentAssignment.writingSpaceMultipliers
        let multiplier = saved?.indices.contains(index) == true ? saved![index] : 1
        return standardExerciseHeight * CGFloat(min(3, max(1, multiplier)))
    }

}


private struct AssignmentGradeItemRow: View {
    let item: AssignmentGrade.Item

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.question).font(.subheadline.weight(.semibold))
            Text("Read as: \(item.studentAnswer)").font(.subheadline)
            Text("Expected: \(item.expectedAnswer)").font(.subheadline).foregroundStyle(.secondary)
            Text(item.feedback).font(.caption).foregroundStyle(item.isCorrect ? .green : .orange)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
    }
}


private struct AssignmentChangeRequestView: View {
    @Environment(\.dismiss) private var dismiss
    let assignment: Assignment
    let student: StudentProfile
    let onSaved: (Assignment) -> Void

    @State private var request = ""
    @State private var isApplying = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Change request") {
                    TextEditor(text: $request)
                        .frame(minHeight: 130)
                    Text("Describe what to change and name an exercise or skill when possible.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section("Examples") {
                    Text("Add 5 more problems about counting by 10s.")
                    Text("Give exercise 2 twice as much writing space.")
                    Text("Add an illustration to exercise 3.")
                }
                if let errorMessage {
                    Section { Text(errorMessage).foregroundStyle(.red) }
                }
            }
            .navigationTitle("Adjust worksheet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.disabled(isApplying)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await applyRequest() }
                    } label: {
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
            let updated = try await AssignmentAdjustmentService().adjust(assignment, for: student, request: request)
            onSaved(updated)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
