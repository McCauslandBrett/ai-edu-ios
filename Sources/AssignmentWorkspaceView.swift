import SwiftUI
import UIKit
import PencilKit

struct AssignmentWorkspaceView: View {
    @EnvironmentObject private var documents: AssignmentDocumentStore
    @EnvironmentObject private var profiles: StudentProfileStore
    @Environment(\.scenePhase) private var scenePhase
    let assignment: Assignment

    @State private var drawing = PKDrawing()
    @State private var isGrading = false
    @State private var grade: AssignmentGrade?
    @State private var gradingError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                assignmentHeader

                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Label("Your work", systemImage: "pencil.tip.crop.circle")
                            .font(.headline)
                        Spacer()
                        Text(documents.status(for: assignment.id))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    worksheet
                        .frame(minHeight: 620)
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
        .navigationTitle(assignment.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            drawing = documents.drawing(for: assignment.id)
            if let saved = UserDefaults.standard.data(forKey: gradeStorageKey) {
                grade = try? JSONDecoder().decode(AssignmentGrade.self, from: saved)
            }
        }
        .onChange(of: drawing) { _, newDrawing in
            documents.updateDrawing(newDrawing, for: assignment.id)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                documents.flushSave(for: assignment.id)
            }
        }
    }

    private var gradeStorageKey: String { "assignment-grade-\(assignment.id)" }

    private var gradingPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
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
            if let gradingError {
                Text(gradingError).font(.subheadline).foregroundStyle(.red)
            }
            if let grade {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Suggested score").font(.headline)
                        Spacer()
                        Text("\(grade.score.formatted()) / \(grade.total.formatted())")
                            .font(.title3.bold()).foregroundStyle(.indigo)
                    }
                    Text(grade.overallFeedback).font(.body)
                    if grade.needsHumanReview {
                        Label("Some handwriting needs a human review.", systemImage: "exclamationmark.triangle.fill")
                            .font(.subheadline.weight(.semibold)).foregroundStyle(.orange)
                    }
                    ForEach(grade.items) { item in
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
                .padding(14)
                .background(.indigo.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))
            }
        }
        .padding(18)
        .background(.background, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(.quaternary))
    }

    @MainActor
    private func gradeAssignment() async {
        isGrading = true
        gradingError = nil
        defer { isGrading = false }
        do {
            let result = try await LearningAIService().grade(
                assignment,
                student: profiles.selectedStudent,
                drawing: drawing
            )
            grade = result
            UserDefaults.standard.set(try JSONEncoder().encode(result), forKey: gradeStorageKey)
        } catch {
            gradingError = error.localizedDescription
        }
    }

    private var assignmentHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(assignment.subject.uppercased())
                .font(.caption.weight(.bold))
                .tracking(1)
                .foregroundStyle(.indigo)
            Text(assignment.title)
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(.primary)
            Text("Due \(assignment.dueDate) · \(assignment.points) points")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(assignment.prompt)
                .font(.body)
                .foregroundStyle(.primary)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(22)
        .background(.background, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(.quaternary, lineWidth: 1))
    }

    private var worksheet: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("WORKSHEET")
                    .font(.caption.weight(.bold))
                    .tracking(1.1)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(assignment.points) points")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 20)

            ForEach(Array(assignment.questions.enumerated()), id: \.offset) { _, question in
                VStack(alignment: .leading, spacing: 16) {
                    Text(question)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    Rectangle()
                        .fill(Color.indigo.opacity(0.16))
                        .frame(height: 1)
                }
                .padding(.bottom, 24)
            }

            Spacer(minLength: 200)
        }
        .padding(24)
        .frame(maxWidth: .infinity, minHeight: 620, alignment: .topLeading)
        .background(Color(uiColor: .systemBackground))
        .overlay {
            PencilCanvas(drawing: $drawing)
                .background(Color.clear)
                .padding(.top, 12)
        }
    }
}

private struct PencilCanvas: UIViewRepresentable {
    @Binding var drawing: PKDrawing

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.drawingPolicy = .anyInput
        canvas.tool = PKInkingTool(.pen, color: .systemBlue, width: 3)
        canvas.delegate = context.coordinator
        canvas.drawing = drawing
        canvas.alwaysBounceVertical = false
        canvas.isScrollEnabled = false

        if let window = canvas.window {
            context.coordinator.attachToolPicker(to: canvas, window: window)
        }
        DispatchQueue.main.async {
            if let window = canvas.window {
                context.coordinator.attachToolPicker(to: canvas, window: window)
            }
        }
        return canvas
    }

    func updateUIView(_ canvas: PKCanvasView, context: Context) {
        context.coordinator.parent = self
        if canvas.drawing != drawing {
            canvas.drawing = drawing
        }
        if let window = canvas.window {
            context.coordinator.attachToolPicker(to: canvas, window: window)
        }
    }

    @MainActor
    final class Coordinator: NSObject, PKCanvasViewDelegate {
        var parent: PencilCanvas
        private var toolPicker: PKToolPicker?

        init(_ parent: PencilCanvas) {
            self.parent = parent
        }

        func attachToolPicker(to canvas: PKCanvasView, window: UIWindow) {
            guard toolPicker == nil else { return }
            let picker = PKToolPicker()
            picker.setVisible(true, forFirstResponder: canvas)
            picker.addObserver(canvas)
            canvas.becomeFirstResponder()
            toolPicker = picker
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            parent.drawing = canvasView.drawing
        }
    }
}
