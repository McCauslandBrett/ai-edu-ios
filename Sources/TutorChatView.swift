import SwiftUI
import UIKit
import PencilKit

struct TutorChatView: View {
    @Environment(\.dismiss) private var dismiss
    let student: StudentProfile
    let subject: String
    let weekNumber: Int
    let lecturePrompt: String

    @State private var messages: [TutorChatMessage] = []
    @State private var canvasItems: [String] = []
    @State private var illustration: UIImage?
    @State private var drawing = PKDrawing()
    @State private var canvasSize = CGSize.zero
    @State private var draft = ""
    @State private var isSending = false
    @State private var didStart = false
    @State private var errorMessage: String?
    @State private var illustrationError: String?
    @State private var showsConversation = false
    @State private var selectedTool: PencilCanvasToolMode = .pen

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                fullScreenWhiteboard(size: geometry.size)

                VStack(spacing: 12) {
                    sessionHeader
                    agentNotes
                    if !showsConversation {
                        latestTutorMessage
                    }
                    Spacer(minLength: 12)
                    if showsConversation {
                        conversation
                            .frame(maxHeight: geometry.size.height * 0.30)
                    }
                    composer
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
            PencilCanvas(drawing: $drawing, showsToolPicker: false, toolMode: selectedTool)
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
                Label(showsConversation ? "Hide chat" : "Chat", systemImage: "bubble.left.and.bubble.right")
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
        if !canvasItems.isEmpty || illustrationError != nil {
            VStack(alignment: .leading, spacing: 8) {
                if !canvasItems.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Array(canvasItems.enumerated()), id: \.offset) { _, item in
                                Text(item)
                                    .font(.subheadline.weight(.medium))
                                    .padding(10)
                                    .frame(maxWidth: 270, alignment: .leading)
                                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    }
                }
                if let illustrationError {
                    Text(illustrationError)
                        .font(.caption).padding(8)
                        .background(.regularMaterial, in: Capsule())
                }
            }
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

    @ViewBuilder
    private var latestTutorMessage: some View {
        if let message = messages.last(where: { $0.isVisible && $0.role == .assistant }) {
            Text(message.text)
                .font(.subheadline)
                .lineLimit(3)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                .onTapGesture { withAnimation { showsConversation = true } }
        } else if isSending {
            HStack(spacing: 8) {
                ProgressView()
                Text("Your tutor is getting the lesson ready…")
                    .font(.subheadline)
            }
            .padding(12)
            .background(.regularMaterial, in: Capsule())
        } else if let errorMessage {
            Text(errorMessage)
                .font(.subheadline).foregroundStyle(.red)
                .padding(12)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("Ask a question or explain your thinking…", text: $draft, axis: .vertical)
                .lineLimit(1...4)
                .textFieldStyle(.roundedBorder)
                .disabled(isSending)
            Button {
                sendDraft()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(.indigo)
            }
            .disabled(isSending || draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityLabel("Send message")
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
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

    private func sendDraft() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isSending else { return }
        messages.append(TutorChatMessage(role: .user, text: text))
        draft = ""
        errorMessage = nil
        Task { await sendToTutor() }
    }

    @MainActor
    private func sendToTutor() async {
        guard !isSending else { return }
        isSending = true
        errorMessage = nil
        defer { isSending = false }

        let request = TutorChatRequest(
            student: AIStudentContext(name: student.name, age: student.age, gradeLevel: student.gradeLevel),
            subject: subject,
            weekNumber: weekNumber,
            lecturePrompt: lecturePrompt,
            messages: messages.map { TutorChatRequest.Message(role: $0.role.rawValue, content: $0.text) },
            canvasItems: canvasItems,
            imageBase64: whiteboardImageBase64()
        )

        do {
            let response = try await TutorChatService().send(request)
            messages.append(TutorChatMessage(role: .assistant, text: response.reply))
            canvasItems.append(contentsOf: response.canvasItems)
            canvasItems = Array(canvasItems.suffix(12))
            if let encodedImage = response.imageBase64,
               let data = Data(base64Encoded: encodedImage),
               let newIllustration = UIImage(data: data) {
                illustration = newIllustration
                drawing = PKDrawing()
            }
            illustrationError = response.imageError
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func whiteboardImageBase64() -> String? {
        guard canvasSize.width > 0, canvasSize.height > 0,
              illustration != nil || !drawing.bounds.isEmpty else { return nil }
        let imageBounds = CGRect(origin: .zero, size: canvasSize)
        let renderer = UIGraphicsImageRenderer(size: canvasSize)
        let image = renderer.image { context in
            UIColor.white.setFill()
            context.cgContext.fill(imageBounds)
            if let illustration {
                illustration.draw(in: aspectFitRect(for: illustration.size, inside: imageBounds))
            }
            drawing.image(from: imageBounds, scale: 1).draw(in: imageBounds)
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
