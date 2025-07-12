import Foundation

struct Configuration {

    // Helper function to read a value from the app's Info.plist
    private static func value<T>(for key: String) throws -> T where T: LosslessStringConvertible {
        guard let object = Bundle.main.object(forInfoDictionaryKey: key) else {
            throw fatalError("\(key) not set in Info.plist")
        }

        switch object {
        case let value as T:
            return value
        case let string as String:
            guard let value = T(string) else { fallthrough }
            return value
        default:
            throw fatalError("Invalid value for \(key) in Info.plist")
        }
    }

    // MARK: - API Keys
    static let deepgramAPIKey: String = {
        return try! value(for: "DEEPGRAM_API_KEY")
    }()

    static let anthropicAPIKey: String = {
        return try! value(for: "ANTHROPIC_API_KEY")
    }()

    static let elevenLabsAPIKey: String = {
        return try! value(for: "ELEVENLABS_API_KEY")
    }()
}
