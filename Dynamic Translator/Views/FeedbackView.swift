import SwiftUI

struct FeedbackView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var feedbackText = ""
    @State private var isSubmitting = false
    @State private var showingSuccessAlert = false
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    
    // Replace with your Formspree form ID after creating it at formspree.io
    private let formspreeEndpoint = "https://formspree.io/f/movewlzp"
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("How can we improve our app?")) {
                    TextEditor(text: $feedbackText)
                        .frame(minHeight: 150)
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                }
                
                Section {
                    Button(action: submitFeedback) {
                        if isSubmitting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        } else {
                            Text("Submit Feedback")
                                .frame(maxWidth: .infinity)
                                .foregroundColor(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
                    .buttonStyle(PlainButtonStyle())
                    .disabled(feedbackText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting)
                }
                .listRowBackground(Color.clear)
            }
            .navigationTitle("App Feedback")
            .navigationBarItems(trailing: Button("Cancel") {
                dismiss()
            })
            .alert("Thank You!", isPresented: $showingSuccessAlert) {
                Button("OK", role: .cancel) {
                    dismiss()
                }
            } message: {
                Text("Your feedback has been submitted successfully. We appreciate your input!")
            }
            .alert("Error", isPresented: $showingErrorAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func submitFeedback() {
        guard !feedbackText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        isSubmitting = true
        
        // Create the request
        guard let url = URL(string: formspreeEndpoint) else {
            errorMessage = "Invalid form endpoint"
            showingErrorAlert = true
            isSubmitting = false
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Include useful metadata with the feedback
        let feedback: [String: Any] = [
            "message": feedbackText,
            "device": UIDevice.current.model,
            "systemVersion": UIDevice.current.systemVersion,
            "appVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: feedback)
        } catch {
            errorMessage = "Failed to prepare feedback data"
            showingErrorAlert = true
            isSubmitting = false
            return
        }
        
        // Send the request
        URLSession.shared.dataTask(with: request) { _, response, error in
            DispatchQueue.main.async {
                isSubmitting = false
                
                if let error = error {
                    errorMessage = "Failed to submit feedback: \(error.localizedDescription)"
                    showingErrorAlert = true
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse, 
                      (200...299).contains(httpResponse.statusCode) else {
                    errorMessage = "Server returned an error"
                    showingErrorAlert = true
                    return
                }
                
                showingSuccessAlert = true
            }
        }.resume()
    }
}

struct FeedbackView_Previews: PreviewProvider {
    static var previews: some View {
        FeedbackView()
    }
}
