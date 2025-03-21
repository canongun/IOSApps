import Foundation
import AVFoundation

class ElevenLabsService: NSObject, AVAudioPlayerDelegate {
    private let apiKey = Configuration.elevenLabsAPIKey // Safely referenced
    private let baseURL = "https://api.elevenlabs.io/v1/text-to-speech"
    private var defaultVoiceID = "21m00Tcm4TlvDq8ikWAM" // Default voice ID (Rachel - English)
    
    // Add a completion handler for audio playback
    var onPlaybackCompleted: (() -> Void)?
    
    // Voice ID mapping for different languages
    static let voiceIDMap: [String: String] = [
        "Bulgarian": "fSxb5mPM1l5zTVVtM3Vb",
        "Chinese": "hkfHEbBvdQFNX4uWHqRF",
        "Czech": "OAAjJsQDvpg3sVjiLgyl",
        "Danish": "ZKutKtutnlbOxDxkNlhk",
        "Dutch": "YUdpWWny7k5yb4QCeweX",
        "English": "21m00Tcm4TlvDq8ikWAM",
        "Finnish": "YSabzCJMvEHDduIDMdwV",
        "French": "O31r762Gb3WFygrEOGh0",
        "German": "dCnu06FiOZma2KVNUoPZ",
        "Greek": "XZ8zM3TBDcQnbvfD1YDK",
        "Hindi": "Sm1seazb4gs7RSlUVw7c",
        "Indonesian": "LcvlyuBGMjj1h4uAtQjo",
        "Italian": "3DPhHWXDY263XJ1d2EPN",
        "Japanese": "8EkOjt4xTPGMclNlh1pk",
        "Korean": "uyVNoMrnUku1dZyVEXwD",
        "Malay": "UcqZLa941Kkt8ZhEEybf",
        "Norwegian": "uNsWM1StCcpydKYOjKyu",
        "Polish": "Pid5DJleNF2sxsuF6YKD",
        "Portuguese": "eVXYtPVYB9wDoz9NVTIy",
        "Romanian": "urzoE6aZYmSRdFQ6215h",
        "Russian": "AB9XsbSA4eLG12t2myjN",
        "Slovak": "3K1lqsxxXFiTAXCO09Zv",
        "Spanish": "x5IDPSl4ZUbhosMmVFTk",
        "Swedish": "4xkUqaR9MYOJHoaC1Nak",
        "Turkish": "KbaseEXyT9EE0CQLEfbB",
        "Ukrainian": "nCqaTnIbLdME87OuQaZY",
        "Vietnamese": "foH7s9fX31wFFH2yqrFa"
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
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default)
            try audioSession.setActive(true)
            
            // Clean up previous player if it exists
            if audioPlayer != nil {
                audioPlayer?.stop()
                audioPlayer = nil
            }
            
            // Create and play audio
            audioPlayer = try AVAudioPlayer(data: data)
            
            if audioPlayer == nil {
                print("Failed to create audio player")
                
                // If there's an error, still call the completion handler
                DispatchQueue.main.async {
                    self.onPlaybackCompleted?()
                }
                return
            }
            
            audioPlayer!.delegate = self  // Set the delegate to receive completion notifications
            
            if !audioPlayer!.prepareToPlay() {
                print("Failed to prepare audio for playback")
                
                // If there's an error, still call the completion handler
                DispatchQueue.main.async {
                    self.onPlaybackCompleted?()
                }
                return
            }
            
            let success = audioPlayer!.play()
            if !success {
                print("Failed to start audio playback")
                
                // If there's an error, still call the completion handler
                DispatchQueue.main.async {
                    self.onPlaybackCompleted?()
                }
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
            
            // If there's an error, still call the completion handler
            DispatchQueue.main.async {
                self.onPlaybackCompleted?()
            }
        }
    }
    
    // AVAudioPlayerDelegate method - called when audio finishes playing
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        print("Audio playback finished, success: \(flag)")
        
        // Notify that playback is complete
        DispatchQueue.main.async {
            self.onPlaybackCompleted?()
        }
    }
}