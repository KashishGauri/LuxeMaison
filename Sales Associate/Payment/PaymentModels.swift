//
//  PaymentModels.swift
//  Sales Associate
//
//  Money model, frozen order, GST tax model, tenders and the payment
//  state-machine vocabulary for the post–"Proceed to Pay" flow.
//
//  Everything here is a *mock* prototype: no real gateway. Amounts are kept
//  in integer paise to avoid floating-point money errors.
//

import Foundation

// MARK: - Money

/// Indian-grouped currency formatting (₹1,84,000) backed by en_IN locale.
enum IndianMoney {
    static func format(paise: Int, showsPaise: Bool = false) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_IN")
        formatter.numberStyle = .currency
        formatter.currencyCode = "INR"
        formatter.maximumFractionDigits = showsPaise ? 2 : 0
        formatter.minimumFractionDigits = showsPaise ? 2 : 0
        let rupees = Double(paise) / 100.0
        return formatter.string(from: NSNumber(value: rupees)) ?? "₹\(rupees)"
    }

    /// Converts a `SalesProduct.priceValue` (denominated in lakhs) to integer paise.
    static func paise(fromLakhs lakhs: Double) -> Int {
        Int((lakhs * 100_000 * 100).rounded())
    }
}

// MARK: - Tax (GST)

/// Whether the supply is taxed as CGST+SGST (intra-state) or IGST (interstate).
/// Driven by place of supply — never hardcoded (addendum §1 / F1).
enum GSTTreatment: Equatable {
    case intraState   // CGST + SGST
    case interState   // IGST
}

/// Minimal place-of-supply model (state name + numeric GST state code).
struct PlaceOfSupply: Equatable {
    let stateName: String
    let stateCode: String   // GST state code, e.g. "27" for Maharashtra

    /// The supplier's home state — intra-state supplies match this.
    static let supplierState = PlaceOfSupply(stateName: "Maharashtra", stateCode: "27")
}

/// Per-line GST facts. Rates expressed as a fraction (0.18 == 18%).
struct GSTClassification: Equatable {
    let hsn: String
    let unitOfMeasure: String   // UQC, e.g. "NOS"
    let rate: Double

    /// Heuristic classification so the mock receipt carries plausible HSN + rate.
    static func infer(for product: SalesProduct) -> GSTClassification {
        let haystack = "\(product.name) \(product.categoryID) \(product.audience)".lowercased()

        func has(_ needles: [String]) -> Bool { needles.contains { haystack.contains($0) } }

        if has(["ring", "necklace", "bracelet", "jewel", "diamond", "bvlgari", "sapphire", "emerald", "ruby", "bridal", "band"]) {
            return GSTClassification(hsn: "7113", unitOfMeasure: "NOS", rate: 0.03)
        }
        if has(["watch"]) {
            return GSTClassification(hsn: "9101", unitOfMeasure: "NOS", rate: 0.18)
        }
        if has(["bag", "tote", "clutch", "backpack", "case", "capucines", "hobo", "wallet", "leather"]) {
            return GSTClassification(hsn: "4202", unitOfMeasure: "NOS", rate: 0.18)
        }
        if has(["loafer", "heel", "sling", "shoe", "footwear"]) {
            return GSTClassification(hsn: "6403", unitOfMeasure: "PRS", rate: 0.18)
        }
        return GSTClassification(hsn: "9999", unitOfMeasure: "NOS", rate: 0.18)
    }
}

// MARK: - Line items & order

/// A single frozen line on the tax invoice. `gross` is the tax-inclusive
/// amount the customer sees; taxable value and tax are back-calculated.
struct PaymentLineItem: Identifiable, Equatable {
    let id: String
    let name: String
    let brand: String
    let imageName: String
    let quantity: Int
    let classification: GSTClassification
    let grossInclusivePaise: Int   // unit price × qty, tax-inclusive

    var taxablePaise: Int {
        Int((Double(grossInclusivePaise) / (1 + classification.rate)).rounded())
    }

    var taxPaise: Int { grossInclusivePaise - taxablePaise }
}

enum BuyerType: Equatable {
    case b2c
    case b2b(gstin: String, legalName: String)

    var isBusiness: Bool {
        if case .b2b = self { return true }
        return false
    }
}

/// The order total is frozen before the first payment attempt (addendum §2).
/// Invoice number + IRN are backend-issued at finalize — never on device.
struct FrozenOrder: Equatable {
    let orderID: String
    let lineItems: [PaymentLineItem]
    var placeOfSupply: PlaceOfSupply
    var treatment: GSTTreatment
    var buyerType: BuyerType
    let fulfillment: PaymentFulfillmentSummary
    let clientName: String
    let clientPhone: String

    // Backend-issued at finalize (nil until then).
    var invoiceNumber: String?
    var irn: String?

    var taxablePaise: Int { lineItems.reduce(0) { $0 + $1.taxablePaise } }
    var taxPaise: Int { lineItems.reduce(0) { $0 + $1.taxPaise } }
    var totalPaise: Int { lineItems.reduce(0) { $0 + $1.grossInclusivePaise } }
    var itemCount: Int { lineItems.reduce(0) { $0 + $1.quantity } }

    /// Split tax into the two halves (intra) or single IGST (inter).
    var cgstPaise: Int { treatment == .intraState ? taxPaise / 2 : 0 }
    var sgstPaise: Int { treatment == .intraState ? taxPaise - cgstPaise : 0 }
    var igstPaise: Int { treatment == .interState ? taxPaise : 0 }
}

/// How the order was actually paid — captured at finalize and carried alongside
/// the order so the sale/receipt records can store the tender used.
struct PaymentSummary: Equatable {
    /// Total successfully paid, in paise.
    let paidPaise: Int
    /// Primary tender method (e.g. "UPI QR", "Card", "Cash").
    let method: String
    /// Gateway/tender reference for the primary tender (e.g. Razorpay payment id).
    let reference: String?
}

/// Snapshot of the fulfillment choice carried into payment (decoupled from the
/// private CheckoutFulfillmentMethod enum in ContentView).
struct PaymentFulfillmentSummary: Equatable {
    enum Kind: Equatable { case pickup, delivery }
    let kind: Kind
    let address: String?

    var label: String { kind == .pickup ? "Boutique pickup" : "Delivery" }
}

// MARK: - Tenders

enum PaymentMethodKind: String, CaseIterable, Identifiable, Equatable {
    case upiQR = "UPI QR"
    case card = "Card"
    case cash = "Cash"
    case split = "Split (Card + UPI)"
    case manualPOS = "Manual POS"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .upiQR: return "qrcode"
        case .card: return "creditcard"
        case .cash: return "banknote"
        case .split: return "square.split.2x1"
        case .manualPOS: return "dot.radiowaves.left.and.right"
        }
    }

    var subtitle: String {
        switch self {
        case .upiQR: return "Show a UPI QR for the customer to scan"
        case .card: return "Tap or insert on the POS terminal"
        case .cash: return "Collect notes and record change"
        case .split: return "Card leg first, UPI QR for the remainder"
        case .manualPOS: return "Record an external terminal reference"
        }
    }
}

enum PaymentTenderStatus: Equatable {
    case pending
    case successful
    case failed
}

struct PaymentTender: Identifiable, Equatable {
    let id = UUID()
    let method: PaymentMethodKind
    var amountPaise: Int
    var status: PaymentTenderStatus
    var reference: String?
}

// MARK: - Restricted actions (OVR-03)

/// Actions the associate can only *request* — approver screens stay out of the app.
enum RestrictedActionKind: String, Equatable {
    case gatewayRefund = "Gateway refund"
    case cashReversal = "Cash reversal (manual drawer)"
    case priceOverride = "Price override"

    var explainer: String {
        switch self {
        case .gatewayRefund:
            return "A manager must approve refunding this payment back to the source."
        case .cashReversal:
            return "Cash returns are a manual drawer action — a manager must authorise opening the drawer."
        case .priceOverride:
            return "Changing a frozen order total needs manager approval."
        }
    }
}

// MARK: - State machine

/// Every screen/state in the payment catalogue. The `.payment` destination is a
/// single internal state machine (addendum §7) rather than app-level enum cases.
enum PaymentStage: Equatable {
    case creatingOrder            // PAY-00
    case orderCreateFailed        // PAY-00 failure
    case methodSelect             // PAY-01
    case aboveCap                 // PAY-01B (order over UPI QR cap)
    case gstinCapture             // OVR-07
    case upiQR                    // PAY-04
    case qrExpired                // PAY-04C
    case hostedCheckout           // Live: Razorpay hosted page (card / UPI / QR)
    case splitConfig              // PAY-05
    case splitCardPaidQRPending   // PAY-05C
    case cashEntry                // Cash tender
    case manualPOS                // Manual POS + amount confirm (G1)
    case verifying                // PAY-06
    case stillChecking            // PAY-06 (extended)
    case statusUnknown            // PAY-07 — blocks a second charge
    case anomalousCredit          // PAY-15
    case overpaid
    case partiallyPaid
    case completing               // PAY-16 — finalize in progress
    case finalizeNeedsAttention   // PAY-16B — payment safe, do not re-charge
    case success                  // PAY-10
    case receipt                  // PAY-11 / PAY-11B
    case refundFailed
    case reservationExpired       // OVR-06
    case restrictedRequest        // OVR-03
}

// MARK: - Config & demo scenarios

/// Interaction-timing + cap defaults (addendum §5). All configurable.
struct PaymentConfig: Equatable {
    var upiQrCapPaise = 200_000_00        // ₹2,00,000 UPI QR cap
    var cardMinPaise = 100_000_00         // split card leg minimum
    var qrExpirySeconds = 7 * 60          // 7 min (within Razorpay [2m, 2h])
    var verifyingToStillChecking = 20     // seconds
    var stillCheckingToUnknown = 70       // seconds
    var reservationTTLSeconds = 15 * 60   // 15 min
    var completingBeforeEscalate = 12     // seconds

    static let `default` = PaymentConfig()
}

/// The mock backend needs a way to demonstrate every terminal state. In a real
/// build these outcomes would come from the gateway/webhook.
enum DemoScenario: String, CaseIterable, Identifiable, Equatable {
    case happyPath = "Success"
    case statusUnknown = "Status unknown"
    case finalizeFails = "Finalize needs attention"
    case qrExpiresThenLateCredit = "QR expires → late credit"
    case anomalousCredit = "Anomalous credit"
    case overpaid = "Overpaid"
    case partiallyPaid = "Partially paid"
    case orderCreateFails = "Order-create fails"
    case reservationExpires = "Reservation expires"

    var id: String { rawValue }
}
