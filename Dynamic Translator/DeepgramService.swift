import Foundation

class DeepgramService {
    private let apiKey = Configuration.deepgramAPIKey // Now safely referenced
    private let baseURL = "https://api.deepgram.com/v1/listen"
    
    func transcribeAudio(audioData: Data, completion: @escaping (Result<String, Error>) -> Void) {
        // Create URL request
        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        request.setValue("Token \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("nova-3", forHTTPHeaderField: "model")
        request.httpBody = audioData
        
        // Create URLSession task
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "DeepgramService", code: 0, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }
            
            do {
                // Parse the JSON response
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let results = json["results"] as? [String: Any],
                   let channels = results["channels"] as? [[String: Any]],
                   let alternatives = channels[0]["alternatives"] as? [[String: Any]],
                   let transcript = alternatives[0]["transcript"] as? String {
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