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
    @State private var messages: [TutorChatMessage] = []
    @State private var canvasItems: [String] = []
    @State private var illustration: UIImage?
    @State private var drawing = PKDrawing()
    @State private var canvasSize = CGSize.zero
    @State private var isSending = false
    @State private var didStart = false
    @State private var errorMessage: String?
    @State private var illustrationError: String?
    @State private var showsConversation = false
    @State private var selectedTool: PencilCanvasToolMode = .pen
    @State private var tutorTurnCount = 0
    @State private var sessionReadyToComplete = false
    @State private var completionReason: String?
    @State private var didCompleteSession = false

    private let maximumTutorTurns = 5

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
        .task { await beginLesson() }
        .onChange(of: speech.finalTranscript) { _, _ in
            handleFinalTranscript()
        }
    }

    private func fullScreenWhiteboard(size: CGSize) -> some View {
        ZStack {
            Color.white
            if let illustration {
                Image(uiImage: illustration)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size.width, height: size.height)
            }
            PencilCanvas(
                drawing: $drawing,
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
        if let illustrationError {
            Text(illustrationError)
                .font(.caption).padding(8)
                .background(.regularMaterial, in: Capsule())
        }
    }

    private var conversation: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(messages.filter(\.isVisible)) { message in
                        TutorMessageBubble(message: message)
                            .id(message.id)
                    }
                    if isSending {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("Tutor is thinking…").font(.subheadline).foregroundStyle(.secondary)
                        }
                        .padding(12)
                    }
                    if let errorMessage {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(errorMessage).font(.subheadline).foregroundStyle(.red)
                            Button("Try again") { Task { await sendToTutor() } }
                                .disabled(isSending)
                        }
                        .padding(12)
                    }
                }
                .padding(14)
            }
            .onChange(of: messages.count) { _, _ in
                guard let lastMessage = messages.last(where: \.isVisible) else { return }
                withAnimation { proxy.scrollTo(lastMessage.id, anchor: .bottom) }
            }
        }
        .padding(6)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    private var voiceControls: some View {
        VStack(spacing: 8) {
            voiceStatus
            if sessionReadyToComplete {
                Button(action: completeSession) {
                    Label("Complete session", systemImage: "checkmark.seal.fill")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: 380)
                        .frame(height: 58)
                        .background(Color.green, in: Capsule())
                }
                .disabled(didCompleteSession)
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
                    .disabled(isSending || speech.isTranscribing || speech.isSpeaking)
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
                    .disabled(isSending || speech.isTranscribing || speech.isRecording)

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
                    .disabled(isSending || speech.isTranscribing || speech.isRecording)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    @ViewBuilder
    private var voiceStatus: some View {
        if sessionReadyToComplete {
            Label("Lesson complete · ready to finish", systemImage: "checkmark.circle.fill")
                .font(.subheadline.weight(.semibold))
        } else if isSending || speech.isTranscribing {
            HStack(spacing: 8) {
                ProgressView()
                Text(isSending ? "Tutor is thinking…" : "Checking Apple Speech, then online if allowed…")
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

        if let message = speech.errorMessage ?? errorMessage {
            Text(message)
                .font(.caption).foregroundStyle(.red)
                .multilineTextAlignment(.center)
        }
    }

    @MainActor
    private func beginLesson() async {
        guard !didStart else { return }
        didStart = true
        messages.append(TutorChatMessage(
            role: .user,
            text: "Start the lesson by greeting the student and asking one engaging first question.",
            isVisible: false
        ))
        await sendToTutor()
    }

    private func handleFinalTranscript() {
        let text = speech.takeFinalTranscript().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isSending else { return }
        messages.append(TutorChatMessage(role: .user, text: text))
        errorMessage = nil
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
        guard !isSending, !sessionReadyToComplete else { return }
        isSending = true
        errorMessage = nil
        defer { isSending = false }

        let request = TutorChatRequest(
            student: AIStudentContext(name: student.name, age: student.age, gradeLevel: student.gradeLevel),
            subject: subject,
            weekNumber: weekNumber,
            lecturePrompt: lecturePrompt,
            action: action,
            tutorTurnCount: tutorTurnCount,
            messages: messages.suffix(24).map { TutorChatRequest.Message(role: $0.role.rawValue, content: $0.text) },
            canvasItems: canvasItems,
            imageBase64: whiteboardImageBase64()
        )

        do {
            let response = try await TutorChatService().send(request)
            tutorTurnCount += 1
            if response.sessionComplete || tutorTurnCount >= maximumTutorTurns {
                sessionReadyToComplete = true
                completionReason = response.completionReason ?? "Finished after \(tutorTurnCount) tutor turns."
            }
            messages.append(TutorChatMessage(role: .assistant, text: response.reply))
            canvasItems.append(contentsOf: response.canvasItems)
            canvasItems = Array(canvasItems.suffix(12))
            speech.speak(response.reply)
            if action != "check-whiteboard",
               let encodedImage = response.imageBase64,
               let data = Data(base64Encoded: encodedImage),
               let newIllustration = UIImage(data: data) {
                illustration = newIllustration
                drawing = PKDrawing()
            }
            illustrationError = response.imageError
        } catch {
            errorMessage = error.localizedDescription
            speech.speak("I couldn't reach your tutor. Please ask a grown-up to help.")
        }
    }

    @MainActor
    private func completeSession() {
        guard sessionReadyToComplete, !didCompleteSession else { return }
        didCompleteSession = true
        profiles.recordTutorSession(
            studentID: student.id,
            subject: subject,
            weekNumber: weekNumber,
            tutorTurnCount: tutorTurnCount,
            completionReason: completionReason ?? "Tutor session completed."
        )
        speech.stopSpeaking()
        dismiss()
    }

    private func whiteboardImageBase64() -> String? {
        guard canvasSize.width > 0, canvasSize.height > 0,
              illustration != nil || !drawing.bounds.isEmpty else { return nil }
        let scale = min(1, 1_024 / max(canvasSize.width, canvasSize.height))
        let outputSize = CGSize(width: canvasSize.width * scale, height: canvasSize.height * scale)
        let outputBounds = CGRect(origin: .zero, size: outputSize)
        let sourceBounds = CGRect(origin: .zero, size: canvasSize)
        let renderer = UIGraphicsImageRenderer(size: outputSize)
        let image = renderer.image { context in
            UIColor.white.setFill()
            context.cgContext.fill(outputBounds)
            if let illustration {
                illustration.draw(in: aspectFitRect(for: illustration.size, inside: outputBounds))
            }
            drawing.image(from: sourceBounds, scale: scale).draw(in: outputBounds)
        }
        return image.pngData()?.base64EncodedString()
    }

    private func aspectFitRect(for imageSize: CGSize, inside bounds: CGRect) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else { return bounds }
        let scale = min(bounds.width / imageSize.width, bounds.height / imageSize.height)
        let fittedSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return CGRect(
            x: bounds.midX - fittedSize.width / 2,
            y: bounds.midY - fittedSize.height / 2,
            width: fittedSize.width,
            height: fittedSize.height
        )
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
