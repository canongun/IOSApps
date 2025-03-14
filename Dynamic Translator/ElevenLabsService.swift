import Foundation
import AVFoundation

class ElevenLabsService {
    private let apiKey = Configuration.elevenLabsAPIKey // Safely referenced
    private let baseURL = "https://api.elevenlabs.io/v1/text-to-speech"
    private var defaultVoiceID = "21m00Tcm4TlvDq8ikWAM" // Default voice ID (Rachel - English)
    
    // Voice ID mapping for different languages
    static let voiceIDMap: [String: String] = [
        "English": "21m00Tcm4TlvDq8ikWAM", // Rachel
        "Spanish": "x5IDPSl4ZUbhosMmVFTk",
        "French": "O31r762Gb3WFygrEOGh0",
        "German": "dCnu06FiOZma2KVNUoPZ",
        "Italian": "3DPhHWXDY263XJ1d2EPN",
        "Turkish": "KbaseEXyT9EE0CQLEfbB"
    ]
    
    private var audioPlayer: AVAudioPlayer?
    
    func synthesizeSpeech(text: String, language: String = "English", completion: @escaping (Result<Data, Error>) -> Void) {
        // Get the appropriate voice ID for the language
        let voiceID = ElevenLabsService.voiceIDMap[language] ?? defaultVoiceID
        
        print("Using voice ID for \(language): \(voiceID)")
        
        // Create URL with voice ID
        guard let url = URL(string: "\(baseURL)/\(voiceID)") else {
            completion(.failure(NSError(domain: "ElevenLabsService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        
        // Create URL request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "xi-api-key")
        
        // For non-English languages, use multilingual model
        let modelID = language == "English" ? "eleven_monolingual_v1" : "eleven_multilingual_v2"
        
        let requestBody: [String: Any] = [
            "text": text,
            "model_id": modelID,
            "voice_settings": [
                "stability": 0.5,
                "similarity_boost": 0.5
            ]
        ]
        
        // Log request details
        print("ElevenLabs request to: \(url.absoluteString)")
        print("Using model: \(modelID)")
        print("Text to synthesize: \(text)")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            completion(.failure(error))
            return
        }
        
        // Create URLSession task
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("ElevenLabs network error: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            // Log HTTP response status
            if let httpResponse = response as? HTTPURLResponse {
                print("ElevenLabs HTTP response status: \(httpResponse.statusCode)")
                
                // If we got an error status code
                if httpResponse.statusCode >= 400 {
                    if let data = data, let errorMessage = String(data: data, encoding: .utf8) {
                        print("ElevenLabs error response: \(errorMessage)")
                        completion(.failure(NSError(domain: "ElevenLabsService", 
                                                 code: httpResponse.statusCode, 
                                                 userInfo: [NSLocalizedDescriptionKey: "API Error: \(errorMessage)"])))
                        return
                    }
                }
            }
            
            guard let data = data else {
                print("ElevenLabs error: No data received")
                completion(.failure(NSError(domain: "ElevenLabsService", code: 0, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }
            
            // Check if data seems valid (audio data is typically not tiny)
            print("Received audio data size: \(data.count) bytes")
            if data.count < 100 {
                // If it's a small amount of data, it might be an error message rather than audio
                if let errorText = String(data: data, encoding: .utf8) {
                    print("ElevenLabs possibly returned an error: \(errorText)")
                    completion(.failure(NSError(domain: "ElevenLabsService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid audio data: \(errorText)"])))
                    return
                }
            }
            
            completion(.success(data))
        }
        
        task.resume()
    }
    
    func playAudio(data: Data) {
        do {
            // Print audio data details to help diagnose issues
            print("Attempting to play audio data of size: \(data.count) bytes")
            
            // Configure audio session for playback
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            
            // Create and play audio
            audioPlayer = try AVAudioPlayer(data: data)
            
            if audioPlayer == nil {
                print("Failed to create audio player")
                return
            }
            
            if !audioPlayer!.prepareToPlay() {
                print("Failed to prepare audio for playback")
                return
            }
            
            let success = audioPlayer!.play()
            if !success {
                print("Failed to start audio playback")
            } else {
                print("Audio playback started successfully")
            }
        } catch {
            print("Failed to play audio: \(error.localizedDescription)")
            // Print more detailed error information if available
            if let nsError = error as NSError? {
                print("Error domain: \(nsError.domain), code: \(nsError.code), description: \(nsError.localizedDescription)")
                if let underlyingError = nsError.userInfo[NSUnderlyingErrorKey] as? NSError {
                    print("Underlying error: \(underlyingError)")
                }
            }
        }
    }
}