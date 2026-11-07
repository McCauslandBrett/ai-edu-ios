import AVFoundation
import Speech
import Combine

@MainActor
final class TutorSpeechController: NSObject, ObservableObject {
    @Published private(set) var isRecording = false
    @Published private(set) var isTranscribing = false
    @Published private(set) var isSpeaking = false
    @Published private(set) var partialTranscript = ""
    @Published private(set) var finalTranscript = ""
    @Published private(set) var errorMessage: String?
    @Published var allowsOnlineFallback: Bool {
        didSet { UserDefaults.standard.set(allowsOnlineFallback, forKey: Self.onlineFallbackPreferenceKey) }
    }

    private static let onlineFallbackPreferenceKey = "TutorAllowsOnlineSpeechFallback"
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private let synthesizer = AVSpeechSynthesizer()
    private var recorder: AVAudioRecorder?
    private var recordingURL: URL?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var recognitionContinuation: CheckedContinuation<String, Error>?
    private var recognitionTimeoutTask: Task<Void, Never>?

    override init() {
        allowsOnlineFallback = UserDefaults.standard.object(forKey: Self.onlineFallbackPreferenceKey) as? Bool ?? true
        super.init()
        synthesizer.delegate = self
    }

    func startRecording() async {
        guard !isRecording, !isTranscribing, !isSpeaking else { return }
        errorMessage = nil
        partialTranscript = ""
        finalTranscript = ""

        guard await requestMicrophonePermission() else {
            errorMessage = "Please allow microphone access so the student can talk to the tutor."
            return
        }

        let appleSpeechAllowed = await requestSpeechPermission()
        guard appleSpeechAllowed || allowsOnlineFallback else {
            errorMessage = "Allow Speech Recognition or turn on online fallback to use voice chat."
            return
        }

        do {
            try configureRecordingSession()
            try beginAudioRecording()
        } catch {
            recorder?.stop()
            recorder = nil
            errorMessage = "I couldn't start the microphone. Please try again."
        }
    }

    func stopRecording() {
        guard isRecording, let url = recordingURL else { return }
        recorder?.stop()
        recorder = nil
        isRecording = false
        isTranscribing = true
        Task { await transcribeRecording(at: url) }
    }

    func takeFinalTranscript() -> String {
        defer { finalTranscript = "" }
        return finalTranscript
    }

    func speak(_ text: String) {
        guard !text.isEmpty else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio)
            try session.setActive(true)
            let utterance = AVSpeechUtterance(string: text)
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
            utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.82
            synthesizer.speak(utterance)
        } catch {
            errorMessage = "I couldn't play the tutor's voice."
        }
    }

    func stopSpeaking() {
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
    }

    private func requestMicrophonePermission() async -> Bool {
        if AVAudioApplication.shared.recordPermission == .granted { return true }
        return await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { allowed in continuation.resume(returning: allowed) }
        }
    }

    private func requestSpeechPermission() async -> Bool {
        let status = SFSpeechRecognizer.authorizationStatus()
        if status == .authorized { return true }
        guard status == .notDetermined else { return false }
        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    private func configureRecordingSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .allowBluetoothHFP])
        try session.setActive(true, options: .notifyOthersOnDeactivation)
    }

    private func beginAudioRecording() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("tutor-\(UUID().uuidString).m4a")
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 22_050,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
        ]
        let newRecorder = try AVAudioRecorder(url: url, settings: settings)
        newRecorder.isMeteringEnabled = false
        guard newRecorder.record() else {
            throw LearningAIServiceError.service("The microphone could not start recording.")
        }
        recorder = newRecorder
        recordingURL = url
        isRecording = true
    }

    private func transcribeRecording(at url: URL) async {
        defer {
            try? FileManager.default.removeItem(at: url)
            recordingURL = nil
            isTranscribing = false
        }

        if SFSpeechRecognizer.authorizationStatus() == .authorized,
           let recognizer, recognizer.isAvailable {
            do {
                let text = try await transcribeWithAppleSpeech(at: url, recognizer: recognizer)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty {
                    partialTranscript = text
                    finalTranscript = text
                    return
                }
            } catch {
                // An unavailable Apple speech model falls through to the optional service path.
            }
        }

        guard allowsOnlineFallback else {
            errorMessage = "Apple Speech couldn't hear words. Try again, or enable online speech fallback."
            return
        }

        do {
            let audio = try Data(contentsOf: url)
            let result = try await TutorChatService().transcribe(audio: audio)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !result.isEmpty else {
                errorMessage = "I didn't catch that. Tap the microphone and try again."
                return
            }
            partialTranscript = result
            finalTranscript = result
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func transcribeWithAppleSpeech(at url: URL, recognizer: SFSpeechRecognizer) async throws -> String {
        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = true
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }

        return try await withCheckedThrowingContinuation { continuation in
            recognitionContinuation = continuation
            recognitionTimeoutTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(15))
                guard !Task.isCancelled else { return }
                self?.finishAppleRecognition(throwing: LearningAIServiceError.service("Apple Speech timed out."))
            }
            recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
                Task { @MainActor in
                    guard let self else { return }
                    if let result {
                        self.partialTranscript = result.bestTranscription.formattedString
                        if result.isFinal {
                            self.finishAppleRecognition(returning: result.bestTranscription.formattedString)
                        }
                    }
                    if let error {
                        self.finishAppleRecognition(throwing: error)
                    }
                }
            }
        }
    }

    private func finishAppleRecognition(returning text: String) {
        guard let continuation = recognitionContinuation else { return }
        recognitionContinuation = nil
        recognitionTimeoutTask?.cancel()
        recognitionTimeoutTask = nil
        recognitionTask = nil
        continuation.resume(returning: text)
    }

    private func finishAppleRecognition(throwing error: Error) {
        guard let continuation = recognitionContinuation else { return }
        recognitionContinuation = nil
        recognitionTimeoutTask?.cancel()
        recognitionTimeoutTask = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        continuation.resume(throwing: error)
    }
}

extension TutorSpeechController: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        Task { @MainActor in isSpeaking = true }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in isSpeaking = false }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in isSpeaking = false }
    }
}
