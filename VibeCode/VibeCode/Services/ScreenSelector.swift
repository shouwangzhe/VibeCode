import AppKit

extension NSScreen {
    var displayID: CGDirectDisplayID {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID) ?? 0
    }
}

enum ScreenPreference: Codable, Hashable, Equatable {
    case auto
    case specific(displayID: UInt32)

    // Custom Codable for enum with associated values
    private enum CodingKeys: String, CodingKey {
        case type, displayID
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "specific":
            let id = try container.decode(UInt32.self, forKey: .displayID)
            self = .specific(displayID: id)
        default:
            self = .auto
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .auto:
            try container.encode("auto", forKey: .type)
        case .specific(let id):
            try container.encode("specific", forKey: .type)
            try container.encode(id, forKey: .displayID)
        }
    }
}

@Observable
class ScreenSelector {
    static let shared = ScreenSelector()

    @ObservationIgnored
    private var _preferenceStorage = UserDefaultsBacked(key: "screenPreference", defaultValue: ScreenPreference.auto)

    var preference: ScreenPreference {
        get { _preferenceStorage.wrappedValue }
        set { _preferenceStorage.wrappedValue = newValue }
    }

    var availableScreens: [NSScreen] {
        NSScreen.screens
    }

    var selectedScreen: NSScreen {
        switch preference {
        case .auto:
            // Prefer screen with notch, fallback to main
            return NSScreen.screens.first(where: { NotchGeometry.hasNotch(screen: $0) })
                ?? NSScreen.main
                ?? NSScreen.screens[0]
        case .specific(let displayID):
            return NSScreen.screens.first(where: { $0.displayID == displayID })
                ?? NSScreen.main
                ?? NSScreen.screens[0]
        }
    }

    func screenName(for screen: NSScreen) -> String {
        screen.localizedName
    }

    func preferenceTag(for screen: NSScreen) -> ScreenPreference {
        .specific(displayID: screen.displayID)
    }

    private init() {}
}
