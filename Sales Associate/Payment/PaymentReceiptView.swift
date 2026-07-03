//
//  PaymentReceiptView.swift
//  Sales Associate
//
//  The GST tax invoice (PAY-11 / PAY-11B). Adapts to buyer type (B2C / B2B) and
//  place of supply (CGST+SGST vs IGST). Invoice number + IRN come from the
//  backend at finalize; the e-invoice signed QR is kept clearly separate from
//  the UPI payment QR.
//

import SwiftUI

struct ReceiptView: View {
    let order: FrozenOrder
    let paidPaise: Int
    /// Invoice date to print; when nil the current date is used (live checkout).
    var invoiceDate: String? = nil
    let onDone: () -> Void

    // Supplier (the boutique) — fixed for this store.
    private let supplierName = "Luxe Maison Retail Pvt. Ltd."
    private let supplierAddress = "Ground Floor, Regalia Arcade, South Mumbai, Maharashtra 400021"
    private let supplierGSTIN = "27AABCL1234M1Z5"

    var body: some View {
        Card {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    Divider().overlay(Theme.line)
                    supplierBlock
                    invoiceMetaBlock
                    buyerBlock
                    Divider().overlay(Theme.line)
                    lineItemsBlock
                    taxSummaryBlock
                    footerBlock
                    PaymentPrimaryButton(title: "Done", systemImage: "checkmark", action: onDone)
                        .padding(.top, 4)
                }
                .padding(.bottom, 8)
            }
            .scrollIndicators(.hidden)
            .frame(maxWidth: .infinity, minHeight: 560, alignment: .top)
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Tax Invoice")
                    .font(.title.weight(.black))
                    .foregroundStyle(Theme.ink)
                Text("Original for recipient")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.muted)
            }
            Spacer()
            Label(order.buyerType.isBusiness ? "B2B" : "B2C", systemImage: "building.2")
                .font(.caption.weight(.black))
                .foregroundStyle(Theme.gold)
                .padding(.horizontal, 11).padding(.vertical, 6)
                .background(Theme.selected, in: Capsule())
        }
    }

    private var supplierBlock: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(supplierName).font(.headline.weight(.black)).foregroundStyle(Theme.ink)
            Text(supplierAddress).font(.caption.weight(.semibold)).foregroundStyle(Theme.muted)
            Text("GSTIN: \(supplierGSTIN)").font(.caption.weight(.black)).foregroundStyle(Theme.ink)
        }
    }

    private var invoiceMetaBlock: some View {
        VStack(spacing: 8) {
            metaRow("Invoice no.", order.invoiceNumber ?? "—")
            metaRow("Invoice date", serverDateString)
            metaRow("Place of supply", "\(order.placeOfSupply.stateName) (\(order.placeOfSupply.stateCode))")
            metaRow("Fulfillment", order.fulfillment.label)
        }
        .padding(12)
        .background(.white.opacity(0.5), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var buyerBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Billed to").font(.caption2.weight(.black)).foregroundStyle(Theme.muted)
            Text(buyerName).font(.subheadline.weight(.black)).foregroundStyle(Theme.ink)
            Text(order.clientPhone).font(.caption.weight(.semibold)).foregroundStyle(Theme.muted)
            if case let .b2b(gstin, _) = order.buyerType {
                Text("Recipient GSTIN: \(gstin)").font(.caption.weight(.black)).foregroundStyle(Theme.ink)
            } else if order.totalPaise >= 50_000_00 {
                // Unregistered recipient ≥ ₹50,000 must carry name + state (Rule 46).
                Text("State: \(order.placeOfSupply.stateName) (\(order.placeOfSupply.stateCode))")
                    .font(.caption.weight(.semibold)).foregroundStyle(Theme.muted)
            }
        }
    }

    private var buyerName: String {
        if case let .b2b(_, legalName) = order.buyerType { return legalName }
        return order.clientName
    }

    // MARK: Line items

    private var lineItemsBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Items").font(.caption2.weight(.black)).foregroundStyle(Theme.muted)
            ForEach(order.lineItems) { item in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(item.name).font(.subheadline.weight(.black)).foregroundStyle(Theme.ink)
                        Spacer()
                        Text(IndianMoney.format(paise: item.grossInclusivePaise, showsPaise: true))
                            .font(.subheadline.weight(.black)).monospacedDigit().foregroundStyle(Theme.ink)
                    }
                    HStack(spacing: 12) {
                        tag("HSN \(item.classification.hsn)")
                        tag("\(item.quantity) \(item.classification.unitOfMeasure)")
                        tag("GST \(Int((item.classification.rate * 100).rounded()))%")
                        Spacer()
                        Text("Taxable \(IndianMoney.format(paise: item.taxablePaise, showsPaise: true))")
                            .font(.caption2.weight(.bold)).foregroundStyle(Theme.muted)
                    }
                }
                .padding(12)
                .background(.white.opacity(0.5), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }

    // MARK: Tax summary

    private var taxSummaryBlock: some View {
        VStack(spacing: 8) {
            amountRow("Taxable value", order.taxablePaise)
            if order.treatment == .intraState {
                amountRow("CGST", order.cgstPaise)
                amountRow("SGST", order.sgstPaise)
            } else {
                amountRow("IGST", order.igstPaise)
            }
            Divider().overlay(Theme.line)
            amountRow("Total (incl. GST)", order.totalPaise, emphasised: true)
        }
        .padding(12)
        .background(Theme.selected.opacity(0.5), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var footerBlock: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Authorized signatory").font(.caption2.weight(.black)).foregroundStyle(Theme.muted)
                Text("For \(supplierName)").font(.caption.weight(.bold)).foregroundStyle(Theme.ink)
                Image(systemName: "signature").font(.title3).foregroundStyle(Theme.gold)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("Amount received").font(.caption2.weight(.black)).foregroundStyle(Theme.muted)
                Text(IndianMoney.format(paise: paidPaise))
                    .font(.headline.weight(.black)).monospacedDigit().foregroundStyle(PaymentTone.success.color)
            }
        }
    }

    // MARK: Helpers

    private var serverDateString: String {
        if let invoiceDate, !invoiceDate.isEmpty { return invoiceDate }
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM yyyy, HH:mm"
        return formatter.string(from: Date())   // server time in production (F5)
    }

    private func metaRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.caption.weight(.bold)).foregroundStyle(Theme.muted)
            Spacer()
            Text(value).font(.caption.weight(.black)).foregroundStyle(Theme.ink)
                .multilineTextAlignment(.trailing)
        }
    }

    private func amountRow(_ label: String, _ paise: Int, emphasised: Bool = false) -> some View {
        HStack {
            Text(label).font(emphasised ? .subheadline.weight(.black) : .caption.weight(.bold))
                .foregroundStyle(emphasised ? Theme.ink : Theme.muted)
            Spacer()
            Text(IndianMoney.format(paise: paise, showsPaise: true))
                .font(emphasised ? .headline.weight(.black) : .caption.weight(.black))
                .monospacedDigit()
                .foregroundStyle(Theme.ink)
        }
    }

    private func tag(_ text: String) -> some View {
        Text(text)
            .font(.caption2.weight(.black))
            .foregroundStyle(Theme.gold)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(Theme.selected, in: Capsule())
    }
}
