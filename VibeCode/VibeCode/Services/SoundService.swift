import AVFoundation
import Foundation

/// Sound preferences for individual events
struct SoundPreferences: Codable {
    var sessionStart: Bool = true
    var sessionEnd: Bool = true
    var responseComplete: Bool = true
    var permissionRequest: Bool = true
    var toolExecution: Bool = false
}

/// Plays sound effects for session events using configurable sound packs
class SoundService {
    static let shared = SoundService()
    private var players: [String: AVAudioPlayer] = [:]
    private let packStore = SoundPackStore.shared

    @UserDefaultsBacked(key: "soundsEnabled", defaultValue: true)
    var isEnabled: Bool

    @UserDefaultsBacked(key: "soundVolume", defaultValue: 0.7)
    var volume: Float

    @UserDefaultsBacked(key: "soundPreferences", defaultValue: SoundPreferences())
    var preferences: SoundPreferences

    private init() {
        reloadSounds()
    }

    /// Reload all sounds from the currently selected pack
    func reloadSounds() {
        players.removeAll()
        let pack = packStore.selectedPack

        for (eventKey, filename) in pack.sounds {
            if let player = loadSound(filename: filename, packId: pack.id) {
                player.prepareToPlay()
                players[eventKey] = player
            }
        }
    }

    /// Load a sound file, trying pack bundle → bundle root → custom dir → system sounds
    private func loadSound(filename: String, packId: String) -> AVAudioPlayer? {
        let nameWithoutExt = (filename as NSString).deletingPathExtension
        let ext = (filename as NSString).pathExtension

        if !ext.isEmpty {
            // 1. Try app bundle: Sounds/<packId>/<filename>
            if let url = Bundle.main.url(forResource: nameWithoutExt, withExtension: ext, subdirectory: "Sounds/\(packId)") {
                return try? AVAudioPlayer(contentsOf: url)
            }
            // 2. Try Sounds/ subdirectory
            if let url = Bundle.main.url(forResource: nameWithoutExt, withExtension: ext, subdirectory: "Sounds") {
                return try? AVAudioPlayer(contentsOf: url)
            }
            // 3. Try bundle root (XcodeGen flattens resources here)
            if let url = Bundle.main.url(forResource: nameWithoutExt, withExtension: ext) {
                return try? AVAudioPlayer(contentsOf: url)
            }
        }

        // 2. Try custom pack directory: ~/.vibecode/sounds/<packId>/<filename>
        let customPath = packStore.customPackDirectory(for: packId) + "/" + filename
        if FileManager.default.fileExists(atPath: customPath) {
            return try? AVAudioPlayer(contentsOf: URL(fileURLWithPath: customPath))
        }

        // 3. Try system sound by name (for Minimal/Retro packs that reference system sound names)
        let systemPath = "/System/Library/Sounds/\(filename).aiff"
        if FileManager.default.fileExists(atPath: systemPath) {
            return try? AVAudioPlayer(contentsOf: URL(fileURLWithPath: systemPath))
        }

        // 4. Fallback: try the filename as a direct system sound path
        let directPath = "/System/Library/Sounds/\(filename)"
        if FileManager.default.fileExists(atPath: directPath) {
            return try? AVAudioPlayer(contentsOf: URL(fileURLWithPath: directPath))
        }

        return nil
    }

    func play(_ event: HookEventType) {
        guard isEnabled else { return }

        let soundKey: String?
        let isEventEnabled: Bool

        switch event {
        case .sessionStart:
            soundKey = "sessionStart"
            isEventEnabled = preferences.sessionStart
        case .sessionEnd:
            soundKey = "sessionEnd"
            isEventEnabled = preferences.sessionEnd
        case .stop:
            soundKey = "responseComplete"
            isEventEnabled = preferences.responseComplete
        case .permissionRequest:
            soundKey = "permissionRequest"
            isEventEnabled = preferences.permissionRequest
        case .postToolUse:
            soundKey = "toolExecution"
            isEventEnabled = preferences.toolExecution
        default:
            soundKey = nil
            isEventEnabled = false
        }

        guard isEventEnabled, let key = soundKey, let player = players[key] else { return }
        player.volume = volume
        player.currentTime = 0
        player.play()
    }

    /// Preview a specific event's sound (for settings UI)
    func previewSound(eventKey: String) {
        guard let player = players[eventKey] else { return }
        player.volume = volume
        player.currentTime = 0
        player.play()
    }
}
