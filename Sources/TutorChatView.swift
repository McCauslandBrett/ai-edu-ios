import SwiftUI
import UIKit
import PencilKit

struct TutorChatView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var profiles: StudentProfileStore
    let student: StudentProfile
    let subject: String
    let weekNumber: Int
    let lecturePrompt: String

    @StateObject private var speech = TutorSpeechController()
    @StateObject private var model: TutorChatSessionModel
    @State private var canvasSize = CGSize.zero
    @State private var showsConversation = false
    @State private var selectedTool: PencilCanvasToolMode = .pen

    init(student: StudentProfile, subject: String, weekNumber: Int, lecturePrompt: String) {
        self.student = student
        self.subject = subject
        self.weekNumber = weekNumber
        self.lecturePrompt = lecturePrompt
        _model = StateObject(wrappedValue: TutorChatSessionModel(
            student: student,
            subject: subject,
            weekNumber: weekNumber,
            lecturePrompt: lecturePrompt
        ))
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                fullScreenWhiteboard(size: geometry.size)

                VStack(spacing: 12) {
                    sessionHeader
                    agentNotes
                    Spacer(minLength: 12)
                    if showsConversation {
                        conversation
                            .frame(maxHeight: geometry.size.height * 0.30)
                    }
                    voiceControls
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .safeAreaPadding(.top, 8)
                .safeAreaPadding(.bottom, 8)
            }
        }
        .background(Color.white)
        .ignoresSafeArea()
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .task { await model.beginLesson { speech.speak($0) } }
        .onChange(of: speech.finalTranscript) { _, _ in
            handleFinalTranscript()
        }
    }

    private func fullScreenWhiteboard(size: CGSize) -> some View {
        ZStack {
            Color.white
            if let illustration = model.illustration {
                Image(uiImage: illustration)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size.width, height: size.height)
            }
            PencilCanvas(
                drawing: $model.drawing,
                showsToolPicker: false,
                toolMode: selectedTool,
                drawingPolicy: .anyInput
            )
                .frame(width: size.width, height: size.height)
        }
        .onAppear { canvasSize = size }
        .onChange(of: size) { _, newSize in canvasSize = newSize }
    }

    private var sessionHeader: some View {
        HStack(spacing: 12) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.backward")
                    .font(.headline.weight(.semibold))
                    .frame(width: 42, height: 42)
                    .background(.regularMaterial, in: Circle())
            }
            .accessibilityLabel("Close tutor session")

            VStack(alignment: .leading, spacing: 2) {
                Text("\(subject) · Week \(weekNumber)")
                    .font(.headline)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text("Whiteboard · \(student.name)")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 8)
            .background(.regularMaterial, in: Capsule())

            Spacer(minLength: 4)

            drawingTools

            Button {
                withAnimation(.easeInOut(duration: 0.2)) { showsConversation.toggle() }
            } label: {
                Label(showsConversation ? "Hide transcript" : "Transcript", systemImage: "text.bubble")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 14)
                    .frame(height: 42)
                    .background(.regularMaterial, in: Capsule())
            }
        }
        .buttonStyle(.plain)
    }

    private var drawingTools: some View {
        HStack(spacing: 4) {
            toolButton(.pen, symbol: "pencil.tip", label: "Pen")
            toolButton(.eraser, symbol: "eraser", label: "Eraser")
        }
        .padding(4)
        .background(.regularMaterial, in: Capsule())
    }

    private func toolButton(_ tool: PencilCanvasToolMode, symbol: String, label: String) -> some View {
        Button {
            selectedTool = tool
        } label: {
            Image(systemName: symbol)
                .font(.subheadline.weight(.semibold))
                .frame(width: 36, height: 34)
                .background(selectedTool == tool ? Color.indigo.opacity(0.18) : .clear, in: Capsule())
        }
        .accessibilityLabel(label)
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var agentNotes: some View {
        if let illustrationError = model.illustrationError {
            Text(illustrationError)
                .font(.caption).padding(8)
                .background(.regularMaterial, in: Capsule())
        }
    }

    private var conversation: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(model.messages.filter(\.isVisible)) { message in
                        TutorMessageBubble(message: message)
                            .id(message.id)
                    }
                    if model.isSending {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("Tutor is thinking…").font(.subheadline).foregroundStyle(.secondary)
                        }
                        .padding(12)
                    }
                    if let errorMessage = model.errorMessage {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(errorMessage).font(.subheadline).foregroundStyle(.red)
                            Button("Try again") { Task { await sendToTutor() } }
                                .disabled(model.isSending)
                        }
                        .padding(12)
                    }
                }
                .padding(14)
            }
            .onChange(of: model.messages.count) { _, _ in
                guard let lastMessage = model.messages.last(where: \.isVisible) else { return }
                withAnimation { proxy.scrollTo(lastMessage.id, anchor: .bottom) }
            }
        }
        .padding(6)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    private var voiceControls: some View {
        VStack(spacing: 8) {
            voiceStatus
            if model.sessionReadyToComplete {
                Button(action: completeSession) {
                    Label("Complete session", systemImage: "checkmark.seal.fill")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: 380)
                        .frame(height: 58)
                        .background(Color.green, in: Capsule())
                }
                .disabled(model.didCompleteSession)
            } else {
                HStack(spacing: 10) {
                    Button {
                        toggleRecording()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: speech.isRecording ? "checkmark" : "mic.fill")
                                .font(.title2.bold())
                            Text(speech.isRecording ? "I'm done" : "Tap to talk")
                                .font(.title3.weight(.bold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: 360)
                        .frame(height: 66)
                        .background(speech.isRecording ? Color.red : Color.indigo, in: Capsule())
                    }
                    .disabled(model.isSending || speech.isTranscribing || speech.isSpeaking)
                    .accessibilityLabel(speech.isRecording ? "Finish speaking" : "Talk to the tutor")

                    Menu {
                        Toggle("Allow online fallback (uses AI credits)", isOn: $speech.allowsOnlineFallback)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.title2.weight(.semibold))
                            .frame(width: 44, height: 44)
                            .background(.thinMaterial, in: Circle())
                    }
                    .accessibilityLabel("Voice transcription options")
                }

                HStack(spacing: 12) {
                    Button {
                        speech.stopSpeaking()
                        Task { await sendToTutor(action: "check-whiteboard") }
                    } label: {
                        Label("Check my work", systemImage: "paperplane.fill")
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 14)
                            .frame(height: 42)
                            .background(.thinMaterial, in: Capsule())
                    }
                    .disabled(model.isSending || speech.isTranscribing || speech.isRecording)

                    Button {
                        speech.stopSpeaking()
                        Task { await sendToTutor(action: "next-question") }
                    } label: {
                        Label("Next question", systemImage: "arrow.right.circle.fill")
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 14)
                            .frame(height: 42)
                            .background(.thinMaterial, in: Capsule())
                    }
                    .disabled(model.isSending || speech.isTranscribing || speech.isRecording)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    @ViewBuilder
    private var voiceStatus: some View {
        if model.sessionReadyToComplete {
            Label("Lesson complete · ready to finish", systemImage: "checkmark.circle.fill")
                .font(.subheadline.weight(.semibold))
        } else if model.isSending || speech.isTranscribing {
            HStack(spacing: 8) {
                ProgressView()
                Text(model.isSending ? "Tutor is thinking…" : "Checking Apple Speech, then online if allowed…")
                    .font(.subheadline.weight(.medium))
            }
        } else if speech.isSpeaking {
            Label("Listen to your tutor", systemImage: "speaker.wave.2.fill")
                .font(.subheadline.weight(.medium))
        } else if speech.isRecording {
            Label("Tell your tutor what you think", systemImage: "waveform")
                .font(.subheadline.weight(.medium))
        } else {
            Label("Tap the microphone and tell your tutor", systemImage: "mic")
                .font(.subheadline.weight(.medium))
        }

        if let message = speech.errorMessage ?? model.errorMessage {
            Text(message)
                .font(.caption).foregroundStyle(.red)
                .multilineTextAlignment(.center)
        }
    }

    private func handleFinalTranscript() {
        let text = speech.takeFinalTranscript()
        guard model.receiveTranscript(text) else { return }
        Task { await sendToTutor() }
    }

    private func toggleRecording() {
        if speech.isRecording {
            speech.stopRecording()
        } else {
            Task { await speech.startRecording() }
        }
    }

    @MainActor
    private func sendToTutor(action: String? = nil) async {
        let image = TutorWhiteboardSnapshotEncoder().base64(
            illustration: model.illustration,
            drawing: model.drawing,
            canvasSize: canvasSize
        )
        await model.send(action: action, imageBase64: image) { speech.speak($0) }
    }

    @MainActor
    private func completeSession() {
        guard model.complete(profiles: profiles) else { return }
        speech.stopSpeaking()
        dismiss()
    }
}



private struct TutorMessageBubble: View {
    let message: TutorChatMessage

    private var isTutor: Bool { message.role == .assistant }

    var body: some View {
        HStack {
            if !isTutor { Spacer(minLength: 36) }
            Text(message.text)
                .font(.body)
                .padding(13)
                .foregroundStyle(isTutor ? Color.primary : Color.white)
                .background(
                    isTutor ? Color(uiColor: .secondarySystemBackground) : Color.indigo,
                    in: RoundedRectangle(cornerRadius: 16)
                )
            if isTutor { Spacer(minLength: 36) }
        }
    }
}
