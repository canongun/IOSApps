//
//  Dynamic_TranslatorApp.swift
//  Dynamic Translator
//
//  Created by can on 13.03.25.
//

import SwiftUI
import StoreKit

@main
struct Dynamic_TranslatorApp: App {
    @StateObject private var usageManager = UsageTimeManager()
    @StateObject private var subscriptionService = SubscriptionService()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(usageManager)
                .environmentObject(subscriptionService)
        }
    }
    
    init() {
        // Set up StoreKit transaction listener
        listenForTransactions()
    }
    
    func listenForTransactions() {
        // Start a task to listen for transactions
        Task {
            for await verificationResult in Transaction.updates {
                // Handle the transaction based on its verification status
                switch verificationResult {
                case .verified(let transaction):
                    // This is a verified transaction
                    print("Received verified transaction: \(transaction.productID)")
                    
                    // Process the transaction with our subscription service
                    await subscriptionService.handleTransaction(transaction, usageManager: usageManager)
                    
                    // Always finish the transaction when you're done with it
                    await transaction.finish()
                    
                case .unverified(let transaction, let verificationError):
                    // This transaction failed verification
                    print("Received unverified transaction: \(transaction.productID)")
                    print("Verification error: \(verificationError)")
                    
                    // Still finish the transaction even if unverified
                    await transaction.finish()
                }
            }
        }
    }
}
