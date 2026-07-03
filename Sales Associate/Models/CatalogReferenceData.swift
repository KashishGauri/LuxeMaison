import Foundation

// App reference / configuration data (NOT dummy records). These drive the Stock
// tab, the Issue tab's request flow, and the product-category tabs. They are not
// stored in Supabase, so they live here as static configuration. (Relocated out of
// the deleted SalesAssociateDummyData.swift.)

extension StockDashboard {
    static let sample = StockDashboard(
        metrics: [
            StockMetric(title: "In Boutique", value: "18", detail: "sellable pieces"),
            StockMetric(title: "SM Review", value: "03", detail: "fulfillment checks"),
            StockMetric(title: "Scanned Today", value: "12", detail: "certificate checks")
        ],
        issueTypes: [
            StockIssueType(id: "missing", title: "Missing", icon: "exclamationmark.triangle", description: "Received quantity is lower than the inventory handoff count."),
            StockIssueType(id: "damage", title: "Damage", icon: "sparkle.magnifyingglass", description: "Item arrived damaged during inventory handoff or transit."),
            StockIssueType(id: "mismatch", title: "Mismatch", icon: "tag", description: "Received item does not match the expected box, tag, or name.")
        ],
        scanChecks: [
            StockScanCheck(title: "SKU matched", status: "HB-221 verified", icon: "checkmark.seal"),
            StockScanCheck(title: "Certificate", status: "Authenticity record found", icon: "doc.text.magnifyingglass"),
            StockScanCheck(title: "Store status", status: "Available for selling", icon: "shippingbox")
        ],
        reviews: [
            StoreManagerReview(
                title: "Missing quantity reviewed",
                status: "Approved follow-up",
                note: "SM confirmed short receipt and routed it to Inventory Controller.",
                time: "Today, 10:05 AM",
                icon: "checkmark.seal"
            ),
            StoreManagerReview(
                title: "Damage photo checked",
                status: "More evidence needed",
                note: "Upload a closer photo of clasp and packaging seal.",
                time: "Yesterday, 6:20 PM",
                icon: "camera.macro"
            )
        ]
    )
}

extension IssueDashboard {
    static let sample = IssueDashboard(
        issueTypes: [
            IssueRequestType(id: "missing", title: "Missing", icon: "exclamationmark.triangle", description: "Report missing item details or missing proof to Store Manager."),
            IssueRequestType(id: "exchange", title: "Exchange", icon: "arrow.left.arrow.right", description: "Request Store Manager review for exchange eligibility."),
            IssueRequestType(id: "repair", title: "Repair", icon: "wrench.adjustable", description: "Capture diagnosis, warranty, parts, labour, and charge basis."),
            IssueRequestType(id: "service", title: "Service Issue", icon: "sparkles", description: "Raise service support such as cleaning, authentication, warranty, or adjustment.")
        ],
        repairDiagnosisTypes: [
            "Battery issue",
            "Glass replacement",
            "Movement issue",
            "Strap replacement",
            "Complete servicing"
        ],
        repairServicePrices: [
            "Battery replacement - Fixed price",
            "Strap replacement - Model based",
            "Glass replacement - Watch model based",
            "Complete servicing - Category fixed"
        ],
        repairWarrantyOptions: [
            "In warranty - manufacturing defect",
            "Accidental damage - chargeable",
            "Warranty expired - chargeable"
        ],
        returnExchangeTypes: ["Return", "Exchange", "Cancellation"],
        serviceTypes: ["Cleaning", "Authentication", "Warranty", "Resize / Adjustment"],
        repairStatuses: ["Assessment pending", "Receipt generated", "Client informed", "SM review needed"],
        historyItems: [
            IssueHistoryItem(
                title: "Exchange exception",
                requestType: "Return / Exchange",
                status: .approved,
                note: "SM approved exchange after receipt and product condition check.",
                time: "Today, 9:40 AM",
                icon: "arrow.left.arrow.right"
            ),
            IssueHistoryItem(
                title: "Clasp repair estimate",
                requestType: "Repair",
                status: .pending,
                note: "Waiting for SM review on repair charge before sharing final receipt.",
                time: "Yesterday, 6:15 PM",
                icon: "wrench.adjustable"
            ),
            IssueHistoryItem(
                title: "Late return request",
                requestType: "Return / Exchange",
                status: .rejected,
                note: "Return window exceeded and exception was not approved.",
                time: "22 Jun, 4:30 PM",
                icon: "xmark.seal"
            )
        ]
    )
}

extension ProductCategory {
    static let sampleCategories: [ProductCategory] = [
        ProductCategory(id: "handbags", title: "Handbags", icon: "handbag"),
        ProductCategory(id: "watches", title: "Watches", icon: "applewatch"),
        ProductCategory(id: "fragrances", title: "Fragrances", icon: "wind"),
        ProductCategory(id: "footwear", title: "Footwear", icon: "shoeprints.fill")
    ]
}
