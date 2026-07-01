//
//  PaymentComponents.swift
//  Sales Associate
//
//  Reusable building blocks for the payment flow, composed before the screens.
//  Status colour is always paired with a distinct icon (accessibility H1/H4).
//

import SwiftUI

// MARK: - Palette

/// Status tones. Each pairs a hue with a required icon so colour is never the
/// only signal (colour-blind / gold-vs-amber safety).
enum PaymentTone {
    case neutral, info, success, warning, danger, gold

    var color: Color {
        switch self {
        case .neutral: return Theme.muted
        case .info: return Color(red: 0.20, green: 0.45, blue: 0.85)
        case .success: return Color(red: 0.16, green: 0.55, blue: 0.30)
        case .warning: return Color(red: 0.82, green: 0.55, blue: 0.10)
        case .danger: return Color(red: 0.75, green: 0.22, blue: 0.20)
        case .gold: return Theme.gold
        }
    }

    var defaultIcon: String {
        switch self {
        case .neutral: return "circle"
        case .info: return "clock.arrow.circlepath"
        case .success: return "checkmark.seal.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .danger: return "xmark.octagon.fill"
        case .gold: return "sparkles"
        }
    }
}

// MARK: - Scaffold

/// Consistent Card + header used by every payment screen.
struct PaymentScaffold<Content: View>: View {
    let title: String
    var subtitle: String? = nil
    var onBack: (() -> Void)? = nil
    @ViewBuilder var content: () -> Content

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 14) {
                    if let onBack {
                        Button(action: onBack) {
                            Image(systemName: "chevron.left")
                                .font(.headline.weight(.black))
                                .foregroundStyle(Theme.ink)
                                .frame(width: 44, height: 44)
                                .background(.white.opacity(0.72), in: Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Back")
                    }

                    VStack(alignment: .leading, spacing: 5) {
                        Text(title)
                            .font(.title2.weight(.black))
                            .foregroundStyle(Theme.ink)
                        if let subtitle {
                            Text(subtitle)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.muted)
                        }
                    }
                    Spacer(minLength: 0)
                }

                content()
            }
            .frame(maxWidth: .infinity, minHeight: 560, alignment: .topLeading)
        }
    }
}

// MARK: - Order summary bar

struct OrderSummaryBar: View {
    let totalPaise: Int
    let paidPaise: Int
    let remainingPaise: Int

    var body: some View {
        HStack(spacing: 0) {
            column("Total", totalPaise, tone: Theme.ink)
            divider
            column("Paid", paidPaise, tone: PaymentTone.success.color)
            divider
            column("Remaining", remainingPaise, tone: remainingPaise == 0 ? PaymentTone.success.color : Theme.gold)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 8)
        .background(.white.opacity(0.62), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.line.opacity(0.5), lineWidth: 1))
    }

    private func column(_ label: String, _ paise: Int, tone: Color) -> some View {
        VStack(spacing: 5) {
            Text(label.uppercased())
                .font(.caption2.weight(.black))
                .foregroundStyle(Theme.muted)
            Text(IndianMoney.format(paise: paise))
                .font(.headline.weight(.black))
                .monospacedDigit()
                .foregroundStyle(tone)
        }
        .frame(maxWidth: .infinity)
    }

    private var divider: some View {
        Rectangle().fill(Theme.line.opacity(0.5)).frame(width: 1, height: 34)
    }
}

// MARK: - Status card

struct PaymentStatusCard: View {
    let tone: PaymentTone
    var icon: String? = nil
    let title: String
    let message: String
    var isBusy: Bool = false

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(tone.color.opacity(0.14))
                    .frame(width: 92, height: 92)
                if isBusy {
                    ProgressView()
                        .controlSize(.large)
                        .tint(tone.color)
                } else {
                    Image(systemName: icon ?? tone.defaultIcon)
                        .font(.system(size: 40, weight: .black))
                        .foregroundStyle(tone.color)
                }
            }

            Text(title)
                .font(.title3.weight(.black))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
            Text(message)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 26)
        .padding(.horizontal, 18)
        .background(.white.opacity(0.5), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(message)")
    }
}

// MARK: - Method card

struct PaymentMethodCard: View {
    let method: PaymentMethodKind
    var isDisabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: method.symbol)
                    .font(.title2.weight(.black))
                    .foregroundStyle(isDisabled ? Theme.muted : Theme.gold)
                    .frame(width: 54, height: 54)
                    .background(Theme.selected.opacity(isDisabled ? 0.4 : 0.9), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(method.rawValue)
                        .font(.headline.weight(.black))
                        .foregroundStyle(Theme.ink)
                    Text(method.subtitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.black))
                    .foregroundStyle(Theme.muted)
            }
            .padding(14)
            .background(.white.opacity(0.58), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Theme.line.opacity(0.45), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.55 : 1)
    }
}

// MARK: - Tender progress

struct TenderProgressRow: View {
    let tender: PaymentTender

    private var tone: PaymentTone {
        switch tender.status {
        case .successful: return .success
        case .pending: return .info
        case .failed: return .danger
        }
    }

    private var statusText: String {
        switch tender.status {
        case .successful: return "Paid"
        case .pending: return "Pending"
        case .failed: return "Failed"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: tender.method.symbol)
                .font(.headline.weight(.black))
                .foregroundStyle(Theme.gold)
                .frame(width: 40, height: 40)
                .background(Theme.selected, in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(tender.method.rawValue)
                    .font(.subheadline.weight(.black))
                    .foregroundStyle(Theme.ink)
                if let reference = tender.reference {
                    Text("Ref \(reference)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.muted)
                }
            }

            Spacer()

            Text(IndianMoney.format(paise: tender.amountPaise))
                .font(.subheadline.weight(.black))
                .monospacedDigit()
                .foregroundStyle(Theme.ink)

            Label(statusText, systemImage: tender.status == .successful ? "checkmark.circle.fill" : "clock")
                .labelStyle(.iconOnly)
                .font(.subheadline.weight(.black))
                .foregroundStyle(tone.color)
        }
        .padding(12)
        .background(.white.opacity(0.5), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - Countdown pill

struct CountdownPill: View {
    let closeBy: Date
    var label: String = "Expires in"

    var body: some View {
        // Fully qualified: the Inventory module defines its own `TimelineView`.
        SwiftUI.TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = max(0, Int(closeBy.timeIntervalSince(context.date)))
            let minutes = remaining / 60
            let seconds = remaining % 60
            let tone: PaymentTone = remaining <= 30 ? .danger : (remaining <= 90 ? .warning : .gold)

            HStack(spacing: 7) {
                Image(systemName: "timer")
                    .font(.subheadline.weight(.black))
                Text("\(label) \(minutes):\(String(format: "%02d", seconds))")
                    .font(.subheadline.weight(.black))
                    .monospacedDigit()
            }
            .foregroundStyle(tone.color)
            .padding(.horizontal, 13)
            .padding(.vertical, 8)
            .background(tone.color.opacity(0.12), in: Capsule())
            .accessibilityLabel("\(label) \(minutes) minutes \(seconds) seconds")
        }
    }
}

// MARK: - Mock QR

/// A deterministic pseudo-QR rendered natively (no external library). It is a
/// display placeholder — not a scannable payload.
struct MockQRCode: View {
    let seed: String
    var moduleCount: Int = 25

    var body: some View {
        Canvas { context, size in
            let modules = pattern()
            let cell = size.width / CGFloat(moduleCount)
            for row in 0..<moduleCount {
                for col in 0..<moduleCount {
                    guard modules[row][col] else { continue }
                    let rect = CGRect(x: CGFloat(col) * cell, y: CGFloat(row) * cell, width: cell, height: cell)
                    context.fill(Path(rect), with: .color(Theme.ink))
                }
            }
        }
        .background(.white)
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }

    private func pattern() -> [[Bool]] {
        var rng = seededValue(seed)
        var grid = Array(repeating: Array(repeating: false, count: moduleCount), count: moduleCount)
        for r in 0..<moduleCount {
            for c in 0..<moduleCount {
                rng = (rng &* 1103515245 &+ 12345) & 0x7fffffff
                grid[r][c] = (rng % 100) < 46
            }
        }
        // Finder-eye squares in three corners for a QR-like look.
        for corner in [(0, 0), (0, moduleCount - 7), (moduleCount - 7, 0)] {
            for r in 0..<7 {
                for c in 0..<7 {
                    let onBorder = r == 0 || r == 6 || c == 0 || c == 6
                    let inCore = (2...4).contains(r) && (2...4).contains(c)
                    grid[corner.0 + r][corner.1 + c] = onBorder || inCore
                }
            }
        }
        return grid
    }

    private func seededValue(_ string: String) -> UInt64 {
        var hash: UInt64 = 5381
        for byte in string.utf8 { hash = (hash &* 33) &+ UInt64(byte) }
        return hash & 0x7fffffff
    }
}

// MARK: - Buttons

struct PaymentPrimaryButton: View {
    let title: String
    var systemImage: String? = nil
    var tone: PaymentTone = .gold
    var isEnabled: Bool = true
    let action: () -> Void
    @State private var locked = false

    var body: some View {
        Button {
            guard !locked, isEnabled else { return }   // duplicate-tap lockout
            locked = true
            action()
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 1_200_000_000)
                locked = false
            }
        } label: {
            label
                .font(.headline.weight(.black))
                .frame(maxWidth: .infinity, minHeight: 56)
                .foregroundStyle(.white)
                .background(tone == .gold ? AnyShapeStyle(Theme.goldGradient) : AnyShapeStyle(tone.color), in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.5)
    }

    @ViewBuilder private var label: some View {
        if let systemImage { Label(title, systemImage: systemImage) } else { Text(title) }
    }
}

struct PaymentSecondaryButton: View {
    let title: String
    var systemImage: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            label
                .font(.headline.weight(.black))
                .frame(maxWidth: .infinity, minHeight: 56)
                .foregroundStyle(Theme.ink)
                .background(.white.opacity(0.7), in: Capsule())
                .overlay(Capsule().stroke(Theme.line.opacity(0.5), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder private var label: some View {
        if let systemImage { Label(title, systemImage: systemImage) } else { Text(title) }
    }
}

// MARK: - Demo badge

/// Marks affordances that stand in for the real backend/customer action.
struct DemoBadge: View {
    let text: String

    var body: some View {
        Label(text, systemImage: "wand.and.stars")
            .font(.caption2.weight(.black))
            .foregroundStyle(Theme.muted)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.white.opacity(0.55), in: Capsule())
            .overlay(Capsule().stroke(Theme.line.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [3, 3])))
    }
}
