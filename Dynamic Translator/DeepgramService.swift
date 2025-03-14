import Foundation

class DeepgramService {
    private let apiKey = Configuration.deepgramAPIKey // Now safely referenced
    private let baseURL = "https://api.deepgram.com/v1/listen"
    
    func transcribeAudio(audioData: Data, completion: @escaping (Result<String, Error>) -> Void) {
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
                    
                    // Check if language was detected
                    if let metadata = results["metadata"] as? [String: Any],
                       let detected_language = metadata["detected_language"] as? String {
                        print("Detected language: \(detected_language)")
                    }
                    
                    completion(.success(transcript))
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