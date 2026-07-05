import SwiftUI

struct SalesAssociateDashboard {
    let associate: AssociateProfile
    let monthlyGoal: SalesGoal
    let priorityItems: [PriorityItem]
    let quickActions: [QuickAction]
    let metrics: [DashboardMetric]
    let weeklySales: WeeklySalesSummary
}

struct AssociateProfile {
    let id: String
    let initials: String
    let name: String
    let role: String
    let boutique: String
    let email: String
    let phone: String
    let employeeID: String
    let shift: String
}

struct SalesGoal {
    let title: String
    let progress: Double
    let achieved: String
    let target: String

    var percentageText: String {
        "\(Int(progress * 100))%"
    }

    var detailText: String {
        "\(achieved) achieved from \(target) target"
    }
}

struct PriorityItem: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let subtitle: String
    let badge: String?
}

struct QuickAction: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let isPrimary: Bool
}

struct DashboardMetric: Identifiable {
    let id = UUID()
    let title: String
    let value: String
}

struct WeeklySalesSummary {
    let total: String
    let change: String
    let comparison: String
    let bestDay: String
    let bestDayLabel: String
    let days: [DailySales]
}

struct DailySales: Identifiable {
    let id = UUID()
    let day: String
    let amount: String
    let progress: Double
    let isBest: Bool
}

enum ClientTier {
    static func rewardPoints(for lifetimePurchaseAmount: Int) -> Int {
        max(0, lifetimePurchaseAmount) / 1_000
    }

    static func displayName(for rewardPoints: Int) -> String {
        switch rewardPoints {
//        case 50_000...:
//            return "Platinum Tier"
//        case 20_000...49_999:
//            return "Diamond Tier"
        case 5_000...:
            return "Platinum Tier"
        case 1_000...4_999:
            return "Diamond Tier"
        default:
            return "Gold Tier"
        }
    }

    static func minimumLifetimeAmount(for tierName: String?) -> Int {
        let normalizedTier = tierName?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""

//        if normalizedTier.contains("platinum") {
//            return 50_000_000
//        }
//
//        if normalizedTier.contains("diamond") {
//            return 20_000_000
//        }

        if normalizedTier.contains("platinum") {
            return 5_000_000
        }

        if normalizedTier.contains("diamond") {
            return 1_000_000
        }

        return 0
    }
}

struct ClientProfile: Identifiable, Equatable, Codable {
    let id: String
    let phone: String
    let initials: String
    let name: String
    let email: String
    let birthday: String
    let preferredLanguage: String
    let preferredContactMethod: String
    let marketingConsent: Bool
    // Explicit consent flags (source of truth for what the associate may see).
    let preferenceVisibilityConsent: Bool
    let purchaseHistoryVisibilityConsent: Bool
    let followUpDate: String
    let tier: String
    let rewardPoints: Int
    let lifetimePurchaseAmount: Int
    let boutique: String
    let status: String
    let note: String
    let attributes: [ClientAttribute]
    let tasks: [ClientTask]
    let purchaseHistory: [ClientPurchase]
    let wishlistProductIDs: [String]
    let defaultDeliveryAddress: String?
    let deliveryAddressDetail: String?

    init(
        id: String,
        phone: String,
        initials: String,
        name: String,
        email: String = "",
        birthday: String = "",
        preferredLanguage: String = "English",
        preferredContactMethod: String = "Phone",
        marketingConsent: Bool = false,
        preferenceVisibilityConsent: Bool? = nil,
        purchaseHistoryVisibilityConsent: Bool? = nil,
        followUpDate: String = "",
        tier: String? = nil,
        rewardPoints: Int? = nil,
        lifetimePurchaseAmount: Int? = nil,
        boutique: String,
        status: String,
        note: String,
        attributes: [ClientAttribute],
        tasks: [ClientTask],
        purchaseHistory: [ClientPurchase] = [],
        wishlistProductIDs: [String] = [],
        defaultDeliveryAddress: String? = nil,
        deliveryAddressDetail: String? = nil
    ) {
        self.id = id
        self.phone = phone
        self.initials = initials
        self.name = name
        self.email = email
        self.birthday = birthday
        self.preferredLanguage = preferredLanguage
        self.preferredContactMethod = preferredContactMethod
        self.marketingConsent = marketingConsent
        // When not passed explicitly, fall back to the legacy status/task derivation
        // so profiles built before the explicit flags keep their consent state.
        self.preferenceVisibilityConsent = preferenceVisibilityConsent
            ?? Self.legacyAllowsPreferenceVisibility(status: status, tasks: tasks)
        self.purchaseHistoryVisibilityConsent = purchaseHistoryVisibilityConsent
            ?? Self.legacyAllowsPurchaseHistoryVisibility(status: status, tasks: tasks)
        self.followUpDate = followUpDate
        // Lifetime spend is the larger of the stored amount and the sum of recorded
        // purchases, so it always reflects the client's actual purchase history.
        let historySpend = Self.lifetimeSpend(from: purchaseHistory)
        let resolvedLifetimePurchaseAmount = lifetimePurchaseAmount
            ?? rewardPoints.map { max(0, $0) * 1_000 }
            ?? ClientTier.minimumLifetimeAmount(for: tier)
        self.lifetimePurchaseAmount = max(0, max(resolvedLifetimePurchaseAmount, historySpend))
        self.rewardPoints = ClientTier.rewardPoints(for: self.lifetimePurchaseAmount)
        self.tier = ClientTier.displayName(for: self.rewardPoints)
        self.boutique = boutique
        self.status = status
        self.note = note
        self.attributes = attributes
        self.tasks = tasks
        self.purchaseHistory = purchaseHistory
        self.wishlistProductIDs = wishlistProductIDs
        self.defaultDeliveryAddress = defaultDeliveryAddress
        self.deliveryAddressDetail = deliveryAddressDetail
    }

    /// Total spend (in rupees) recorded across a client's purchase history.
    /// `grossPaise` is the gross-inclusive line amount (paise) captured at checkout.
    static func lifetimeSpend(from purchaseHistory: [ClientPurchase]) -> Int {
        purchaseHistory.reduce(0) { $0 + max(0, $1.grossPaise ?? 0) } / 100
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case phone
        case initials
        case name
        case email
        case birthday
        case preferredLanguage
        case preferredContactMethod
        case marketingConsent
        case preferenceVisibilityConsent
        case purchaseHistoryVisibilityConsent
        case followUpDate
        case tier
        case rewardPoints
        case lifetimePurchaseAmount
        case boutique
        case status
        case note
        case attributes
        case tasks
        case purchaseHistory
        case wishlistProductIDs
        case defaultDeliveryAddress
        case deliveryAddressDetail
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        phone = try container.decode(String.self, forKey: .phone)
        initials = try container.decode(String.self, forKey: .initials)
        name = try container.decode(String.self, forKey: .name)
        email = try container.decodeIfPresent(String.self, forKey: .email) ?? ""
        birthday = try container.decodeIfPresent(String.self, forKey: .birthday) ?? ""
        preferredLanguage = try container.decodeIfPresent(String.self, forKey: .preferredLanguage) ?? "English"
        preferredContactMethod = try container.decodeIfPresent(String.self, forKey: .preferredContactMethod) ?? "Phone"
        marketingConsent = try container.decodeIfPresent(Bool.self, forKey: .marketingConsent) ?? false
        followUpDate = try container.decodeIfPresent(String.self, forKey: .followUpDate) ?? ""
        let storedTier = try container.decodeIfPresent(String.self, forKey: .tier)
        let storedRewardPoints = try container.decodeIfPresent(Int.self, forKey: .rewardPoints)
        let storedLifetimePurchaseAmount = try container.decodeIfPresent(Int.self, forKey: .lifetimePurchaseAmount)
        // Decode the purchase history first so lifetime spend can include it.
        let decodedPurchaseHistory = try container.decodeIfPresent([ClientPurchase].self, forKey: .purchaseHistory) ?? []
        purchaseHistory = decodedPurchaseHistory
        let historySpend = Self.lifetimeSpend(from: decodedPurchaseHistory)
        let resolvedLifetimePurchaseAmount = storedLifetimePurchaseAmount
            ?? storedRewardPoints.map { max(0, $0) * 1_000 }
            ?? ClientTier.minimumLifetimeAmount(for: storedTier)
        lifetimePurchaseAmount = max(0, max(resolvedLifetimePurchaseAmount, historySpend))
        rewardPoints = ClientTier.rewardPoints(for: lifetimePurchaseAmount)
        tier = ClientTier.displayName(for: rewardPoints)
        boutique = try container.decode(String.self, forKey: .boutique)
        status = try container.decode(String.self, forKey: .status)
        note = try container.decode(String.self, forKey: .note)
        attributes = try container.decode([ClientAttribute].self, forKey: .attributes)
        let decodedTasks = try container.decodeIfPresent([ClientTask].self, forKey: .tasks) ?? []
        if decodedTasks.isEmpty {
            self.tasks = Self.reconstructTasks(
                status: status,
                marketingConsent: marketingConsent,
                followUpDate: followUpDate,
                attributes: attributes
            )
        } else {
            self.tasks = decodedTasks
        }
        wishlistProductIDs = try container.decodeIfPresent([String].self, forKey: .wishlistProductIDs) ?? []
        defaultDeliveryAddress = try container.decodeIfPresent(String.self, forKey: .defaultDeliveryAddress)
        deliveryAddressDetail = try container.decodeIfPresent(String.self, forKey: .deliveryAddressDetail)
        // Explicit flags when present; otherwise migrate from the legacy status/tasks.
        preferenceVisibilityConsent = try container.decodeIfPresent(Bool.self, forKey: .preferenceVisibilityConsent)
            ?? Self.legacyAllowsPreferenceVisibility(status: status, tasks: tasks)
        purchaseHistoryVisibilityConsent = try container.decodeIfPresent(Bool.self, forKey: .purchaseHistoryVisibilityConsent)
            ?? Self.legacyAllowsPurchaseHistoryVisibility(status: status, tasks: tasks)
    }

    static func reconstructTasks(
        status: String,
        marketingConsent: Bool,
        followUpDate: String,
        attributes: [ClientAttribute]
    ) -> [ClientTask] {
        var tasks: [ClientTask] = []
        
        let consentAccepted = status.lowercased().contains("verified") || status.lowercased().contains("visible")
        
        tasks.append(ClientTask(
            icon: consentAccepted ? "checkmark.shield" : "eye.slash",
            title: consentAccepted ? "Preference consent on" : "Preference consent pending",
            subtitle: consentAccepted ? "Preferences and history visible" : "Only identity is visible to sales associate"
        ))
        
        tasks.append(ClientTask(
            icon: "heart",
            title: attributes.isEmpty ? "Preferences pending" : (consentAccepted ? "Preferences saved" : "Preferences captured privately"),
            subtitle: attributes.isEmpty ? "No optional preference data saved" : (consentAccepted ? attributes.map { "\($0.title): \($0.value)" }.joined(separator: ", ") : "Other preferences require client consent")
        ))
        
        tasks.append(ClientTask(
            icon: marketingConsent ? "megaphone.fill" : "bell.slash",
            title: marketingConsent ? "Marketing consent on" : "Marketing consent off",
            subtitle: marketingConsent ? "Client can receive campaigns" : "Do not send marketing campaigns"
        ))
        
        if !followUpDate.isEmpty {
            tasks.append(ClientTask(
                icon: "calendar.badge.clock",
                title: "Follow-up",
                subtitle: followUpDate
            ))
        }
        
        return tasks
    }

    /// Returns a copy of this profile with an updated wishlist, preserving every other field.
    /// Tier and reward points recompute identically from the unchanged lifetime purchase amount.
    func updatingWishlist(_ productIDs: [String]) -> ClientProfile {
        ClientProfile(
            id: id,
            phone: phone,
            initials: initials,
            name: name,
            email: email,
            birthday: birthday,
            preferredLanguage: preferredLanguage,
            preferredContactMethod: preferredContactMethod,
            marketingConsent: marketingConsent,
            preferenceVisibilityConsent: preferenceVisibilityConsent,
            purchaseHistoryVisibilityConsent: purchaseHistoryVisibilityConsent,
            followUpDate: followUpDate,
            lifetimePurchaseAmount: lifetimePurchaseAmount,
            boutique: boutique,
            status: status,
            note: note,
            attributes: attributes,
            tasks: tasks,
            purchaseHistory: purchaseHistory,
            wishlistProductIDs: productIDs,
            defaultDeliveryAddress: defaultDeliveryAddress,
            deliveryAddressDetail: deliveryAddressDetail
        )
    }

    /// Returns a copy of this profile with new purchases prepended to the history,
    /// preserving every other field. Tier and reward points recompute identically
    /// from the unchanged lifetime purchase amount.
    func addingPurchases(_ newPurchases: [ClientPurchase]) -> ClientProfile {
        ClientProfile(
            id: id,
            phone: phone,
            initials: initials,
            name: name,
            email: email,
            birthday: birthday,
            preferredLanguage: preferredLanguage,
            preferredContactMethod: preferredContactMethod,
            marketingConsent: marketingConsent,
            preferenceVisibilityConsent: preferenceVisibilityConsent,
            purchaseHistoryVisibilityConsent: purchaseHistoryVisibilityConsent,
            followUpDate: followUpDate,
            lifetimePurchaseAmount: lifetimePurchaseAmount,
            boutique: boutique,
            status: status,
            note: note,
            attributes: attributes,
            tasks: tasks,
            purchaseHistory: newPurchases + purchaseHistory,
            wishlistProductIDs: wishlistProductIDs,
            defaultDeliveryAddress: defaultDeliveryAddress,
            deliveryAddressDetail: deliveryAddressDetail
        )
    }

    func matches(_ query: String) -> Bool {
        let normalizedQuery = query
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard !normalizedQuery.isEmpty else { return false }

        return name.lowercased().contains(normalizedQuery)
            || id.lowercased().contains(normalizedQuery)
            || phone.lowercased().contains(normalizedQuery)
            || email.lowercased().contains(normalizedQuery)
    }

    var allowsPreferenceVisibility: Bool { preferenceVisibilityConsent }

    var allowsPurchaseHistoryVisibility: Bool { purchaseHistoryVisibilityConsent }

    /// Legacy string derivation, used only to migrate profiles saved before the
    /// explicit consent flags existed (init / decoder fall back to these when the
    /// stored booleans are absent).
    static func legacyAllowsPreferenceVisibility(status: String, tasks: [ClientTask]) -> Bool {
        let taskText = tasks
            .map { "\($0.title) \($0.subtitle)" }
            .joined(separator: " ")
            .lowercased()
        let profileText = "\(status) \(taskText)".lowercased()

        return profileText.contains("consent verified")
            || profileText.contains("consent on")
            || profileText.contains("preferences visible")
            || profileText.contains("profile and purchase history allowed")
    }

    static func legacyAllowsPurchaseHistoryVisibility(status: String, tasks: [ClientTask]) -> Bool {
        let taskText = tasks
            .map { "\($0.title) \($0.subtitle)" }
            .joined(separator: " ")
            .lowercased()
        let profileText = "\(status) \(taskText)".lowercased()

        return profileText.contains("consent verified")
            || profileText.contains("purchase history visible")
            || profileText.contains("purchase history allowed")
            || profileText.contains("history visible")
            || profileText.contains("profile and purchase history allowed")
    }

    var hasClientInsightConsent: Bool {
        allowsPreferenceVisibility || allowsPurchaseHistoryVisibility
    }

    var rewardPointsText: String {
        NumberFormatter.localizedString(from: NSNumber(value: rewardPoints), number: .decimal)
    }

    var lifetimePurchaseText: String {
        if lifetimePurchaseAmount >= 10_000_000 {
            return "Rs. \(formattedAmount(Double(lifetimePurchaseAmount) / 10_000_000))Cr"
        }

        if lifetimePurchaseAmount >= 100_000 {
            return "Rs. \(formattedAmount(Double(lifetimePurchaseAmount) / 100_000))L"
        }

        return "Rs. \(NumberFormatter.localizedString(from: NSNumber(value: lifetimePurchaseAmount), number: .decimal))"
    }

    var visiblePreferenceAttributes: [ClientAttribute] {
        attributes.filter { !$0.isConsentPlaceholder }
    }

    func sanitizedForClienteling(
        fallbackLifetimePurchaseAmount: Int? = nil,
        fallbackPurchaseHistory: [ClientPurchase] = [],
        fallbackWishlistProductIDs: [String] = []
    ) -> ClientProfile {
        let cleanedAttributes = attributes.filter { !$0.isConsentPlaceholder }
        let cleanedTasks = tasks.map { task in
            guard task.subtitle.lowercased().contains("hidden until") else {
                return task
            }

            return ClientTask(
                icon: task.icon,
                title: task.title,
                subtitle: "Other preferences require client consent"
            )
        }

        return ClientProfile(
            id: id,
            phone: phone,
            initials: initials,
            name: name,
            email: email,
            birthday: birthday,
            preferredLanguage: preferredLanguage,
            preferredContactMethod: preferredContactMethod,
            marketingConsent: marketingConsent,
            preferenceVisibilityConsent: preferenceVisibilityConsent,
            purchaseHistoryVisibilityConsent: purchaseHistoryVisibilityConsent,
            followUpDate: followUpDate,
            tier: tier,
            lifetimePurchaseAmount: fallbackLifetimePurchaseAmount ?? lifetimePurchaseAmount,
            boutique: boutique,
            status: status,
            note: note,
            attributes: cleanedAttributes,
            tasks: cleanedTasks,
            purchaseHistory: purchaseHistory.isEmpty ? fallbackPurchaseHistory : purchaseHistory,
            wishlistProductIDs: wishlistProductIDs.isEmpty ? fallbackWishlistProductIDs : wishlistProductIDs,
            defaultDeliveryAddress: defaultDeliveryAddress,
            deliveryAddressDetail: deliveryAddressDetail
        )
    }

    private func formattedAmount(_ amount: Double) -> String {
        let formatted = String(format: "%.2f", amount)
        return formatted
            .replacingOccurrences(of: ".00", with: "")
            .replacingOccurrences(of: #"0$"#, with: "", options: .regularExpression)
    }
}

struct ClientPurchase: Identifiable, Equatable, Codable {
    let id: String
    let productID: String
    let productName: String
    let price: String
    let purchasedOn: String
    let boutique: String
    // Items bought in the same checkout share an `orderID` so they group into one
    // order in the history. The remaining fields let that order rebuild its tax
    // invoice. All optional so legacy/DB entries decode as single-item orders.
    var orderID: String? = nil
    var quantity: Int? = nil
    var grossPaise: Int? = nil
    var hsn: String? = nil
    var gstRate: Double? = nil
    var invoiceNumber: String? = nil
    // Fulfilment captured at checkout so a re-opened receipt rebuilds correctly.
    // "pickup" / "delivery"; address + tracking id are delivery-only.
    var fulfillmentKind: String? = nil
    var deliveryAddress: String? = nil
    var trackingID: String? = nil
}

struct ClientAttribute: Identifiable, Equatable, Codable {
    let title: String
    let value: String

    var id: String {
        "\(title)-\(value)"
    }

    var isConsentPlaceholder: Bool {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .contains("hidden until consent")
    }
}

struct ClientTask: Identifiable, Equatable, Codable {
    let icon: String
    let title: String
    let subtitle: String

    var id: String {
        "\(icon)-\(title)-\(subtitle)"
    }
}

struct ProductCategory: Identifiable, Equatable {
    let id: String
    let title: String
    let icon: String
}

struct SalesProduct: Identifiable, Equatable {
    let id: String
    var name: String
    var brand: String
    var categoryID: String
    let audience: String
    var price: String
    let originalPrice: String?
    var imageName: String
    let badge: String?
    let availability: String
    let stockNote: String
    let sizes: [String]
    let materials: [String]
    let colors: [String]
    let suggestedReason: String
    let isWishlisted: Bool
    /// On-hand units for this SKU. Mutable so a completed sale can decrement it.
    /// Seeded from `stockNote`/`availability` via `seededStockQuantity()`.
    var stockQuantity: Int = 0
    /// Tracks if the product was fetched from the Supabase database.
    var existsInDB: Bool = true
    /// The Supabase `Product.id` (uuid) backing this SKU. Used to join
    /// `StoreInventory` (its `productid`) for on-hand stock and to decrement that
    /// stock when a sale is finalized. Empty for local/dummy products.
    var dbID: String = ""

    // Additional Supabase database fields
    var barcode: String? = nil
    var isActive: Bool? = true
    var reorderThreshold: Int? = nil

    /// Returns a copy with `stockQuantity` seeded from the catalogue metadata, so
    /// the Stock screen shows a real count that a sale can then reduce.
    func seededStockQuantity() -> SalesProduct {
        var copy = self
        copy.stockQuantity = Self.inferStockQuantity(availability: availability, stockNote: stockNote)
        return copy
    }

    nonisolated static func inferStockQuantity(availability: String, stockNote: String) -> Int {
        // Prefer an explicit count in the note ("2 pieces available…").
        if let range = stockNote.range(of: #"[0-9]+"#, options: .regularExpression),
           let count = Int(stockNote[range]) {
            return count
        }
        if stockNote.lowercased().contains("not in boutique") { return 0 }
        return availability == "In boutique" ? 6 : 3
    }

    var isInStock: Bool { stockQuantity > 0 }

    func matches(_ query: String) -> Bool {
        let normalizedQuery = query
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard !normalizedQuery.isEmpty else { return false }

        let searchableFields = [id, name, brand, categoryID] + sizes + materials + colors
        return searchableFields.contains { $0.lowercased().contains(normalizedQuery) }
    }

    var priceValue: Double {
        Self.parsePriceValue(price)
    }

    var originalPriceValue: Double? {
        originalPrice.map(Self.parsePriceValue)
    }

    var hasDiscount: Bool {
        guard let originalPriceValue else { return false }
        return originalPriceValue > priceValue
    }

    var discountText: String? {
        guard let originalPriceValue, originalPriceValue > priceValue else { return nil }
        let percentage = Int(((1 - (priceValue / originalPriceValue)) * 100).rounded())
        return "\(percentage)% off"
    }

    nonisolated private static func parsePriceValue(_ priceText: String) -> Double {
        let normalizedText = priceText.lowercased()

        // Pull the first numeric token (e.g. "1.84" from "rs. 1.84l"). Stripping
        // every non-[0-9.] character and joining instead would merge the dot in
        // the "Rs." prefix into the number (".1.84"), which fails to parse and
        // silently yields 0 — the reason payment amounts came out as ₹0.
        let baseValue: Double
        if let match = normalizedText.range(of: #"[0-9]+(\.[0-9]+)?"#, options: .regularExpression) {
            baseValue = Double(normalizedText[match]) ?? 0
        } else {
            baseValue = 0
        }

        if normalizedText.contains("cr") {
            return baseValue * 100
        }

        if normalizedText.contains("k") {
            return baseValue / 100
        }

        return baseValue
    }
}

struct StockDashboard {
    let metrics: [StockMetric]
    let issueTypes: [StockIssueType]
    let scanChecks: [StockScanCheck]
    let reviews: [StoreManagerReview]
}

struct StockMetric: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let detail: String
}

struct StockIssueType: Identifiable, Equatable {
    let id: String
    let title: String
    let icon: String
    let description: String
}

struct StockScanCheck: Identifiable {
    let id = UUID()
    let title: String
    let status: String
    let icon: String
}

struct StoreManagerReview: Identifiable {
    let id = UUID()
    let title: String
    let status: String
    let note: String
    let time: String
    let icon: String
}

struct IssueDashboard {
    let issueTypes: [IssueRequestType]
    let repairDiagnosisTypes: [String]
    let repairServicePrices: [String]
    let repairWarrantyOptions: [String]
    let returnExchangeTypes: [String]
    let serviceTypes: [String]
    let repairStatuses: [String]
    let historyItems: [IssueHistoryItem]
}

struct IssueRequestType: Identifiable, Equatable {
    let id: String
    let title: String
    let icon: String
    let description: String
}

struct IssueHistoryItem: Identifiable {
    let id = UUID()
    let title: String
    let requestType: String
    let status: IssueApprovalStatus
    let note: String
    let time: String
    let icon: String
}

enum IssueApprovalStatus: String {
    case approved = "Approved"
    case rejected = "Rejected"
    case pending = "Pending"
}
