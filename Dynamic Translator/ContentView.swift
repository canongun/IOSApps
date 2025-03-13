//
//  ContentView.swift
//  Dynamic Translator
//
//  Created by can on 13.03.25.
//

import SwiftUI

struct ContentView: View {
    @State private var isTranslating = false
    @State private var targetLanguage = "English"
    @State private var availableLanguages = ["English"]
    
    var body: some View {
        VStack {
            Spacer()
            
            // Main translation button
            Button(action: {
                isTranslating.toggle()
            }) {
                Circle()
                    .fill(isTranslating ? Color.red : Color.blue)
                    .frame(width: 200, height: 200)
                    .overlay(
                        Image(systemName: isTranslating ? "mic.fill" : "mic")
                            .font(.system(size: 80))
                            .foregroundColor(.white)
                    )
            }
            .padding(.bottom, 50)
            
            Spacer()
            
            // Language selection dropdown
            Menu {
                ForEach(availableLanguages, id: \.self) { language in
                    Button(language) {
                        targetLanguage = language
                    }
                }
            } label: {
                HStack {
                    Text("Translate to: \(targetLanguage)")
                        .font(.headline)
                    Image(systemName: "chevron.down")
                }
                .padding()
                .background(Color.gray.opacity(0.2))
                .cornerRadius(10)
            }
            .padding(.bottom, 50)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
