import AVFoundation
import AudioToolbox

/// Tiny system-sound helper for the basketball game (no bundled assets).
enum BasketballSounds {
    static func swish() {
        play(1306) // SMS received-ish bright
    }
    static func rim() {
        play(1104) // short click
    }
    static func bounce() {
        play(1103)
    }
    static func score() {
        play(1057) // short positive
    }
    static func gameOver() {
        play(1025)
    }

    private static func play(_ id: SystemSoundID) {
        AudioServicesPlaySystemSound(id)
    }
}
