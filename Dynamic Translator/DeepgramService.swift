import Foundation

// Add a struct to hold transcription metadata
struct TranscriptionMetadata {
    let detectedLanguage: String?
    let confidence: Double?
}

// Add a struct to hold transcription result with metadata
struct TranscriptionResult {
    let text: String
    let metadata: TranscriptionMetadata?
}

class DeepgramService {
    private let apiKey = Configuration.deepgramAPIKey // Now safely referenced
    private let baseURL = "https://api.deepgram.com/v1/listen"
    
    func transcribeAudio(audioData: Data, completion: @escaping (Result<TranscriptionResult, Error>) -> Void) {
        // Create URL with query parameters for language detection
        let urlString = "\(baseURL)?model=nova-2&detect_language=true"
        
        // Create URL request
        var request = URLRequest(url: URL(string: urlString)!)
        request.httpMethod = "POST"
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        request.setValue("Token \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = audioData
        
        // Create URLSession task
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            // Print HTTP response status code for debugging
            if let httpResponse = response as? HTTPURLResponse {
                print("Deepgram API HTTP response status: \(httpResponse.statusCode)")
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "DeepgramService", code: 0, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }
            
            // Debug: Print raw response
            if let jsonString = String(data: data, encoding: .utf8) {
                print("Deepgram raw response: \(jsonString)")
            }
            
            do {
                // Parse the JSON response
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let results = json["results"] as? [String: Any],
                   let channels = results["channels"] as? [[String: Any]],
                   let alternatives = channels[0]["alternatives"] as? [[String: Any]],
                   let transcript = alternatives[0]["transcript"] as? String {
                    
                    // Extract metadata
                    var metadata: TranscriptionMetadata? = nil
                    
                    // Check if language was detected
                    if let detectedLanguage = channels[0]["detected_language"] as? String,
                       let languageConfidence = channels[0]["language_confidence"] as? Double {
                        metadata = TranscriptionMetadata(
                            detectedLanguage: detectedLanguage,
                            confidence: languageConfidence
                        )
                        print("Detected language: \(detectedLanguage) (confidence: \(languageConfidence))")
                    }
                    
                    let result = TranscriptionResult(text: transcript, metadata: metadata)
                    completion(.success(result))
                } else {
                    completion(.failure(NSError(domain: "DeepgramService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to parse response"])))
                }
            } catch {
                completion(.failure(error))
            }
        }
        
        task.resume()
    }
}