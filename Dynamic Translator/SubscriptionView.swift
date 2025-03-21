import SwiftUI
import StoreKit
import SafariServices

struct SubscriptionView: View {
    @ObservedObject var usageManager: UsageTimeManager
    @ObservedObject var subscriptionService: SubscriptionService
    @Environment(\.dismiss) private var dismiss
    
    @State private var isPurchasing = false
    @State private var errorMessage: String?
    @State private var showingError = false
    @State private var isRestoring = false
    @State private var showRestoreSuccess = false
    
    // Add state for Safari view
    @State private var showingSafari = false
    @State private var safariURL: URL?
    
    // URLs for your legal documents - replace these with your actual URLs
    private let termsOfUseURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    private let privacyPolicyURL = URL(string: "https://gist.github.com/canongun/e979c8af78ae9d255cba16156af578fc")!
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Usage info
                    VStack(alignment: .center, spacing: 8) {
                        Text("Your Translation Time")
                            .font(.title3)
                            .fontWeight(.bold)
                        
                        Text(usageManager.formattedRemainingTime())
                            .font(.system(size: 42, weight: .bold))
                            .foregroundColor(.blue)
                        
                        Text("remaining")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        if let expiryDate = usageManager.subscriptionExpiryDate {
                            Text("Your \(usageManager.subscriptionTier.displayName) plan renews on \(expiryDate, style: .date)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                    // Add restore purchases button
                    Button(action: {
                        Task {
                            await restorePurchases()
                        }
                    }) {
                        HStack {
                            if isRestoring {
                                ProgressView()
                                    .padding(.trailing, 5)
                            }
                            Text(isRestoring ? "Restoring..." : "Restore Purchases")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(10)
                    }
                    .padding(.horizontal)
                    .disabled(isRestoring || isPurchasing)
                    
                    Divider()
                        .padding(.vertical)
                    
                    // Subscription options
                    Text("Choose Your Plan")
                        .font(.title3)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                    
                    if subscriptionService.isLoading {
                        ProgressView("Loading subscription options...")
                            .padding()
                    } else if subscriptionService.products.isEmpty {
                        Text("No subscription options available")
                            .foregroundColor(.secondary)
                            .padding()
                    } else {
                        // Subscription plans
                        VStack(spacing: 16) {
                            // Filter for subscription products
                            let subscriptionProducts = subscriptionService.products.filter { 
                                $0.id != SubscriptionService.creditsPackID 
                            }
                            
                            ForEach(subscriptionProducts, id: \.id) { product in
                                SubscriptionPlanCard(
                                    product: product,
                                    currentTier: usageManager.subscriptionTier,
                                    isPurchasing: isPurchasing,
                                    isPrimary: true
                                ) {
                                    await purchaseProduct(product)
                                }
                                .padding(.horizontal)
                            }
                            
                            // Divider between subscription and pay-as-you-go
                            if let creditProduct = subscriptionService.products.first(where: { 
                                $0.id == SubscriptionService.creditsPackID 
                            }) {
                                Divider()
                                    .padding(.vertical, 10)
                                
                                Text("One-time Purchase")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal)
                                    .padding(.top, 10)
                                
                                SubscriptionPlanCard(
                                    product: creditProduct,
                                    currentTier: usageManager.subscriptionTier,
                                    isPurchasing: isPurchasing,
                                    isPrimary: false
                                ) {
                                    await purchaseProduct(creditProduct)
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                    
                    // Add legal links at the bottom
                    HStack {
                        Button("Terms of Use") {
                            safariURL = termsOfUseURL
                            showingSafari = true
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                        
                        Spacer()
                        
                        Button("Privacy Policy") {
                            safariURL = privacyPolicyURL
                            showingSafari = true
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    }
                    .padding(.horizontal)
                    .padding(.top, 10)
                }
                .padding(.vertical)
            }
            .navigationTitle("Subscription Plans")
            .navigationBarItems(trailing: Button("Close") {
                dismiss()
            })
            .alert("Purchase Error", isPresented: $showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "An unknown error occurred")
            }
            .alert("Purchases Restored", isPresented: $showRestoreSuccess) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Your previous purchases have been restored successfully.")
            }
            .sheet(isPresented: $showingSafari) {
                if let url = safariURL {
                    SafariView(url: url)
                }
            }
            .onAppear {
                // Refresh products when view appears
                Task {
                    await subscriptionService.loadProducts()
                }
            }
        }
    }
    
    private func purchaseProduct(_ product: Product) async {
        isPurchasing = true
        defer { isPurchasing = false }
        
        do {
            let success = try await subscriptionService.purchase(product, usageManager: usageManager)
            if !success {
                errorMessage = "Purchase was cancelled or is pending."
                showingError = true
            }
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
    
    private func restorePurchases() async {
        isRestoring = true
        defer { isRestoring = false }
        
        do {
            let success = await subscriptionService.restorePurchases(usageManager: usageManager)
            if success {
                showRestoreSuccess = true
            } else {
                errorMessage = "No purchases to restore or an error occurred."
                showingError = true
            }
        }
    }
}

struct SubscriptionPlanCard: View {
    let product: Product
    let currentTier: SubscriptionTier
    let isPurchasing: Bool
    let isPrimary: Bool
    let purchase: () async -> Void
    
    var isCurrentSubscription: Bool {
        if product.id.contains("basic") && currentTier == .basic {
            return true
        } else if product.id.contains("pro") && currentTier == .pro {
            return true
        }
        return false
    }
    
    var planMinutes: String {
        if product.id.contains("basic") {
            return "20 minutes"
        } else if product.id.contains("pro") {
            return "45 minutes"
        } else if product.id.contains("credits") {
            return "15 minutes"
        }
        return "Unknown"
    }
    
    var planType: String {
        if product.id.contains("credits") {
            return "One-time Purchase"
        } else {
            return "Monthly Subscription"
        }
    }
    
    var marketingDescription: String {
        if product.id.contains("basic") {
            return "Perfect for casual users. Great for travel and occasional translations."
        } else if product.id.contains("pro") {
            return "Best for frequent users. Ideal for students, and travelers who need more translation time."
        } else if product.id.contains("credits") {
            return "Need a quick boost? Purchase translation minutes without a subscription."
        }
        return product.description
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(product.displayName)
                    .font(.headline)
                
                Spacer()
                
                if isCurrentSubscription {
                    Text("Current Plan")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(4)
                }
            }
            
            Text(planMinutes)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.blue)
            
            // Explicitly show the subscription period/length
            if !product.id.contains("credits") {
                Text("Subscription Period: Monthly")
                    .font(.subheadline)
                    .foregroundColor(.primary)
            }
            
            Text(marketingDescription)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            
            Text(planType)
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack {
                Text(product.displayPrice)
                    .font(.headline)
                
                if !product.id.contains("credits") {
                    Text("per month")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: {
                    Task {
                        await purchase()
                    }
                }) {
                    Text(buttonLabel)
                        .fontWeight(.medium)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(buttonColor)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .disabled(isCurrentSubscription || isPurchasing)
            }
        }
        .padding()
        .background(
            isPrimary ? 
                (Color.blue.opacity(0.08)) : 
                (Color.gray.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isPrimary ? Color.blue.opacity(0.2) : Color.clear, lineWidth: 1)
        )
        .cornerRadius(12)
    }
    
    private var buttonLabel: String {
        if isPurchasing {
            return "Processing..."
        }
        if isCurrentSubscription {
            return "Current Plan"
        }
        if product.id.contains("credits") {
            return "Buy Credits"
        }
        return "Subscribe"
    }
    
    private var buttonColor: Color {
        if isCurrentSubscription {
            return .green
        }
        if isPurchasing {
            return .gray
        }
        return .blue
    }
}

// Add a Safari view wrapper for showing web content
struct SafariView: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: UIViewControllerRepresentableContext<SafariView>) -> SFSafariViewController {
        return SFSafariViewController(url: url)
    }
    
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: UIViewControllerRepresentableContext<SafariView>) {
        // No updates needed
    }
}
