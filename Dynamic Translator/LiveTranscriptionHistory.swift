import Foundation

// A model for storing a single live transcription entry
struct LiveTranscriptionEntry: Identifiable, Codable {
    let id: UUID
    let originalText: String
    let translatedText: String
    let sourceLanguage: String
    let targetLanguage: String
    let timestamp: Date
    
    init(id: UUID = UUID(), originalText: String, translatedText: String, sourceLanguage: String, targetLanguage: String, timestamp: Date = Date()) {
        self.id = id
        self.originalText = originalText
        self.translatedText = translatedText
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.timestamp = timestamp
    }
}

// A class to manage live transcription history
class LiveTranscriptionHistory: ObservableObject {
    @Published var entries: [LiveTranscriptionEntry] = []
    
    private let saveKey = "liveTranscriptionHistory"
    private let userDefaults = UserDefaults.standard
    
    init() {
        loadHistory()
    }
    
    func addEntry(originalText: String, translatedText: String, sourceLanguage: String, targetLanguage: String) {
        let newEntry = LiveTranscriptionEntry(
            originalText: originalText,
            translatedText: translatedText,
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage
        )
        
        DispatchQueue.main.async {
            self.entries.insert(newEntry, at: 0) // Add newest entries at the top
            self.saveHistory()
        }
    }
    
    func clearHistory() {
        DispatchQueue.main.async {
            self.entries.removeAll()
            self.saveHistory()
        }
    }
    
    private func saveHistory() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(entries)
            userDefaults.set(data, forKey: saveKey)
        } catch {
            print("Failed to save live transcription history: \(error.localizedDescription)")
        }
    }
    
    private func loadHistory() {
        if let data = userDefaults.data(forKey: saveKey) {
            do {
                let decoder = JSONDecoder()
                entries = try decoder.decode([LiveTranscriptionEntry].self, from: data)
            } catch {
                print("Failed to load live transcription history: \(error.localizedDescription)")
            }
        }
    }
}