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
            
            products = try await Product.products(for: productIDs)
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
    private func handleTransaction(_ transaction: Transaction, usageManager: UsageTimeManager) async {
        // Process based on product type
        switch transaction.productID {
        case SubscriptionService.basicMonthlyID:
            // Calculate expiry date (typically 1 month from now)
            let expiryDate = transaction.expirationDate ?? Calendar.current.date(byAdding: .month, value: 1, to: Date())!
            usageManager.updateSubscription(to: .basic, expiryDate: expiryDate)
            
        case SubscriptionService.proMonthlyID:
            let expiryDate = transaction.expirationDate ?? Calendar.current.date(byAdding: .month, value: 1, to: Date())!
            usageManager.updateSubscription(to: .pro, expiryDate: expiryDate)
            
        case SubscriptionService.creditsPackID:
            // Add credit minutes
            usageManager.addCreditMinutes(SubscriptionService.creditPackMinutes)
            
        default:
            break
        }
    }
}
