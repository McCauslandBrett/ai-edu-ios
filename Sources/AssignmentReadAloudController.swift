import AVFoundation
import Combine

@MainActor
final class AssignmentReadAloudController: NSObject, ObservableObject {
    @Published private(set) var speakingID: String?

    private let synthesizer = AVSpeechSynthesizer()
    private var activeUtterance: AVSpeechUtterance?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func toggle(_ text: String, id: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        if speakingID == id, synthesizer.isSpeaking {
            stop()
            return
        }

        stop()
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? session.setActive(true)

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: Locale.preferredLanguages.first ?? "en-US")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.82
        activeUtterance = utterance
        speakingID = id
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        activeUtterance = nil
        speakingID = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func finish(_ utterance: AVSpeechUtterance) {
        guard activeUtterance === utterance else { return }
        activeUtterance = nil
        speakingID = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

extension AssignmentReadAloudController: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in finish(utterance) }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in finish(utterance) }
    }
}
