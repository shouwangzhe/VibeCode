import Foundation

@Observable
class SoundPackStore {
    static let shared = SoundPackStore()

    @ObservationIgnored
    private var _selectedPackIdStorage = UserDefaultsBacked(key: "selectedSoundPackId", defaultValue: "default")

    var selectedPackId: String {
        get { _selectedPackIdStorage.wrappedValue }
        set { _selectedPackIdStorage.wrappedValue = newValue }
    }

    private(set) var availablePacks: [SoundPack] = []

    var selectedPack: SoundPack {
        availablePacks.first(where: { $0.id == selectedPackId }) ?? Self.builtInPacks[0]
    }

    static let builtInPacks: [SoundPack] = [
        SoundPack(
            id: "default",
            name: "Default",
            description: "Standard notification sounds",
            author: "VibeCode",
            sounds: [
                "sessionStart": "session_start.aiff",
                "sessionEnd": "session_end.aiff",
                "responseComplete": "tool_execution.aiff",
                "permissionRequest": "permission_request.aiff",
                "toolExecution": "tool_execution.aiff",
            ]
        ),
        SoundPack(
            id: "minimal",
            name: "Minimal",
            description: "Subtle, unobtrusive sounds",
            author: "VibeCode",
            sounds: [
                "sessionStart": "Blow",
                "responseComplete": "Tink",
                "permissionRequest": "Tink",
            ]
        ),
        SoundPack(
            id: "retro",
            name: "Retro",
            description: "Classic computer sounds",
            author: "VibeCode",
            sounds: [
                "sessionStart": "Hero",
                "sessionEnd": "Glass",
                "responseComplete": "Purr",
                "permissionRequest": "Sosumi",
                "toolExecution": "Pop",
            ]
        ),
    ]

    private init() {
        loadPacks()
    }

    func loadPacks() {
        availablePacks = Self.builtInPacks
        availablePacks.append(contentsOf: loadCustomPacks())
    }

    private func loadCustomPacks() -> [SoundPack] {
        let customDir = NSHomeDirectory() + "/.vibecode/sounds"
        guard let subdirs = try? FileManager.default.contentsOfDirectory(atPath: customDir) else {
            return []
        }
        return subdirs.compactMap { dir in
            let packDir = customDir + "/" + dir
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: packDir, isDirectory: &isDir),
                  isDir.boolValue else { return nil }
            return loadCustomPack(at: packDir)
        }
    }

    private func loadCustomPack(at path: String) -> SoundPack? {
        let manifestPath = path + "/pack.json"
        guard let data = FileManager.default.contents(atPath: manifestPath),
              let pack = try? JSONDecoder().decode(SoundPack.self, from: data) else {
            return nil
        }
        return pack
    }

    /// Get the directory path for a custom pack's sound files
    func customPackDirectory(for packId: String) -> String {
        NSHomeDirectory() + "/.vibecode/sounds/" + packId
    }
}
