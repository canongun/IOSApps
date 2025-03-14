import Foundation

class TranslationService {
    private let apiKey = Configuration.anthropicAPIKey // Now safely referenced
    private let baseURL = "https://api.anthropic.com/v1/messages"
    
    func translateText(text: String, targetLanguage: String, completion: @escaping (Result<String, Error>) -> Void) {
        // Create URL request
        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let requestBody: [String: Any] = [
            "model": "claude-3-7-sonnet-20250219",
            "max_tokens": 1000,
            "messages": [
                [
                    "role": "user",
                    "content": "Translate the following text to \(targetLanguage). Just return the translation without any additional text or explanation: \(text)"
                ]
            ]
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            completion(.failure(error))
            return
        }
        
        // Create URLSession task
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "TranslationService", code: 0, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }
            
            // Debug: Print the raw JSON response
            if let jsonString = String(data: data, encoding: .utf8) {
                print("Raw API response: \(jsonString)")
            }
            
            do {
                // Parse the JSON response - updated to match Claude API structure
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    // Try different parsing approaches based on potential response structures
                    if let content = json["content"] as? [[String: Any]],
                       let firstContent = content.first,
                       let type = firstContent["type"] as? String,
                       type == "text",
                       let text = firstContent["text"] as? String {
                        completion(.success(text))
                    } else if let content = json["content"] as? [String],
                              let text = content.first {
                        completion(.success(text))
                    } else if let message = json["message"] as? String {
                        completion(.success(message))
                    } else {
                        completion(.failure(NSError(domain: "TranslationService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to parse response structure"])))
                    }
                } else {
                    completion(.failure(NSError(domain: "TranslationService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to parse JSON response"])))
                }
            } catch {
                completion(.failure(error))
            }
        }
        
        task.resume()
    }
}