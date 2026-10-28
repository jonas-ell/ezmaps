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
    private var releaseTask: Task<Void, Never>?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func say(_ text: String) {
        guard enabled else { return }
        releaseTask?.cancel()
        let session = AVAudioSession.sharedInstance()
        let options: AVAudioSession.CategoryOptions = duckOthers ? [.duckOthers, .interruptSpokenAudioAndMixWithOthers] : []
        try? session.setCategory(.playback, mode: .voicePrompt, options: options)
        try? session.setActive(true)
        let utterance = AVSpeechUtterance(string: text)
        // GM-055: nur gute Stimmen (Erweitert/Premium) – die Standard-Stimme klang laut Nutzer „sehr sehr schlecht“; ohne gute Stimme keine Ansage
        guard let voice = voiceIdentifier.flatMap({ AVSpeechSynthesisVoice(identifier: $0) }).flatMap({ $0.quality != .default ? $0 : nil }) ?? Self.bestGermanVoice else { return }
        utterance.voice = voice
        utterance.rate = min(AVSpeechUtteranceMaximumSpeechRate, AVSpeechUtteranceDefaultSpeechRate * 0.96 * rateFactor) // GM-050: etwas ruhiger
        utterance.pitchMultiplier = 1.03
        utterance.postUtteranceDelay = 0.15
        synthesizer.speak(utterance)
        onSpeakingChange?(true)
    }

    /// GM-023: beste installierte deutsche Stimme (Premium > Erweitert > Standard). Premium-Stimmen lädt der Nutzer
    /// in iOS unter Einstellungen → Bedienungshilfen → Gesprochene Inhalte → Stimmen → Deutsch.
    static var bestGermanVoice: AVSpeechSynthesisVoice? {
        let de = AVSpeechSynthesisVoice.speechVoices().filter { $0.language == "de-DE" }
        // GM-055: nur Erweitert/Premium, sonst nil (keine Ansage)
        return de.filter { $0.quality != .default }.max { a, b in a.quality.rawValue < b.quality.rawValue }
    }

    /// GM-043: alle installierten deutschen Stimmen für die Auswahl (beste zuerst)
    static var germanVoices: [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("de") && $0.quality != .default } // GM-055
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

    /// GM-050: erst 0,6 s nach dem Ende freigeben – vorher wurde die Sitzung zwischen zwei Ansagen abgeschaltet und
    /// die nächste brach ab („bricht manchmal ab“)
    private func release() {
        releaseTask?.cancel()
        releaseTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 600_000_000)
            guard let self, !Task.isCancelled, !self.synthesizer.isSpeaking else { return }
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            self.onSpeakingChange?(false)
        }
    }
}
