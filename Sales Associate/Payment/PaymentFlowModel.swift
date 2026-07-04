//
//  PaymentFlowModel.swift
//  Sales Associate
//
//  The internal state machine for the `.payment` destination. This is a mock:
//  it simulates order-create, QR generation, verification, and finalize using
//  timers, and branches to every terminal state via `DemoScenario`.
//
//  A real build would replace the simulated transitions with backend calls and
//  a webhook/poll — the state vocabulary and the UI would stay the same.
//

import SwiftUI
import Combine

@MainActor
final class PaymentFlowModel: ObservableObject {
    @Published private(set) var stage: PaymentStage = .creatingOrder
    @Published private(set) var order: FrozenOrder
    @Published private(set) var tenders: [PaymentTender] = []
    @Published var scenario: DemoScenario
    @Published private(set) var qrCloseBy: Date?
    @Published private(set) var reservationExpiresAt: Date?
    @Published private(set) var activeQRAmountPaise: Int = 0
    @Published var splitCardAmountPaise: Int = 0
    @Published private(set) var cashReceivedPaise: Int = 0
    @Published private(set) var lastRestrictedAction: RestrictedActionKind?

    // Live Razorpay hosted checkout is the default flow (redirect to Razorpay).
    // Toggle off in the Demo menu to walk the mock catalogue instead.
    @Published var useLiveGateway = true
    @Published private(set) var qrImageURL: URL?
    @Published private(set) var hostedCheckoutURL: URL?
    @Published private(set) var gatewayError: String?

    let config: PaymentConfig
    private var flowGeneration = 0
    private var reservationGeneration = 0
    private var qrSessionGeneration = 0
    private var lastStatusCheck: Date = .distantPast

    init(order: FrozenOrder, scenario: DemoScenario = .happyPath, config: PaymentConfig? = nil) {
        self.order = order
        self.scenario = scenario
        self.config = config ?? PaymentConfig()
    }

    // MARK: Derived amounts

    var paidPaise: Int { tenders.filter { $0.status == .successful }.reduce(0) { $0 + $1.amountPaise } }
    var remainingPaise: Int { max(0, order.totalPaise - paidPaise) }
    var overpaidPaise: Int { max(0, paidPaise - order.totalPaise) }
    var hasSuccessfulTender: Bool { tenders.contains { $0.status == .successful } }

    /// Snapshot of how the order was paid, captured at finalize for the sale/receipt
    /// record. Uses the most recent successful tender as the primary method.
    var paymentSummary: PaymentSummary {
        let successful = tenders.filter { $0.status == .successful }
        let primary = successful.last ?? tenders.last
        return PaymentSummary(
            paidPaise: paidPaise,
            method: primary?.method.rawValue ?? "Unknown",
            reference: primary?.reference
        )
    }

    var suggestedCardPaise: Int {
        let comfortableQR = 50_000_00   // ₹50,000 clears most customers' daily UPI limit (C2)
        return min(order.totalPaise, max(config.cardMinPaise, order.totalPaise - comfortableQR))
    }

    var isAboveQRCap: Bool { order.totalPaise > config.upiQrCapPaise }

    // MARK: Stage control

    private func setStage(_ new: PaymentStage) {
        flowGeneration += 1
        withAnimation(.snappy(duration: 0.28)) { stage = new }
    }

    /// Fire `action` after `seconds`, but only if nothing else moved the flow on
    /// and we are still on the stage we expected (guards against stale timers).
    private func schedule(_ seconds: Double, expecting expected: PaymentStage, _ action: @escaping () -> Void) {
        let gen = flowGeneration
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            guard gen == self.flowGeneration, self.stage == expected else { return }
            action()
        }
    }

    // MARK: PAY-00 — create & freeze order

    func start() {
        // Always show the method picker after freezing the order. Previously the
        // live flow auto-presented Razorpay, so the Card row was never a stable,
        // tappable entry point and presentation timing could swallow the first tap.
        setStage(.creatingOrder)
        schedule(useLiveGateway ? 0.45 : 1.3, expecting: .creatingOrder) { [weak self] in
            guard let self else { return }
            if !self.useLiveGateway, self.scenario == .orderCreateFails {
                self.setStage(.orderCreateFailed)
            } else {
                self.beginReservation()
                self.setStage(.methodSelect)
            }
        }
    }

    func retryOrderCreate() { start() }

    // MARK: Reservation (OVR-06)

    private func beginReservation() {
        reservationGeneration += 1
        let gen = reservationGeneration
        let ttl = scenario == .reservationExpires ? 9 : config.reservationTTLSeconds
        reservationExpiresAt = Date().addingTimeInterval(TimeInterval(ttl))

        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(ttl) * 1_000_000_000)
            guard let self, gen == self.reservationGeneration else { return }
            // A successful tender must never silently expire (addendum A4).
            guard !self.hasSuccessfulTender else { return }
            guard self.isPreTenderStage else { return }
            self.reservationExpiresAt = nil
            self.setStage(.reservationExpired)
        }
    }

    private var isPreTenderStage: Bool {
        switch stage {
        case .methodSelect, .aboveCap, .gstinCapture, .upiQR, .splitConfig, .cashEntry, .manualPOS:
            return true
        default:
            return false
        }
    }

    func recheckAvailabilityAfterExpiry() { start() }

    // MARK: PAY-01 — method selection

    func selectMethod(_ kind: PaymentMethodKind) {
        switch kind {
        case .upiQR:
            if isAboveQRCap { setStage(.aboveCap) } else { generateQR(amountPaise: remainingPaise) }
        case .card:
            if useLiveGateway {
                startHostedCheckout()
            } else {
                beginVerification(for: .card, amountPaise: remainingPaise)
            }
        case .cash:
            cashReceivedPaise = 0
            setStage(.cashEntry)
        case .split:
            splitCardAmountPaise = suggestedCardPaise
            setStage(.splitConfig)
        case .manualPOS:
            setStage(.manualPOS)
        }
    }

    func continueFromAboveCap(useSplit: Bool) {
        if useSplit {
            splitCardAmountPaise = suggestedCardPaise
            setStage(.splitConfig)
        } else {
            beginVerification(for: .card, amountPaise: remainingPaise)
        }
    }

    // MARK: OVR-07 — GSTIN capture

    func captureGSTIN(gstin: String, legalName: String) {
        order.buyerType = .b2b(gstin: gstin, legalName: legalName)
        setStage(.methodSelect)
    }

    func skipGSTIN() { setStage(.methodSelect) }

    func openGSTINCapture() { setStage(.gstinCapture) }

    // MARK: Demo controls (place of supply / buyer type)

    /// Flips the tax treatment so the receipt can demo CGST+SGST vs IGST (F1).
    func setInterstate(_ on: Bool) {
        order.treatment = on ? .interState : .intraState
        order.placeOfSupply = on
            ? PlaceOfSupply(stateName: "Karnataka", stateCode: "29")
            : .supplierState
    }

    func setBusinessBuyer(_ on: Bool) {
        order.buyerType = on
            ? .b2b(gstin: "29ABCDE1234F1Z5", legalName: "\(order.clientName) Holdings LLP")
            : .b2c
    }

    var isInterstate: Bool { order.treatment == .interState }

    // MARK: PAY-04 — UPI QR

    private func generateQR(amountPaise: Int) {
        if useLiveGateway {
            generateLiveQR(amountPaise: amountPaise)
        } else {
            generateMockQR(amountPaise: amountPaise)
        }
    }

    private func generateMockQR(amountPaise: Int) {
        qrImageURL = nil
        activeQRAmountPaise = amountPaise
        let expiry = scenario == .qrExpiresThenLateCredit ? 7 : config.qrExpirySeconds
        qrCloseBy = Date().addingTimeInterval(TimeInterval(expiry))
        setStage(.upiQR)

        // Auto-expire off the server close_by (addendum B5).
        schedule(Double(expiry), expecting: .upiQR) { [weak self] in
            self?.setStage(.qrExpired)
            // Expired must keep listening — a late credit still resolves (B1).
            if self?.scenario == .qrExpiresThenLateCredit {
                self?.schedule(3.0, expecting: .qrExpired) { self?.markCustomerPaidQR(fromExpired: true) }
            }
        }
    }

    // MARK: Live Razorpay UPI QR

    private func generateLiveQR(amountPaise: Int) {
        qrSessionGeneration += 1
        let session = qrSessionGeneration
        gatewayError = nil
        qrImageURL = nil
        qrCloseBy = nil
        activeQRAmountPaise = amountPaise
        setStage(.upiQR)   // shows a "generating…" state until the image arrives

        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let result = try await RazorpayGatewayService.shared.createQR(
                    localOrderID: self.order.orderID,
                    amountPaise: amountPaise,
                    description: "Order \(self.order.orderID) — \(self.order.clientName)",
                    closeBySeconds: self.config.qrExpirySeconds
                )
                guard session == self.qrSessionGeneration else { return }
                self.qrImageURL = result.imageURL
                self.qrCloseBy = result.closeBy
                self.activeQRAmountPaise = result.amountPaise
                self.startLivePolling(qrID: result.qrID, session: session, closeBy: result.closeBy)
            } catch {
                guard session == self.qrSessionGeneration else { return }
                self.gatewayError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                self.setStage(.methodSelect)
            }
        }
    }

    private func startLivePolling(qrID: String, session: Int, closeBy: Date) {
        Task { @MainActor [weak self] in
            while true {
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                guard let self, session == self.qrSessionGeneration else { return }
                guard self.stage == .upiQR || self.stage == .qrExpired else { return }
                // Flip to the expired screen once close_by passes, but keep polling (B1).
                if self.stage == .upiQR, closeBy.timeIntervalSinceNow <= 0 {
                    self.setStage(.qrExpired)
                }
                do {
                    let status = try await RazorpayGatewayService.shared.fetchStatus(qrID: qrID)
                    guard session == self.qrSessionGeneration else { return }
                    if status.status == .paid {
                        self.handleLivePaid(amountPaise: status.amountPaidPaise ?? self.activeQRAmountPaise, paymentID: status.paymentID)
                        return
                    }
                } catch {
                    // Network hiccup — keep polling.
                }
            }
        }
    }

    private func handleLivePaid(amountPaise: Int, paymentID: String?, method: PaymentMethodKind = .upiQR) {
        // Ignore duplicate "paid" callbacks (overlapping poll ticks, or the webhook
        // and the poll both firing) once we're already finalizing or done —
        // otherwise a second hit resets the flow back to the completing spinner.
        switch stage {
        case .completing, .receipt, .success, .finalizeNeedsAttention:
            return
        default:
            break
        }
        qrSessionGeneration += 1   // stop polling
        qrImageURL = nil
        qrCloseBy = nil
        hostedCheckoutURL = nil
        addTender(method: method, amountPaise: amountPaise, status: .successful, reference: paymentID)
        if remainingPaise > 0 {
            setStage(method == .card ? .splitCardPaidQRPending : .methodSelect)
        } else {
            beginFinalize()
        }
    }

    // MARK: Live hosted checkout (Razorpay payment link → card / UPI / QR)

    func startHostedCheckout(amountPaise requestedAmountPaise: Int? = nil) {
        qrSessionGeneration += 1
        let session = qrSessionGeneration
        gatewayError = nil
        hostedCheckoutURL = nil
        let checkoutAmount = min(max(0, requestedAmountPaise ?? remainingPaise), remainingPaise)
        guard checkoutAmount > 0 else {
            setStage(.methodSelect)
            return
        }
        activeQRAmountPaise = checkoutAmount
        setStage(.hostedCheckout)

        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let result = try await RazorpayGatewayService.shared.createPaymentLink(
                    localOrderID: self.order.orderID,
                    amountPaise: checkoutAmount,
                    description: "Order \(self.order.orderID) — \(self.order.clientName)"
                )
                guard session == self.qrSessionGeneration else { return }
                self.hostedCheckoutURL = result.shortURL
                self.startHostedPolling(id: result.linkID, session: session)
            } catch {
                guard session == self.qrSessionGeneration else { return }
                self.gatewayError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                self.setStage(.methodSelect)
            }
        }
    }

    private func startHostedPolling(id: String, session: Int) {
        Task { @MainActor [weak self] in
            while true {
                try? await Task.sleep(nanoseconds: 3_500_000_000)
                guard let self, session == self.qrSessionGeneration else { return }
                guard self.stage == .hostedCheckout else { return }
                do {
                    let status = try await RazorpayGatewayService.shared.fetchStatus(qrID: id)
                    guard session == self.qrSessionGeneration else { return }
                    if status.status == .paid {
                        self.handleLivePaid(amountPaise: status.amountPaidPaise ?? self.activeQRAmountPaise, paymentID: status.paymentID, method: .card)
                        return
                    }
                } catch {
                    // Network hiccup — keep polling.
                }
            }
        }
    }

    func cancelHostedCheckout() {
        qrSessionGeneration += 1
        hostedCheckoutURL = nil
        setStage(.methodSelect)
    }

    /// Demo affordance: the customer scanned and paid (a real build gets this from the webhook).
    func markCustomerPaidQR(fromExpired: Bool = false) {
        beginVerification(for: .upiQR, amountPaise: activeQRAmountPaise)
    }

    func expireQRNow() {
        guard stage == .upiQR else { return }
        setStage(.qrExpired)
    }

    func regenerateQR() { generateQR(amountPaise: remainingPaise) }

    /// Switching away must be guarded by a backend status check first (B4). In
    /// this mock nothing is pending once we leave, so we return cleanly.
    func switchMethod() {
        qrSessionGeneration += 1   // stop any live polling
        qrCloseBy = nil
        qrImageURL = nil
        setStage(.methodSelect)
    }

    func finalizeNow() { beginFinalize() }

    /// Debounced manual status check (addendum B3) — never a poll storm.
    func checkStatus() -> Bool {
        let now = Date()
        guard now.timeIntervalSince(lastStatusCheck) > 3 else { return false }
        lastStatusCheck = now
        return true
    }

    // MARK: PAY-06 / PAY-07 — verification

    private func beginVerification(for method: PaymentMethodKind, amountPaise: Int) {
        qrCloseBy = nil
        setStage(.verifying)
        // Most verifications resolve well under the "still checking" threshold.
        schedule(2.6, expecting: .verifying) { [weak self] in
            self?.resolveVerification(method: method, amountPaise: amountPaise)
        }
        // If it drags on, surface "Still checking" rather than spinning silently (D1).
        schedule(Double(config.verifyingToStillChecking), expecting: .verifying) { [weak self] in
            self?.setStage(.stillChecking)
        }
    }

    private func resolveVerification(method: PaymentMethodKind, amountPaise: Int) {
        switch scenario {
        case .statusUnknown:
            setStage(.stillChecking)
            schedule(3.0, expecting: .stillChecking) { [weak self] in self?.setStage(.statusUnknown) }

        case .anomalousCredit:
            setStage(.anomalousCredit)

        case .overpaid:
            addTender(method: method, amountPaise: amountPaise + 50_000_00, status: .successful)
            setStage(.overpaid)

        case .partiallyPaid:
            addTender(method: method, amountPaise: amountPaise / 2, status: .successful)
            setStage(.partiallyPaid)

        default:
            addTender(method: method, amountPaise: amountPaise, status: .successful)
            if remainingPaise > 0 {
                // e.g. split card leg cleared; QR remainder still pending.
                setStage(method == .card ? .splitCardPaidQRPending : .methodSelect)
            } else {
                beginFinalize()
            }
        }
    }

    /// From Still Checking / Status Unknown a webhook can still resolve (D2).
    func forceResolveFromUnknown() {
        addTender(method: .upiQR, amountPaise: activeQRAmountPaise, status: .successful)
        if remainingPaise > 0 { setStage(.methodSelect) } else { beginFinalize() }
    }

    // MARK: Split (PAY-05)

    func chargeCardLeg() {
        let amount = min(max(splitCardAmountPaise, config.cardMinPaise), order.totalPaise)
        if useLiveGateway {
            startHostedCheckout(amountPaise: amount)
        } else {
            beginVerification(for: .card, amountPaise: amount)
        }
    }

    func generateRemainderQR() {
        generateQR(amountPaise: remainingPaise)
    }

    // MARK: Cash

    func setCashReceived(_ paise: Int) { cashReceivedPaise = paise }

    func confirmCash() {
        addTender(method: .cash, amountPaise: order.totalPaise, status: .successful)
        beginFinalize()
    }

    var cashChangePaise: Int { max(0, cashReceivedPaise - order.totalPaise) }

    // MARK: Manual POS (G1)

    func confirmManualPOS(reference: String, chargedMatchesOrder: Bool) {
        guard chargedMatchesOrder else { return }
        addTender(method: .manualPOS, amountPaise: order.totalPaise, status: .successful, reference: reference)
        beginFinalize()
    }

    // MARK: PAY-16 — finalize

    private func beginFinalize() {
        setStage(.completing)
        // A GCD timer — NOT `schedule(...)` (its generation guard could be
        // invalidated by a second finalize call) and NOT `Task.sleep` (which can be
        // skipped by task-scheduling/lifecycle edge cases). GCD fires on the main
        // run loop regardless, and `completeFinalizationIfNeeded` is stage-guarded,
        // so the receipt always appears exactly once.
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) { [weak self] in
            MainActor.assumeIsolated { self?.completeFinalizationIfNeeded() }
        }
    }

    /// Advances the finalize step to the receipt (or the attention screen for the
    /// finalize-fails demo). Guarded by `stage == .completing` so it runs exactly
    /// once even though both the internal timer and `CompletingView`'s own
    /// lifecycle task call it. The view-driven call is a reliability backstop: the
    /// internal timer can be orphaned when the Razorpay Safari cover tears down at
    /// hand-off, which previously left the flow stuck on the "completing" spinner.
    func completeFinalizationIfNeeded() {
        print("Payment: completeFinalizationIfNeeded fired (stage=\(stage))")
        guard stage == .completing else { return }
        if scenario == .finalizeFails {
            setStage(.finalizeNeedsAttention)   // PAY-16B — money is safe
        } else {
            issueInvoice()
            // Auto-generate and show the tax invoice once the order is finalized.
            setStage(.receipt)
        }
    }

    func retryFinalize() { beginFinalize() }

    /// Invoice number + IRN are issued by the backend at finalize (F3/F4).
    private func issueInvoice() {
        order.invoiceNumber = "LM/26-27/\(String(format: "%05d", Int.random(in: 1...99999)))"
        if order.buyerType.isBusiness {
            order.irn = String((UUID().uuidString + UUID().uuidString).prefix(64)).lowercased()
        }
        // Delivery orders get a courier tracking id (demo placeholder until a real
        // logistics integration issues one). Pickup orders carry no tracking.
        // Build the digits one at a time — `String(format: "%010d", …)` truncates a
        // 64-bit Int to 32 bits and can emit negative/garbled numbers.
        if order.fulfillment.kind == .delivery {
            let digits = (0..<10).map { _ in String(Int.random(in: 0...9)) }.joined()
            order.trackingID = "LMX\(digits)IN"
        }
    }

    // MARK: Receipt / restricted actions

    func viewReceipt() { setStage(.receipt) }

    func requestRestricted(_ action: RestrictedActionKind) {
        lastRestrictedAction = action
        setStage(.restrictedRequest)
    }

    func collectRemainder() { setStage(.methodSelect) }

    // MARK: Helpers

    private func addTender(method: PaymentMethodKind, amountPaise: Int, status: PaymentTenderStatus, reference: String? = nil) {
        tenders.append(PaymentTender(method: method, amountPaise: amountPaise, status: status, reference: reference))
    }
}
