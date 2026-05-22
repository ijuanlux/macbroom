import Foundation
import AVFoundation

/// TTS wrapper for MacBroom's apple. Speaks short lines via AVSpeechSynthesizer
/// when the user has the voice toggle on. Picks a retro-feeling voice when
/// available (Fred / Albert / Junior — classic Macintalk roster) and falls
/// back to the default system voice otherwise.
@MainActor
final class VoiceNarrator {
    static let shared = VoiceNarrator()

    private let synth = AVSpeechSynthesizer()
    private let voiceIdentifier: String? = {
        let preferred = ["com.apple.speech.synthesis.voice.Fred",
                         "com.apple.speech.synthesis.voice.Albert",
                         "com.apple.speech.synthesis.voice.Junior",
                         "com.apple.speech.synthesis.voice.Ralph"]
        for id in preferred {
            if AVSpeechSynthesisVoice(identifier: id) != nil { return id }
        }
        return nil
    }()

    /// Reads the @AppStorage flag and decides if we speak.
    var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: "macbroom.voiceEnabled")
    }

    /// Strips emoji + tool-call noise so the synthesizer doesn't say "smiling
    /// face with sunglasses". Keeps it natural.
    private func sanitize(_ text: String) -> String {
        var out = text
        out = out.replacingOccurrences(of: "🧹", with: "")
        // Strip any character whose unicode scalar is in the emoji block.
        out = String(out.unicodeScalars.filter { !$0.properties.isEmoji || $0.value < 0x80 })
        // Replace common chat shorthand for a more natural read
        out = out
            .replacingOccurrences(of: "fr", with: "for real")
            .replacingOccurrences(of: "lol", with: "ha")
            .replacingOccurrences(of: "ngl", with: "")
            .replacingOccurrences(of: "rn", with: "right now")
        return out.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func speak(_ text: String) {
        guard isEnabled else { return }
        let clean = sanitize(text)
        guard !clean.isEmpty else { return }
        let utterance = AVSpeechUtterance(string: clean)
        if let id = voiceIdentifier, let voice = AVSpeechSynthesisVoice(identifier: id) {
            utterance.voice = voice
        }
        // Retro feel — slightly higher pitch, slightly faster
        utterance.pitchMultiplier = 1.15
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 1.05
        utterance.volume = 0.95
        synth.stopSpeaking(at: .immediate)
        synth.speak(utterance)
    }

    func stop() {
        synth.stopSpeaking(at: .immediate)
    }
}
