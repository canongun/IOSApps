import Foundation

struct Configuration {
    // MARK: - API Keys
    static let deepgramAPIKey: String = {
        if let envKey = ProcessInfo.processInfo.environment["DEEPGRAM_API_KEY"] {
            return envKey
        }
        // Fallback for development/testing - remove in production
        fatalError("DEEPGRAM_API_KEY environment variable not set")
    }()
    
    static let anthropicAPIKey: String = {
        if let envKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] {
            return envKey
        }
        // Fallback for development/testing - remove in production
        fatalError("ANTHROPIC_API_KEY environment variable not set")
    }()
    
    static let elevenLabsAPIKey: String = {
        if let envKey = ProcessInfo.processInfo.environment["ELEVENLABS_API_KEY"] {
            return envKey
        }
        // Fallback for development/testing - remove in production
        fatalError("ELEVENLABS_API_KEY environment variable not set")
    }()
}