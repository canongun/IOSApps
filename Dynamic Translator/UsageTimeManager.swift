import Foundation
import Combine

// Define subscription tiers
enum SubscriptionTier: String, Codable {
    case free
    case basic
    case pro
    
    var minutesAllowance: Double {
        switch self {
        case .free:
            return 5.0  // 5 minutes free
        case .basic:
            return 20.0  // 20 minutes for basic tier
        case .pro:
            return 45.0  // 45 minutes for pro tier
        }
    }
    
    var displayName: String {
        switch self {
        case .free:
            return "Free"
        case .basic:
            return "Basic"
        case .pro:
            return "Pro"
        }
    }
}

class UsageTimeManager: ObservableObject {
    // Published properties for UI updates
    @Published var remainingMinutes: Double
    @Published var subscriptionTier: SubscriptionTier
    @Published var subscriptionExpiryDate: Date?
    @Published var additionalCreditMinutes: Double
    
    // Private properties for tracking
    private var translationStartTime: Date?
    private var isCurrentlyTranslating = false
    private let userDefaults = UserDefaults.standard
    
    // UserDefaults keys
    private let remainingMinutesKey = "remainingMinutes"
    private let tierKey = "subscriptionTier"
    private let expiryDateKey = "subscriptionExpiryDate"
    private let creditMinutesKey = "additionalCreditMinutes"
    private let lastResetDateKey = "lastResetDate"
    
    init() {
        // Load saved values or set defaults
        subscriptionTier = SubscriptionTier(rawValue: userDefaults.string(forKey: tierKey) ?? "") ?? .free
        remainingMinutes = userDefaults.double(forKey: remainingMinutesKey)
        additionalCreditMinutes = userDefaults.double(forKey: creditMinutesKey)
        
        // Initialize with free minutes if first time or no remaining minutes
        if remainingMinutes <= 0 {
            remainingMinutes = subscriptionTier.minutesAllowance
            saveUsage()
        }
        
        // Check for expiry date
        if let expiryDate = userDefaults.object(forKey: expiryDateKey) as? Date {
            subscriptionExpiryDate = expiryDate
            
            // Check if subscription has expired
            if Date() > expiryDate {
                // Keep the tier but mark as expired by setting nil expiry date
                // We don't reset to free tier immediately to allow for renewal
                subscriptionExpiryDate = nil
                saveUsage()
            }
        }
        
        // Check if we need to reset monthly allowance
        checkForMonthlyReset()
    }
    
    // Begin tracking translation time
    func startTranslation() -> Bool {
        // Check if user can make a translation
        if canMakeTranslation() {
            translationStartTime = Date()
            isCurrentlyTranslating = true
            return true
        }
        return false
    }
    
    // End tracking and calculate used time
    func stopTranslation() -> TimeInterval? {
        guard isCurrentlyTranslating, let startTime = translationStartTime else {
            return nil
        }
        
        isCurrentlyTranslating = false
        let endTime = Date()
        let timeUsed = endTime.timeIntervalSince(startTime) / 60.0 // Convert to minutes
        
        // Only subtract time if translation was successful
        // This will be called after successful processing
        return timeUsed
    }
    
    // Confirm usage of time (call after successful translation)
    func confirmUsage(minutes: Double) {
        // First use additional credits if available
        let minutesToDeduct = min(minutes, max(0, remainingMinutes))
        remainingMinutes -= minutesToDeduct
        
        // Use credits for any remaining time
        if minutes > minutesToDeduct && additionalCreditMinutes > 0 {
            let creditMinutesToUse = min(minutes - minutesToDeduct, additionalCreditMinutes)
            additionalCreditMinutes -= creditMinutesToUse
        }
        
        saveUsage()
    }
    
    // Check if user can make a translation
    func canMakeTranslation() -> Bool {
        // User can translate if they have remaining minutes or credits
        return remainingMinutes > 0 || additionalCreditMinutes > 0
    }
    
    // Update subscription tier
    func updateSubscription(to tier: SubscriptionTier, expiryDate: Date) {
        let oldTier = subscriptionTier
        subscriptionTier = tier
        subscriptionExpiryDate = expiryDate
        
        // If upgrading, add additional minutes
        if oldTier != tier {
            // Reset to full allowance for the new tier
            remainingMinutes = tier.minutesAllowance
        }
        
        saveUsage()
    }
    
    // Add credit minutes from purchase
    func addCreditMinutes(_ minutes: Double) {
        additionalCreditMinutes += minutes
        saveUsage()
    }
    
    // Get total available minutes (subscription + credits)
    func totalAvailableMinutes() -> Double {
        return remainingMinutes + additionalCreditMinutes
    }
    
    // Format minutes for display
    func formattedRemainingTime() -> String {
        let total = totalAvailableMinutes()
        let minutes = Int(total)
        let seconds = Int((total - Double(minutes)) * 60)
        
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }
    
    // Save usage data to UserDefaults
    private func saveUsage() {
        userDefaults.set(remainingMinutes, forKey: remainingMinutesKey)
        userDefaults.set(subscriptionTier.rawValue, forKey: tierKey)
        userDefaults.set(additionalCreditMinutes, forKey: creditMinutesKey)
        
        if let expiryDate = subscriptionExpiryDate {
            userDefaults.set(expiryDate, forKey: expiryDateKey)
        } else {
            userDefaults.removeObject(forKey: expiryDateKey)
        }
    }
    
    // Check if we need to reset monthly allowance
    private func checkForMonthlyReset() {
        guard subscriptionTier != .free, let expiryDate = subscriptionExpiryDate else {
            return
        }
        
        let lastResetDate = userDefaults.object(forKey: lastResetDateKey) as? Date ?? Date.distantPast
        let calendar = Calendar.current
        
        // If it's been a month since last reset and subscription is active
        if calendar.dateComponents([.month], from: lastResetDate, to: Date()).month ?? 0 >= 1 {
            // Reset the monthly allowance
            remainingMinutes = subscriptionTier.minutesAllowance
            userDefaults.set(Date(), forKey: lastResetDateKey)
            saveUsage()
        }
    }
    
    // Check subscription status and refresh if needed
    func checkSubscriptionStatus() {
        // This would integrate with StoreKit to verify subscription status
        // For now, just check if past expiry date
        if let expiryDate = subscriptionExpiryDate, Date() > expiryDate {
            // Subscription expired, revert to free tier
            subscriptionTier = .free
            subscriptionExpiryDate = nil
            remainingMinutes = SubscriptionTier.free.minutesAllowance
            saveUsage()
        }
    }
}