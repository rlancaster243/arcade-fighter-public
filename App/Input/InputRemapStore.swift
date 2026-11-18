import AppLogic
import Foundation

enum InputRemapStore {
    private static let userDefaultsKey = "arcadeFighter.inputRemap.v1"

    static func load() -> InputRemapSettings {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else {
            return InputRemapSettings()
        }
        do {
            let decoded = try JSONDecoder().decode(InputRemapSettings.self, from: data)
            guard decoded.schemaVersion == InputRemapSettings.schemaVersion else {
                return InputRemapSettings()
            }
            return decoded
        } catch {
            return InputRemapSettings()
        }
    }

    static func save(_ settings: InputRemapSettings) {
        do {
            let data = try JSONEncoder().encode(settings)
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        } catch {
            // Offline game: ignore persistence failures.
        }
    }
}