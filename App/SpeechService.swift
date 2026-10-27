import AVFoundation

/// Sprachansagen. Musik wird dabei leiser gestellt (Ducking) statt unterbrochen – einstellbar (LESSONS_SWIFT 4).
/// Nach der Ansage wird die Audio-Sitzung freigegeben, damit andere Apps wieder normal laut spielen.
@MainActor
final class SpeechService: NSObject, AVSpeechSynthesizerDelegate {
    var enabled = true
    var duckOthers = true
    /// GM-043: gewählte Stimme (nil = beste deutsche) und Sprechtempo (0,8 … 1,2 × normal)
    var voiceIdentifier: String?
    var rateFactor: Float = 1
    var onSpeakingChange: ((Bool) -> Void)?
    private let synthesizer = AVSpeechSynthesizer()

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func say(_ text: String) {
        guard enabled else { return }
        let session = AVAudioSession.sharedInstance()
        let options: AVAudioSession.CategoryOptions = duckOthers ? [.duckOthers, .interruptSpokenAudioAndMixWithOthers] : []
        try? session.setCategory(.playback, mode: .voicePrompt, options: options)
        try? session.setActive(true)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voiceIdentifier.flatMap { AVSpeechSynthesisVoice(identifier: $0) } ?? Self.bestGermanVoice
        utterance.rate = min(AVSpeechUtteranceMaximumSpeechRate, AVSpeechUtteranceDefaultSpeechRate * rateFactor)
        synthesizer.speak(utterance)
        onSpeakingChange?(true)
    }

    /// GM-023: beste installierte deutsche Stimme (Premium > Erweitert > Standard). Premium-Stimmen lädt der Nutzer
    /// in iOS unter Einstellungen → Bedienungshilfen → Gesprochene Inhalte → Stimmen → Deutsch.
    static var bestGermanVoice: AVSpeechSynthesisVoice? {
        let de = AVSpeechSynthesisVoice.speechVoices().filter { $0.language == "de-DE" }
        let best = de.max { a, b in a.quality.rawValue < b.quality.rawValue }
        return best ?? AVSpeechSynthesisVoice(language: "de-DE")
    }

    /// GM-043: alle installierten deutschen Stimmen für die Auswahl (beste zuerst)
    static var germanVoices: [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("de") }
            .sorted { a, b in a.quality.rawValue != b.quality.rawValue ? a.quality.rawValue > b.quality.rawValue : a.name < b.name }
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in self.release() }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in self.release() }
    }

    private func release() {
        guard !synthesizer.isSpeaking else { return }
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        onSpeakingChange?(false)
    }
}
