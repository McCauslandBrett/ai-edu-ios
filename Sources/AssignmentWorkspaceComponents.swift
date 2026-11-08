import SwiftUI
import UIKit
import PencilKit

struct AssignmentWorksheetView: View {
    let assignment: Assignment
    @Binding var drawing: PKDrawing
    @ObservedObject var speech: AssignmentReadAloudController

    private let exercisesPerPage = 4
    private let standardExerciseHeight: CGFloat = 220
    private let standardPageHeight: CGFloat = 1_020

    private var pageCount: Int {
        max(1, Int(ceil(Double(assignment.questions.count) / Double(exercisesPerPage))))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            pageHeading(1)
            ForEach(Array(assignment.questions.enumerated()), id: \.offset) { index, question in
                if index > 0 && index.isMultiple(of: exercisesPerPage) {
                    Rectangle().fill(Color.gray.opacity(0.18)).frame(height: 2).padding(.vertical, 18)
                    pageHeading(index / exercisesPerPage + 1)
                }
                exercise(question, at: index)
                    .frame(height: exerciseHeight(at: index), alignment: .topLeading)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, minHeight: CGFloat(pageCount) * standardPageHeight, alignment: .topLeading)
        .background(Color(uiColor: .systemBackground))
        .overlay {
            PencilCanvas(drawing: $drawing)
                .background(Color.clear)
                .padding(.top, 12)
        }
    }

    private func exercise(_ question: String, at index: Int) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                Text("Exercise \(index + 1)").font(.caption.weight(.bold)).foregroundStyle(.indigo)
                Spacer()
                if let skills = assignment.questionSkills, skills.indices.contains(index) {
                    Text(skills[index]).font(.caption).foregroundStyle(.secondary)
                }
            }
            if let visuals = assignment.questionIllustrations,
               visuals.indices.contains(index), !visuals[index].isEmpty {
                Text(visuals[index]).font(.system(size: 34)).accessibilityLabel("Exercise illustration")
            }
            HStack(alignment: .top, spacing: 12) {
                Text(question).font(.body.weight(.medium)).foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                AssignmentReadAloudButton(
                    text: question,
                    id: "question-\(index)",
                    speech: speech,
                    shortLabel: true
                )
            }
            Rectangle().fill(Color.indigo.opacity(0.16)).frame(height: 1)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
    }

    private func pageHeading(_ page: Int) -> some View {
        HStack {
            Text(page == 1 ? "WORKSHEET" : "WORKSHEET · PAGE \(page)")
                .font(.caption.weight(.bold)).tracking(1.1).foregroundStyle(.secondary)
            Spacer()
            Text("\(assignment.points) points").font(.caption.weight(.medium)).foregroundStyle(.secondary)
        }
        .padding(.bottom, 18)
    }

    private func exerciseHeight(at index: Int) -> CGFloat {
        let multipliers = assignment.writingSpaceMultipliers ?? []
        let value = multipliers.indices.contains(index) ? multipliers[index] : 1
        return standardExerciseHeight * CGFloat(min(3, max(1, value)))
    }
}

struct AssignmentReadAloudButton: View {
    let text: String
    let id: String
    @ObservedObject var speech: AssignmentReadAloudController
    var shortLabel = false

    private var isSpeaking: Bool { speech.speakingID == id }

    var body: some View {
        Button {
            speech.toggle(text, id: id)
        } label: {
            Group {
                if shortLabel {
                    Label(isSpeaking ? "Stop" : "Listen", systemImage: isSpeaking ? "stop.fill" : "speaker.wave.2.fill")
                        .labelStyle(.iconOnly)
                } else {
                    Label(isSpeaking ? "Stop reading" : "Read aloud", systemImage: isSpeaking ? "stop.fill" : "speaker.wave.2.fill")
                        .labelStyle(.titleAndIcon)
                }
            }
            .font(.caption.weight(.semibold))
            .padding(.horizontal, shortLabel ? 10 : 12)
            .padding(.vertical, 8)
            .background(Color.indigo.opacity(0.1), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isSpeaking ? "Stop reading" : "Read aloud")
    }
}

struct AssignmentGradingPanel: View {
    let assignment: Assignment
    let grade: AssignmentGrade?
    let gradingError: String?
    let retryError: String?
    let retryAssignment: Assignment?
    let isGrading: Bool
    let isGeneratingRetry: Bool
    let onGrade: () -> Void
    let onRetry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            if let gradingError { Text(gradingError).font(.subheadline).foregroundStyle(.red) }
            if let grade { result(grade) }
        }
        .padding(18)
        .background(.background, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(.quaternary))
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("AI grader").font(.headline)
                Text("Checks the handwriting against this assignment's answer key and rubric.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            Button(action: onGrade) {
                if isGrading { ProgressView().tint(.white) }
                else { Label(grade == nil ? "Grade work" : "Grade again", systemImage: "sparkles") }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isGrading)
        }
    }

    private func result(_ grade: AssignmentGrade) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Suggested score").font(.headline)
                Spacer()
                Text("\(grade.score.formatted()) / \(grade.total.formatted())")
                    .font(.title3.bold()).foregroundStyle(.indigo)
            }
            Text(grade.overallFeedback).font(.body)
            if assignment.isHomework {
                HStack(spacing: 8) {
                    Image(systemName: grade.isPassing ? "checkmark.seal.fill" : "xmark.seal.fill")
                    Text(grade.isPassing ? "PASSED" : "NOT PASSED").font(.headline.weight(.bold))
                    Text("· \(grade.correctCount)/\(grade.questionCount) correct · 80% required").font(.subheadline)
                }
                .foregroundStyle(grade.isPassing ? .green : .red)
                if !grade.isPassing { retryControls }
            }
            if grade.needsHumanReview {
                Label("Some handwriting needs a human review.", systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline.weight(.semibold)).foregroundStyle(.orange)
            }
            ForEach(grade.items) { item in AssignmentGradeItemRow(item: item) }
        }
        .padding(14)
        .background(.indigo.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))
    }

    private var retryControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: onRetry) {
                if isGeneratingRetry { ProgressView("Creating a new attempt…") }
                else { Label("Generate new attempt", systemImage: "arrow.clockwise") }
            }
            .disabled(isGeneratingRetry)
            if let retryError { Text(retryError).font(.subheadline).foregroundStyle(.red) }
            if let retryAssignment {
                NavigationLink {
                    AssignmentWorkspaceView(assignment: retryAssignment)
                } label: {
                    Label("Open new attempt", systemImage: "doc.text")
                }
            }
        }
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
