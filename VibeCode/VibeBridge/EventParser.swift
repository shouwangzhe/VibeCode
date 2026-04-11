import Foundation
import Shared

/// Parses Claude Code hook JSON input and determines event type
struct EventParser {
    static func parse(data: Data) -> (HookEventType, HookInput)? {
        guard let input = try? JSONDecoder().decode(HookInput.self, from: data) else {
            return nil
        }

        guard let eventName = input.hookEventName,
              let eventType = HookEventType(rawValue: eventName) else {
            return nil
        }

        return (eventType, input)
    }
}
