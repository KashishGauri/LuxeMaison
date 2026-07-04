//
//  PaymentScreens.swift
//  Sales Associate
//
//  Every screen in the payment catalogue except the tax invoice (its own file).
//  Screens are thin: they render the current stage and call into the model.
//

import SwiftUI

// MARK: - PAY-00 Creating order

struct CreatingOrderView: View {
    var body: some View {
        PaymentStatusCard(
            tone: .info,
            title: "Creating & freezing order",
            message: "Reserving stock and locking the order total before payment.",
            isBusy: true
        )
    }
}

struct OrderCreateFailedView: View {
    @ObservedObject var model: PaymentFlowModel
    let onExit: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            PaymentStatusCard(
                tone: .danger,
                title: "Couldn't start this order",
                message: "The order and its total could not be created. No payment can be taken until this succeeds."
            )
            PaymentPrimaryButton(title: "Retry", systemImage: "arrow.clockwise") { model.retryOrderCreate() }
            PaymentSecondaryButton(title: "Exit", action: onExit)
        }
    }
}

// MARK: - PAY-01 Method selection

struct MethodSelectView: View {
    @ObservedObject var model: PaymentFlowModel

    private var isCollectingRemainder: Bool { model.paidPaise > 0 && model.remainingPaise > 0 }

    var body: some View {
        PaymentScaffold(
            title: isCollectingRemainder ? "Collect remaining" : "Choose payment method",
            subtitle: isCollectingRemainder
                ? "\(IndianMoney.format(paise: model.remainingPaise)) still to collect."
                : "Select how the customer will pay."
        ) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if let error = model.gatewayError {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(PaymentTone.danger.color)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(PaymentTone.danger.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                    if !model.tenders.isEmpty {
                        ForEach(model.tenders) { TenderProgressRow(tender: $0) }
                    }

                    GSTINRow(model: model)

                    if model.useLiveGateway {
                        Label("Card opens Razorpay's secure hosted checkout. UPI QR is generated directly for this order.", systemImage: "lock.shield.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    ForEach(PaymentMethodKind.allCases) { method in
                        PaymentMethodCard(
                            method: method,
                            isDisabled: model.remainingPaise == 0
                        ) {
                            model.selectMethod(method)
                        }
                    }

                    if model.remainingPaise == 0 {
                        Label("Cart is empty — add products to the cart before taking payment.", systemImage: "bag.badge.questionmark")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(PaymentTone.warning.color)
                    } else if model.isAboveQRCap {
                        Label("UPI QR is capped at \(IndianMoney.format(paise: model.config.upiQrCapPaise)) — larger orders route to Split or Card.",
                              systemImage: "info.circle")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.muted)
                            .padding(.top, 2)
                    }
                }
                .padding(.bottom, 8)
            }
            .scrollIndicators(.hidden)
        }
    }
}

private struct GSTINRow: View {
    @ObservedObject var model: PaymentFlowModel

    var body: some View {
        Button { model.openGSTINCapture() } label: {
            HStack(spacing: 12) {
                Image(systemName: model.order.buyerType.isBusiness ? "building.2.fill" : "building.2")
                    .font(.headline.weight(.black))
                    .foregroundStyle(Theme.gold)
                    .frame(width: 40, height: 40)
                    .background(Theme.selected, in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.order.buyerType.isBusiness ? "Business invoice added" : "Add business GSTIN")
                        .font(.subheadline.weight(.black))
                        .foregroundStyle(Theme.ink)
                    Text("Optional — needed for the buyer to claim input tax credit.")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.muted)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.caption.weight(.black)).foregroundStyle(Theme.muted)
            }
            .padding(12)
            .background(.white.opacity(0.4), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - PAY-01B Above cap

struct AboveCapView: View {
    @ObservedObject var model: PaymentFlowModel

    var body: some View {
        PaymentScaffold(title: "Order exceeds the UPI QR cap", onBack: { model.switchMethod() }) {
            VStack(spacing: 18) {
                PaymentStatusCard(
                    tone: .warning,
                    icon: "arrow.triangle.branch",
                    title: "A single UPI QR won't cover this",
                    message: "\(IndianMoney.format(paise: model.order.totalPaise)) is above the \(IndianMoney.format(paise: model.config.upiQrCapPaise)) UPI QR limit. Split the payment or charge the full amount on card."
                )
                Spacer(minLength: 0)
                PaymentPrimaryButton(title: "Split (Card + UPI)", systemImage: "square.split.2x1") {
                    model.continueFromAboveCap(useSplit: true)
                }
                PaymentSecondaryButton(title: "Charge full amount on card", systemImage: "creditcard") {
                    model.continueFromAboveCap(useSplit: false)
                }
            }
        }
    }
}

// MARK: - OVR-07 GSTIN capture

struct GSTINCaptureView: View {
    @ObservedObject var model: PaymentFlowModel
    @State private var gstin = ""
    @State private var legalName = ""

    private var isValid: Bool { gstin.trimmingCharacters(in: .whitespaces).count == 15 && !legalName.isEmpty }

    var body: some View {
        PaymentScaffold(
            title: "Business invoice",
            subtitle: "Capture the buyer's GSTIN so the tax invoice carries their input-tax-credit details.",
            onBack: { model.skipGSTIN() }
        ) {
            VStack(alignment: .leading, spacing: 14) {
                PaymentField(title: "GSTIN (15 characters)", text: $gstin, autocaps: .characters)
                PaymentField(title: "Registered legal name", text: $legalName, autocaps: .words)
                Spacer(minLength: 0)
                PaymentPrimaryButton(title: "Save business details", systemImage: "checkmark", isEnabled: isValid) {
                    model.captureGSTIN(gstin: gstin.trimmingCharacters(in: .whitespaces), legalName: legalName)
                }
                PaymentSecondaryButton(title: "Skip — personal invoice") { model.skipGSTIN() }
            }
        }
    }
}

struct PaymentField: View {
    let title: String
    @Binding var text: String
    var autocaps: TextInputAutocapitalization = .never

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.caption2.weight(.black))
                .foregroundStyle(Theme.muted)
            TextField("", text: $text)
                .textInputAutocapitalization(autocaps)
                .autocorrectionDisabled()
                .font(.headline.weight(.bold))
                .padding(.horizontal, 14)
                .frame(minHeight: 52)
                .background(.white.opacity(0.75), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.line.opacity(0.55), lineWidth: 1))
        }
    }
}

// MARK: - PAY-04 UPI QR

struct UPIQRView: View {
    @ObservedObject var model: PaymentFlowModel
    @State private var showDebounceNote = false

    @ViewBuilder private var qrArea: some View {
        if let url = model.qrImageURL {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFit()
                case .failure:
                    MockQRCode(seed: model.order.orderID)
                default:
                    ProgressView().frame(height: 240)
                }
            }
        } else if model.useLiveGateway {
            VStack(spacing: 10) {
                ProgressView()
                Text("Generating secure QR…")
                    .font(.caption.weight(.bold)).foregroundStyle(Theme.muted)
            }
            .frame(height: 240)
        } else {
            MockQRCode(seed: model.order.orderID)
        }
    }

    var body: some View {
        PaymentScaffold(title: "Scan to pay by UPI", onBack: { model.switchMethod() }) {
            ScrollView {
                VStack(spacing: 16) {
                    HStack {
                        Text(IndianMoney.format(paise: model.activeQRAmountPaise))
                            .font(.system(size: 30, weight: .black, design: .rounded))
                            .foregroundStyle(Theme.ink)
                        Spacer()
                        if let closeBy = model.qrCloseBy { CountdownPill(closeBy: closeBy) }
                    }

                    qrArea
                        .frame(maxWidth: 320)
                        .padding(16)
                        .background(.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Theme.line.opacity(0.5), lineWidth: 1))

                    Label("Show this to the customer. Keep it steady and bright until they confirm.",
                          systemImage: "eye")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.muted)
                        .multilineTextAlignment(.center)

                    if showDebounceNote {
                        Text("Still checking — please wait a few seconds between status checks.")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(PaymentTone.info.color)
                    }

                    HStack(spacing: 12) {
                        Button {
                            if model.checkStatus() == false {
                                showDebounceNote = true
                                Task { @MainActor in try? await Task.sleep(nanoseconds: 2_500_000_000); showDebounceNote = false }
                            }
                        } label: {
                            Label("Check status", systemImage: "arrow.clockwise")
                                .font(.subheadline.weight(.black))
                                .frame(maxWidth: .infinity, minHeight: 48)
                                .foregroundStyle(Theme.ink)
                                .background(.white.opacity(0.7), in: Capsule())
                        }
                        .buttonStyle(.plain)

                        Button { model.switchMethod() } label: {
                            Label("Switch method", systemImage: "arrow.left.arrow.right")
                                .font(.subheadline.weight(.black))
                                .frame(maxWidth: .infinity, minHeight: 48)
                                .foregroundStyle(Theme.ink)
                                .background(.white.opacity(0.7), in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }

                    if model.useLiveGateway {
                        Label("Waiting for the customer's UPI payment…", systemImage: "dot.radiowaves.left.and.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(PaymentTone.info.color)
                            .padding(.top, 4)
                    } else {
                        VStack(spacing: 8) {
                            DemoBadge(text: "Demo")
                            PaymentPrimaryButton(title: "Customer paid", systemImage: "checkmark.circle") {
                                model.markCustomerPaidQR()
                            }
                        }
                        .padding(.top, 4)
                    }
                }
                .padding(.bottom, 8)
            }
            .scrollIndicators(.hidden)
        }
    }
}

// MARK: - PAY-04C QR expired

struct QRExpiredView: View {
    @ObservedObject var model: PaymentFlowModel

    var body: some View {
        VStack(spacing: 18) {
            PaymentStatusCard(
                tone: .warning,
                icon: "clock.badge.exclamationmark",
                title: "QR expired",
                message: "Still listening for a late payment — if the customer already paid, it will resolve automatically. Don't ask them to pay twice."
            )
            PaymentPrimaryButton(title: "Generate a fresh QR", systemImage: "qrcode") { model.regenerateQR() }
            PaymentSecondaryButton(title: "Switch method") { model.switchMethod() }
            HStack(spacing: 8) {
                DemoBadge(text: "Demo")
                Button("Simulate late credit arriving") { model.markCustomerPaidQR(fromExpired: true) }
                    .font(.caption.weight(.black))
                    .foregroundStyle(Theme.gold)
            }
        }
    }
}

// MARK: - Live hosted checkout (Razorpay page)

struct HostedCheckoutView: View {
    @ObservedObject var model: PaymentFlowModel
    @State private var presentedCheckout: HostedCheckoutDestination?

    var body: some View {
        VStack(spacing: 16) {
            PaymentStatusCard(
                tone: .info,
                icon: "creditcard",
                title: model.hostedCheckoutURL == nil ? "Opening Razorpay…" : "Complete payment in Razorpay",
                message: "Pay by card, UPI, or QR on Razorpay's secure page. We'll confirm and continue automatically.",
                isBusy: true
            )
            if model.hostedCheckoutURL != nil {
                PaymentSecondaryButton(title: "Reopen Razorpay", systemImage: "safari") {
                    presentCheckoutIfReady()
                }
            }
            PaymentSecondaryButton(title: "Cancel payment", systemImage: "xmark") { model.cancelHostedCheckout() }
        }
        .onAppear { presentCheckoutIfReady() }
        .onChange(of: model.hostedCheckoutURL) { _, url in
            presentedCheckout = url.map(HostedCheckoutDestination.init(url:))
        }
        .fullScreenCover(item: $presentedCheckout) { destination in
            PaymentSafariView(url: destination.url, onFinish: { presentedCheckout = nil })
                .ignoresSafeArea()
        }
    }

    private func presentCheckoutIfReady() {
        guard let url = model.hostedCheckoutURL else { return }
        presentedCheckout = HostedCheckoutDestination(url: url)
    }
}

private struct HostedCheckoutDestination: Identifiable {
    let id = UUID()
    let url: URL
}

// MARK: - PAY-05 Split config

struct SplitConfigView: View {
    @ObservedObject var model: PaymentFlowModel

    private var cardMin: Int { model.config.cardMinPaise }
    private var total: Int { model.order.totalPaise }
    private var cardAmount: Int { model.splitCardAmountPaise }
    private var remainder: Int { max(0, total - cardAmount) }

    var body: some View {
        PaymentScaffold(
            title: "Split payment",
            subtitle: "Charge part on card, collect the rest by UPI.",
            onBack: { model.switchMethod() }
        ) {
            VStack(alignment: .leading, spacing: 16) {
                legRow("Card leg", cardAmount, tone: PaymentTone.info.color, icon: "creditcard")
                legRow("UPI remainder", remainder, tone: Theme.gold, icon: "qrcode")

                Slider(
                    value: Binding(
                        get: { Double(min(max(cardAmount, cardMin), max(cardMin, total))) },
                        set: { model.splitCardAmountPaise = Int($0) }
                    ),
                    in: Double(cardMin)...Double(max(cardMin + 100_00, total)),
                    step: 1000_00
                )
                .tint(Theme.gold)

                HStack(spacing: 10) {
                    ForEach(viablePercents(), id: \.self) { percent in
                        Button {
                            model.splitCardAmountPaise = max(cardMin, min(total, total * percent / 100))
                        } label: {
                            Text("\(percent)%")
                                .font(.subheadline.weight(.black))
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .foregroundStyle(Theme.ink)
                                .background(.white.opacity(0.7), in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }

                Text("Card minimum is \(IndianMoney.format(paise: cardMin)). Suggested card amount \(IndianMoney.format(paise: model.suggestedCardPaise)).")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.muted)

                Spacer(minLength: 0)
                PaymentPrimaryButton(title: "Charge \(IndianMoney.format(paise: cardAmount)) on card", systemImage: "creditcard") {
                    model.chargeCardLeg()
                }
            }
        }
    }

    /// Only offer percentages whose amount clears the card minimum (C1).
    private func viablePercents() -> [Int] {
        [25, 50, 75].filter { total * $0 / 100 >= cardMin }
    }

    private func legRow(_ label: String, _ paise: Int, tone: Color, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.headline.weight(.black)).foregroundStyle(tone)
                .frame(width: 40, height: 40).background(tone.opacity(0.14), in: Circle())
            Text(label).font(.subheadline.weight(.black)).foregroundStyle(Theme.ink)
            Spacer()
            Text(IndianMoney.format(paise: paise)).font(.headline.weight(.black)).monospacedDigit().foregroundStyle(Theme.ink)
        }
        .padding(12)
        .background(.white.opacity(0.5), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - PAY-05C Card paid, QR pending

struct SplitCardPaidView: View {
    @ObservedObject var model: PaymentFlowModel

    var body: some View {
        VStack(spacing: 16) {
            PaymentStatusCard(
                tone: .success,
                title: "Card leg paid",
                message: "Now collect the remaining \(IndianMoney.format(paise: model.remainingPaise)) by UPI QR."
            )
            ForEach(model.tenders) { TenderProgressRow(tender: $0) }
            Spacer(minLength: 0)
            PaymentPrimaryButton(title: "Generate UPI QR for remainder", systemImage: "qrcode") {
                model.generateRemainderQR()
            }
        }
    }
}

// MARK: - Cash

struct CashEntryView: View {
    @ObservedObject var model: PaymentFlowModel
    @State private var receivedRupees = ""

    private var receivedPaise: Int { (Int(receivedRupees) ?? 0) * 100 }
    private var isEnough: Bool { receivedPaise >= model.order.totalPaise }

    var body: some View {
        PaymentScaffold(
            title: "Cash",
            subtitle: "Collect \(IndianMoney.format(paise: model.order.totalPaise)) and record any change.",
            onBack: { model.switchMethod() }
        ) {
            VStack(alignment: .leading, spacing: 14) {
                PaymentField(title: "Amount received (₹)", text: $receivedRupees)
                    .onChange(of: receivedRupees) { _, _ in model.setCashReceived(receivedPaise) }
                    .keyboardType(.numberPad)

                if receivedPaise > 0 {
                    HStack {
                        Text("Change to return")
                            .font(.subheadline.weight(.black)).foregroundStyle(Theme.muted)
                        Spacer()
                        Text(IndianMoney.format(paise: max(0, receivedPaise - model.order.totalPaise)))
                            .font(.headline.weight(.black)).monospacedDigit()
                            .foregroundStyle(isEnough ? PaymentTone.success.color : PaymentTone.danger.color)
                    }
                    .padding(12)
                    .background(.white.opacity(0.5), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                    if !isEnough {
                        Label("Received amount is less than the order total.", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption.weight(.bold)).foregroundStyle(PaymentTone.danger.color)
                    }
                }

                Spacer(minLength: 0)
                PaymentPrimaryButton(title: "Confirm cash \(IndianMoney.format(paise: model.order.totalPaise))", systemImage: "banknote", isEnabled: isEnough) {
                    model.confirmCash()
                }
            }
        }
    }
}

// MARK: - Manual POS (G1)

struct ManualPOSView: View {
    @ObservedObject var model: PaymentFlowModel
    @State private var reference = ""
    @State private var amountConfirmed = false

    private var canConfirm: Bool { !reference.trimmingCharacters(in: .whitespaces).isEmpty && amountConfirmed }

    var body: some View {
        PaymentScaffold(
            title: "Manual POS",
            subtitle: "Record the terminal reference and confirm the charged amount.",
            onBack: { model.switchMethod() }
        ) {
            VStack(alignment: .leading, spacing: 14) {
                PaymentField(title: "Terminal reference / RRN", text: $reference, autocaps: .characters)

                Toggle(isOn: $amountConfirmed) {
                    Text("I confirm the terminal charged exactly \(IndianMoney.format(paise: model.order.totalPaise)).")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Theme.ink)
                }
                .tint(Theme.gold)
                .padding(12)
                .background(.white.opacity(0.5), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                Label("Marking success on a mismatched amount is an operational hole — confirm the exact charge.",
                      systemImage: "info.circle")
                    .font(.caption.weight(.semibold)).foregroundStyle(Theme.muted)

                Spacer(minLength: 0)
                PaymentPrimaryButton(title: "Mark successful", systemImage: "checkmark.seal", isEnabled: canConfirm) {
                    model.confirmManualPOS(reference: reference.trimmingCharacters(in: .whitespaces), chargedMatchesOrder: amountConfirmed)
                }
            }
        }
    }
}

// MARK: - PAY-06 Verifying / Still checking

struct VerifyingView: View {
    @ObservedObject var model: PaymentFlowModel
    let stillChecking: Bool

    var body: some View {
        VStack(spacing: 16) {
            PaymentStatusCard(
                tone: .info,
                title: stillChecking ? "Still checking…" : "Verifying payment",
                message: stillChecking
                    ? "This is taking longer than usual. We're still confirming with the bank in the background — no need to keep tapping."
                    : "Confirming the payment with the bank. This usually resolves in a few seconds.",
                isBusy: true
            )
            if stillChecking {
                Label("We'll advance automatically the moment it resolves.", systemImage: "clock.arrow.circlepath")
                    .font(.caption.weight(.semibold)).foregroundStyle(Theme.muted)
            }
        }
    }
}

// MARK: - PAY-07 Status unknown

struct StatusUnknownView: View {
    @ObservedObject var model: PaymentFlowModel

    var body: some View {
        VStack(spacing: 16) {
            PaymentStatusCard(
                tone: .warning,
                icon: "questionmark.circle.fill",
                title: "Payment status unknown",
                message: "We couldn't confirm the payment yet — it may still be processing. Do NOT charge again. We keep checking in the background."
            )
            PaymentSecondaryButton(title: "Refresh status", systemImage: "arrow.clockwise") { _ = model.checkStatus() }
            HStack(spacing: 8) {
                DemoBadge(text: "Demo")
                Button("Webhook resolves → paid") { model.forceResolveFromUnknown() }
                    .font(.caption.weight(.black)).foregroundStyle(Theme.gold)
            }
        }
    }
}

// MARK: - PAY-15 Anomalous credit

struct AnomalousCreditView: View {
    @ObservedObject var model: PaymentFlowModel

    var body: some View {
        VStack(spacing: 16) {
            PaymentStatusCard(
                tone: .warning,
                icon: "exclamationmark.arrow.triangle.2.circlepath",
                title: "Unexpected credit received",
                message: "A credit arrived that doesn't match this order's expected amount or attempt. Don't finalize automatically — have it reviewed."
            )
            PaymentPrimaryButton(title: "Request review", systemImage: "flag") {
                model.requestRestricted(.gatewayRefund)
            }
        }
    }
}

// MARK: - Overpaid

struct OverpaidView: View {
    @ObservedObject var model: PaymentFlowModel

    var body: some View {
        VStack(spacing: 16) {
            PaymentStatusCard(
                tone: .warning,
                icon: "arrow.up.circle.fill",
                title: "Overpaid by \(IndianMoney.format(paise: model.overpaidPaise))",
                message: "More than the order total was received. Complete the order and handle the excess as a separate refund — never re-collect."
            )
            PaymentPrimaryButton(title: "Complete order", systemImage: "checkmark") { model.finalizeNow() }
            PaymentSecondaryButton(title: "Request refund of excess", systemImage: "arrow.uturn.left") {
                model.requestRestricted(.gatewayRefund)
            }
        }
    }
}

// MARK: - Partially paid

struct PartiallyPaidView: View {
    @ObservedObject var model: PaymentFlowModel

    var body: some View {
        VStack(spacing: 16) {
            PaymentStatusCard(
                tone: .warning,
                icon: "circle.lefthalf.filled",
                title: "Partially paid",
                message: "Only \(IndianMoney.format(paise: model.paidPaise)) of \(IndianMoney.format(paise: model.order.totalPaise)) was received. Collect the remaining \(IndianMoney.format(paise: model.remainingPaise)) — the order isn't complete."
            )
            ForEach(model.tenders) { TenderProgressRow(tender: $0) }
            PaymentPrimaryButton(title: "Collect remaining", systemImage: "plus.circle") { model.collectRemainder() }
        }
    }
}

// MARK: - PAY-16 Completing

struct CompletingView: View {
    @ObservedObject var model: PaymentFlowModel
    @State private var showManualContinue = false

    var body: some View {
        VStack(spacing: 16) {
            PaymentStatusCard(
                tone: .info,
                title: "Payment received — completing your order",
                message: "Securing stock, generating the invoice and updating loyalty. A second charge is blocked while this finishes.",
                isBusy: true
            )

            // Safety net: money is already collected, so the associate must never be
            // trapped here. If auto-advance hasn't fired within a few seconds, offer
            // a manual button to reach the receipt.
            if showManualContinue {
                PaymentPrimaryButton(title: "Continue to receipt", systemImage: "arrow.right") {
                    model.completeFinalizationIfNeeded()
                }
            }
        }
        // Primary auto-advance: a GCD timer (not `.task`, which can be cancelled by
        // view-lifecycle churn during the Razorpay Safari hand-off). It fires on the
        // main run loop no matter what; completeFinalizationIfNeeded is stage-guarded.
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) {
                MainActor.assumeIsolated { model.completeFinalizationIfNeeded() }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.5) {
                showManualContinue = true
            }
        }
    }
}

// MARK: - PAY-16B Finalize needs attention

struct FinalizeAttentionView: View {
    @ObservedObject var model: PaymentFlowModel

    var body: some View {
        VStack(spacing: 16) {
            PaymentStatusCard(
                tone: .danger,
                icon: "lock.shield.fill",
                title: "Order needs attention — payment is safe",
                message: "The payment succeeded but finishing the order failed. DO NOT collect payment again. Retry completion or hand off to assisted resolution."
            )
            PaymentPrimaryButton(title: "Retry completion", systemImage: "arrow.clockwise") { model.retryFinalize() }
            PaymentSecondaryButton(title: "Request assisted resolution", systemImage: "person.badge.shield.checkmark") {
                model.requestRestricted(.gatewayRefund)
            }
        }
    }
}

// MARK: - PAY-10 Success

struct SuccessView: View {
    @ObservedObject var model: PaymentFlowModel
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            PaymentStatusCard(
                tone: .success,
                title: "Payment successful",
                message: "\(IndianMoney.format(paise: model.order.totalPaise)) collected for order \(model.order.orderID)."
            )
            ForEach(model.tenders) { TenderProgressRow(tender: $0) }
            Spacer(minLength: 0)
            PaymentPrimaryButton(title: "View tax invoice", systemImage: "doc.text") { model.viewReceipt() }
            PaymentSecondaryButton(title: "Done", action: onDone)
        }
    }
}

// MARK: - Refund failed

struct RefundFailedView: View {
    @ObservedObject var model: PaymentFlowModel

    var body: some View {
        VStack(spacing: 16) {
            PaymentStatusCard(
                tone: .danger,
                title: "Refund failed",
                message: "The refund could not be completed. It stays open — do not assume the money moved. Escalate for manual processing."
            )
            PaymentPrimaryButton(title: "Request manual refund", systemImage: "arrow.uturn.left") {
                model.requestRestricted(.gatewayRefund)
            }
        }
    }
}

// MARK: - OVR-06 Reservation expired

struct ReservationExpiredView: View {
    @ObservedObject var model: PaymentFlowModel
    let onExit: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            PaymentStatusCard(
                tone: .warning,
                icon: "hourglass.bottomhalf.filled",
                title: "Reservation expired",
                message: "The stock hold timed out and the items were released back to inventory. Re-check availability to continue, or exit."
            )
            PaymentPrimaryButton(title: "Re-check availability", systemImage: "arrow.clockwise") {
                model.recheckAvailabilityAfterExpiry()
            }
            PaymentSecondaryButton(title: "Exit", action: onExit)
        }
    }
}

// MARK: - OVR-03 Restricted action request

struct RestrictedRequestView: View {
    @ObservedObject var model: PaymentFlowModel
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            PaymentStatusCard(
                tone: .info,
                icon: "paperplane.fill",
                title: "Request sent to manager",
                message: "\(model.lastRestrictedAction?.rawValue ?? "This action") needs approval. \(model.lastRestrictedAction?.explainer ?? "") You'll be notified when it's actioned."
            )
            PaymentSecondaryButton(title: "Done", action: onDone)
        }
    }
}
