import Foundation
import StoreKit

class SubscriptionService: ObservableObject {
    // Product IDs - these would match what you set in App Store Connect
    static let basicMonthlyID = "com.VoiceLink.subscription.basic.monthly"
    static let proMonthlyID = "com.VoiceLink.subscription.pro.monthly"
    static let creditsPackID = "com.VoiceLink.credits.standard"
    
    // Amount of minutes in credit pack
    static let creditPackMinutes = 15.0
    
    @Published var products: [Product] = []
    @Published var isLoading = false
    @Published var error: String?
    
    init() {
        Task {
            await loadProducts()
        }
    }
    
    @MainActor
    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let productIDs = [
                SubscriptionService.basicMonthlyID,
                SubscriptionService.proMonthlyID,
                SubscriptionService.creditsPackID
            ]
            
            let allProducts = try await Product.products(for: productIDs)
            
            // Sort products: Basic first, Pro second, Pay-as-you-go last
            products = allProducts.sorted { product1, product2 in
                if product1.id == SubscriptionService.creditsPackID {
                    return false // Credits pack goes last
                } else if product2.id == SubscriptionService.creditsPackID {
                    return true // Other product goes before credits pack
                } else if product1.id == SubscriptionService.basicMonthlyID {
                    return true // Basic plan first
                } else {
                    return false // Pro plan second
                }
            }
        } catch {
            self.error = error.localizedDescription
            print("Failed to load products: \(error)")
        }
    }
    
    func purchase(_ product: Product, usageManager: UsageTimeManager) async throws -> Bool {
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                // Handle verification
                switch verification {
                case .verified(let transaction):
                    // Process the transaction
                    await handleTransaction(transaction, usageManager: usageManager)
                    await transaction.finish()
                    return true
                    
                case .unverified:
                    throw SKError(.unknown)
                }
                
            case .userCancelled:
                return false
                
            case .pending:
                return false
                
            @unknown default:
                return false
            }
        } catch {
            throw error
        }
    }
    
    @MainActor
    func handleTransaction(_ transaction: Transaction, usageManager: UsageTimeManager) async {
        // Process based on product type
        switch transaction.productID {
        case Self.basicMonthlyID:
            // Calculate expiry date (typically 1 month from now)
            let expiryDate = transaction.expirationDate ?? Calendar.current.date(byAdding: .month, value: 1, to: Date())!
            usageManager.updateSubscription(to: .basic, expiryDate: expiryDate)
            
        case Self.proMonthlyID:
            let expiryDate = transaction.expirationDate ?? Calendar.current.date(byAdding: .month, value: 1, to: Date())!
            usageManager.updateSubscription(to: .pro, expiryDate: expiryDate)
            
        case Self.creditsPackID:
            // Add credit minutes
            usageManager.addCreditMinutes(Self.creditPackMinutes)
            
        default:
            break
        }
    }
    
    @MainActor
    func restorePurchases(usageManager: UsageTimeManager) async -> Bool {
        do {
            // For StoreKit 2, this will check the user's purchase history
            // and restore any previously purchased non-consumable products and active subscriptions
            for await verificationResult in Transaction.currentEntitlements {
                // Process each transaction as if it were new
                if case .verified(let transaction) = verificationResult {
                    await handleTransaction(transaction, usageManager: usageManager)
                }
            }
            return true
        }
    }
}
