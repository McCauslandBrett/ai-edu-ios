import SwiftUI
import UIKit
import PencilKit

struct AssignmentWorkspaceView: View {
    @EnvironmentObject private var documents: AssignmentDocumentStore
    @EnvironmentObject private var profiles: StudentProfileStore
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var model: AssignmentWorkspaceModel
    @StateObject private var speech = AssignmentReadAloudController()
    @State private var drawing = PKDrawing()
    @State private var showingChangeRequest = false

    init(assignment: Assignment, dependencies: AssignmentWorkspaceDependencies = .live) {
        _model = StateObject(wrappedValue: AssignmentWorkspaceModel(assignment: assignment, dependencies: dependencies))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                assignmentHeader
                workSection
                AssignmentGradingPanel(
                    assignment: model.assignment,
                    grade: model.grade,
                    gradingError: model.gradingError,
                    retryError: model.retryError,
                    retryAssignment: model.retryAssignment,
                    isGrading: model.isGrading,
                    isGeneratingRetry: model.isGeneratingRetry,
                    onGrade: { Task { await model.gradeWork(student: profiles.selectedStudent, drawing: drawing, profiles: profiles) } },
                    onRetry: { Task { await model.generateRetry(student: profiles.selectedStudent, profiles: profiles) } }
                )
                Label("AI grading is a suggestion. Review the result before using it to make learning decisions.", systemImage: "lock.shield")
                    .font(.footnote).foregroundStyle(.secondary).padding(.horizontal, 4)
            }
            .padding(20)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .sheet(isPresented: $showingChangeRequest) {
            AssignmentChangeRequestView { request in
                try await model.applyChange(request, student: profiles.selectedStudent, profiles: profiles)
            }
        }
        .navigationTitle(model.assignment.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { restoreWorkspace() }
        .onDisappear { speech.stop() }
        .onChange(of: drawing) { _, newDrawing in
            documents.updateDrawing(newDrawing, for: model.assignment.id)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { documents.flushSave(for: model.assignment.id) }
        }
    }

    private var workSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Your work", systemImage: "pencil.tip.crop.circle").font(.headline)
                Spacer()
                Text(documents.status(for: model.assignment.id)).font(.caption).foregroundStyle(.secondary)
            }
            AssignmentWorksheetView(assignment: model.assignment, drawing: $drawing, speech: speech)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(.gray.opacity(0.25), lineWidth: 1))
        }
        .padding(18)
        .background(.background, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(.quaternary, lineWidth: 1))
    }

    private var assignmentHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(model.assignment.subject.uppercased()).font(.caption.weight(.bold)).tracking(1).foregroundStyle(.indigo)
            Text(model.assignment.title).font(.largeTitle.weight(.bold)).foregroundStyle(.primary)
            Text("Due \(model.assignment.dueDate) · \(model.assignment.points) points").font(.subheadline).foregroundStyle(.secondary)
            HStack(alignment: .top, spacing: 12) {
                Text(model.assignment.prompt).font(.body).foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                AssignmentReadAloudButton(
                    text: model.assignment.prompt,
                    id: "assignment-description",
                    speech: speech
                )
            }
            .padding(.top, 4)
            Button { showingChangeRequest = true } label: {
                Label("Adjust this worksheet", systemImage: "slider.horizontal.3")
            }
            .buttonStyle(.bordered).padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(22)
        .background(.background, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(.quaternary, lineWidth: 1))
    }

    private func restoreWorkspace() {
        let studentID = model.assignment.studentID ?? profiles.selectedStudent.id
        model.restore(for: profiles, studentID: studentID)
        drawing = documents.drawing(for: model.assignment.id)
    }
}
