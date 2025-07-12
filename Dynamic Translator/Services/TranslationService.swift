import Foundation

class TranslationService {
    private let apiKey = Configuration.anthropicAPIKey // Now safely referenced
    private let baseURL = "https://api.anthropic.com/v1/messages"
    
    func translateText(text: String, targetLanguage: String, completion: @escaping (Result<String, Error>) -> Void) {
        // Create URL request
        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        
        let requestBody: [String: Any] = [
            "model": "claude-3-5-haiku-20241022",
            "max_tokens": 1024,
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
            
            // Debug: Print HTTP response status code
            if let httpResponse = response as? HTTPURLResponse {
                print("HTTP response status: \(httpResponse.statusCode)")
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
                    // Check if it's an error response
                    if let errorObj = json["error"] as? [String: Any],
                       let errorMessage = errorObj["message"] as? String {
                        let errorType = errorObj["type"] as? String ?? "unknown"
                        completion(.failure(NSError(domain: "AnthropicAPI", 
                                                  code: 2, 
                                                  userInfo: [NSLocalizedDescriptionKey: "API Error (\(errorType)): \(errorMessage)"])))
                        return
                    }
                    
                    // Try to extract content based on Anthropic's response format
                    if let content = json["content"] as? [[String: Any]],
                       let firstContent = content.first,
                       let type = firstContent["type"] as? String,
                       type == "text",
                       let text = firstContent["text"] as? String {
                        completion(.success(text))
                    } else {
                        print("Full response structure: \(json)")
                        completion(.failure(NSError(domain: "TranslationService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not extract translation from response"])))
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