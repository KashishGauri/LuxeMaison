//
//  PaymentFlowView.swift
//  Sales Associate
//
//  Root of the `.payment` destination. Builds a frozen order from the selling
//  session, hosts the state machine, keeps a persistent order summary on top,
//  and switches to the screen for the current stage.
//

import SwiftUI

// MARK: - Order builder

enum PaymentOrderBuilder {
    static func build(
        products: [SalesProduct],
        session: SellingSessionState,
        fulfillment: PaymentFulfillmentSummary
    ) -> FrozenOrder {
        let productsByID = Dictionary(uniqueKeysWithValues: products.map { ($0.id, $0) })

        let lineItems: [PaymentLineItem] = session.cartProductIDs.compactMap { id in
            guard let product = productsByID[id] else { return nil }
            let quantity = max(1, session.cartQuantitiesByProductID[id] ?? 1)
            let unitPaise = IndianMoney.paise(fromLakhs: product.priceValue)
            return PaymentLineItem(
                id: product.id,
                name: product.name,
                brand: product.brand,
                imageName: product.imageName,
                quantity: quantity,
                classification: GSTClassification.infer(for: product),
                grossInclusivePaise: unitPaise * quantity
            )
        }

        return FrozenOrder(
            orderID: "LM-\(Int.random(in: 100000...999999))",
            lineItems: lineItems,
            placeOfSupply: .supplierState,
            treatment: .intraState,
            buyerType: .b2c,
            fulfillment: fulfillment,
            clientName: session.createdClient?.name ?? session.displayName,
            clientPhone: session.createdClient?.phone ?? "—"
        )
    }
}

// MARK: - Root view

struct PaymentFlowView: View {
    @StateObject private var model: PaymentFlowModel
    @State private var started = false
    @State private var hasRecordedSale = false
    let onExit: () -> Void
    /// Passes the finalized order back when a sale was actually paid (receipt /
    /// success) so the caller can record it; nil for non-sale dismissals like
    /// closing a restricted-action request.
    let onCompleted: (_ paidOrder: FrozenOrder?) -> Void
    /// Fired once, the moment the order is finalized (invoice issued, receipt
    /// shown) — before the associate taps Done. This is what actually records the
    /// sale (stock, Sales/SalesItem, receipt, purchase history) so nothing is lost
    /// if the receipt is dismissed without tapping Done. Carries the payment summary
    /// (tender used, amount paid) so the receipt row can store it.
    let onOrderFinalized: (_ finalizedOrder: FrozenOrder, _ payment: PaymentSummary) -> Void

    init(
        products: [SalesProduct],
        session: SellingSessionState,
        fulfillment: PaymentFulfillmentSummary,
        onExit: @escaping () -> Void,
        onCompleted: @escaping (_ paidOrder: FrozenOrder?) -> Void,
        onOrderFinalized: @escaping (_ finalizedOrder: FrozenOrder, _ payment: PaymentSummary) -> Void = { _, _ in }
    ) {
        let order = PaymentOrderBuilder.build(products: products, session: session, fulfillment: fulfillment)
        _model = StateObject(wrappedValue: PaymentFlowModel(order: order))
        self.onExit = onExit
        self.onCompleted = onCompleted
        self.onOrderFinalized = onOrderFinalized
    }

    var body: some View {
        VStack(spacing: 16) {
            header

            if showsSummaryBar {
                OrderSummaryBar(
                    totalPaise: model.order.totalPaise,
                    paidPaise: model.paidPaise,
                    remainingPaise: model.remainingPaise
                )
            }

            stageView
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear {
            guard !started else { return }
            started = true
            model.start()
        }
        // Record the sale as soon as the order finalizes (receipt/success), not on
        // Done — so it persists even if the associate closes the receipt.
        .onChange(of: model.stage) { _, newStage in
            guard !hasRecordedSale, newStage == .receipt || newStage == .success else { return }
            hasRecordedSale = true
            // Defer to the next run-loop tick so the heavy recording work (stock
            // decrement, Supabase calls) and the parent @State
            // mutations it triggers don't run *inside* this stage-change transaction.
            // Doing it inline can interrupt the completing→receipt view swap and
            // strand the "completing" spinner even though the model reached .receipt.
            let finalizedOrder = model.order
            let payment = model.paymentSummary
            DispatchQueue.main.async {
                onOrderFinalized(finalizedOrder, payment)
            }
        }
    }

    // MARK: Header + demo controls

    private var header: some View {
        HStack(spacing: 12) {
            Button(action: onExit) {
                Image(systemName: "xmark")
                    .font(.headline.weight(.black))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 44, height: 44)
                    .background(.white.opacity(0.72), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close payment")

            VStack(alignment: .leading, spacing: 2) {
                Text("Payment")
                    .font(.title.weight(.black))
                    .foregroundStyle(Theme.ink)
                Text("Order \(model.order.orderID) · \(model.order.clientName)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.muted)
            }

            Spacer()

            demoMenu
        }
    }

    private var demoMenu: some View {
        Menu {
            Picker("Outcome", selection: $model.scenario) {
                ForEach(DemoScenario.allCases) { scenario in
                    Text(scenario.rawValue).tag(scenario)
                }
            }
            Divider()
            Toggle("Interstate (IGST)", isOn: Binding(
                get: { model.isInterstate },
                set: { model.setInterstate($0) }
            ))
            Toggle("Business buyer (B2B)", isOn: Binding(
                get: { model.order.buyerType.isBusiness },
                set: { model.setBusinessBuyer($0) }
            ))
            Divider()
            Toggle("Live Razorpay checkout", isOn: $model.useLiveGateway)
        } label: {
            Label("Demo", systemImage: "slider.horizontal.3")
                .font(.subheadline.weight(.black))
                .foregroundStyle(Theme.gold)
                .padding(.horizontal, 13)
                .padding(.vertical, 9)
                .background(Theme.selected, in: Capsule())
        }
        .accessibilityLabel("Demo controls")
    }

    private var showsSummaryBar: Bool {
        switch model.stage {
        case .creatingOrder, .orderCreateFailed, .reservationExpired, .receipt:
            return false
        default:
            return true
        }
    }

    // MARK: Stage → screen

    @ViewBuilder
    private var stageView: some View {
        switch model.stage {
        case .creatingOrder:
            CreatingOrderView()
        case .orderCreateFailed:
            OrderCreateFailedView(model: model, onExit: onExit)
        case .methodSelect:
            MethodSelectView(model: model)
        case .aboveCap:
            AboveCapView(model: model)
        case .gstinCapture:
            GSTINCaptureView(model: model)
        case .upiQR:
            UPIQRView(model: model)
        case .qrExpired:
            QRExpiredView(model: model)
        case .hostedCheckout:
            HostedCheckoutView(model: model)
        case .splitConfig:
            SplitConfigView(model: model)
        case .splitCardPaidQRPending:
            SplitCardPaidView(model: model)
        case .cashEntry:
            CashEntryView(model: model)
        case .manualPOS:
            ManualPOSView(model: model)
        case .verifying:
            VerifyingView(model: model, stillChecking: false)
        case .stillChecking:
            VerifyingView(model: model, stillChecking: true)
        case .statusUnknown:
            StatusUnknownView(model: model)
        case .anomalousCredit:
            AnomalousCreditView(model: model)
        case .overpaid:
            OverpaidView(model: model)
        case .partiallyPaid:
            PartiallyPaidView(model: model)
        case .completing:
            CompletingView(model: model)
        case .finalizeNeedsAttention:
            FinalizeAttentionView(model: model)
        case .success:
            SuccessView(model: model, onDone: { onCompleted(model.order) })
        case .receipt:
            ReceiptView(order: model.order, paidPaise: model.paidPaise, onDone: { onCompleted(model.order) })
        case .refundFailed:
            RefundFailedView(model: model)
        case .reservationExpired:
            ReservationExpiredView(model: model, onExit: onExit)
        case .restrictedRequest:
            RestrictedRequestView(model: model, onDone: { onCompleted(model.hasSuccessfulTender ? model.order : nil) })
        }
    }
}
