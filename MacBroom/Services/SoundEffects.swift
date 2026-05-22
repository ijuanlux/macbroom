import AppKit

@MainActor
enum SoundEffects {
    /// Plays a quick system sound for cleanup completion. Respects user preference.
    static func playCleanup() {
        guard UserDefaults.standard.object(forKey: "macbroom.soundEffects") as? Bool ?? true else { return }
        // Built-in macOS sound that fits "completion / swoosh" vibe.
        NSSound(named: NSSound.Name("Glass"))?.play()
    }
}
