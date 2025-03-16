//
//  Dynamic_TranslatorApp.swift
//  Dynamic Translator
//
//  Created by can on 13.03.25.
//

import SwiftUI

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
            for await result in Transaction.updates {
                do {
                    let transaction = try result.get()
                    
                    // Handle verified transaction
                    if let usageManager = usageManager {
                        await subscriptionService.handleTransaction(transaction, usageManager: usageManager)
                    }
                    
                    // Always finish the transaction when you're done
                    await transaction.finish()
                } catch {
                    print("Error handling transaction: \(error)")
                }
            }
        }
    }
}
