import SwiftUI

// stock screen
enum StockWorkspaceMode: String, CaseIterable, Identifiable {
    case stock = "Stock"
    case issue = "Issue"
    case scanStock = "Scan Stock"
    case smReview = "SM Review"

    var id: String { rawValue }
}

// there are products listed in the stock
struct StockContent: View {
    let dashboard: StockDashboard
    let products: [SalesProduct]

    @State private var selectedMode: StockWorkspaceMode = .stock
    @State private var stockQuery = ""
    @State private var selectedIssueTypeID: String
    @State private var issueNotes = ""

    init(dashboard: StockDashboard, products: [SalesProduct]) {
        self.dashboard = dashboard
        self.products = products
        _selectedIssueTypeID = State(initialValue: dashboard.issueTypes.first?.id ?? "")
    }

    private var filteredProducts: [SalesProduct] {
        let searchTerm = stockQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !searchTerm.isEmpty else { return products }
        return products.filter { $0.matches(searchTerm) }
    }

    private var selectedIssueType: StockIssueType {
        dashboard.issueTypes.first(where: { $0.id == selectedIssueTypeID }) ?? dashboard.issueTypes[0]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                StockHeader()

                Card {
                    VStack(alignment: .leading, spacing: 18) {
                        StockModePicker(selectedMode: $selectedMode)

                        switch selectedMode {
                        case .stock:
                            StockOverviewPane(
                                metrics: dashboard.metrics,
                                products: filteredProducts,
                                query: $stockQuery
                            )
                        case .issue:
                            StockReceivingIssuePane(
                                issueTypes: dashboard.issueTypes,
                                selectedIssueTypeID: $selectedIssueTypeID,
                                selectedIssueType: selectedIssueType,
                                notes: $issueNotes
                            )
                        case .scanStock:
                            StockScanPane(
                                product: products.first,
                                checks: dashboard.scanChecks
                            )
                        case .smReview:
                            StoreManagerReviewPane(reviews: dashboard.reviews)
                        }
                    }
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 22)
        }
        .scrollIndicators(.hidden)
        .animation(.snappy(duration: 0.24), value: selectedMode)
    }
}

// stock header
private struct StockHeader: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Stock")
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// from where we select the mode in stock
private struct StockModePicker: View {
    @Binding var selectedMode: StockWorkspaceMode

    var body: some View {
        HStack(spacing: 6) {
            ForEach(StockWorkspaceMode.allCases) { mode in
                Button {
                    selectedMode = mode
                } label: {
                    Text(mode.rawValue)
                        .font(.subheadline.weight(.black))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .foregroundStyle(selectedMode == mode ? Theme.gold : Theme.muted)
                        .background(
                            selectedMode == mode ? AnyShapeStyle(Theme.selected) : AnyShapeStyle(Color.clear),
                            in: Capsule()
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(6)
        .background(.white.opacity(0.76), in: Capsule())
        .overlay(
            Capsule()
                .stroke(Theme.line.opacity(0.55), lineWidth: 1)
        )
    }
}

// form here we can look into the stock overview
private struct StockOverviewPane: View {
    let metrics: [StockMetric]
    let products: [SalesProduct]
    @Binding var query: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            StockMetricStrip(metrics: metrics)

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Stock Visibility")
                        .font(.title2.weight(.black))
                    Text("View Store Manager synced stock status")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.muted)
                }

                Spacer()

                Text("SM synced")
                    .font(.caption.weight(.black))
                    .foregroundStyle(Theme.gold)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 8)
                    .background(Theme.selected, in: Capsule())
            }

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Theme.muted)

                TextField("Search SKU or product name", text: $query)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.search)

                if !query.isEmpty {
                    Button {
                        query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Theme.muted.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                }
            }
            .font(.headline.weight(.semibold))
            .padding(.horizontal, 15)
            .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
            .background(.white.opacity(0.68), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Theme.line.opacity(0.55), lineWidth: 1)
            )

            if products.isEmpty {
                EmptyStockState()
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(products) { product in
                        StockProductRow(product: product)
                    }
                }
            }
        }
    }
}

private struct StockMetricStrip: View {
    let metrics: [StockMetric]

    var body: some View {
        HStack(spacing: 12) {
            ForEach(metrics) { metric in
                VStack(alignment: .leading, spacing: 6) {
                    Text(metric.title.uppercased())
                        .font(.caption.weight(.black))
                        .tracking(1.1)
                        .foregroundStyle(Theme.muted)
                    Text(metric.value)
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .foregroundStyle(Theme.ink)
                    Text(metric.detail)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.muted)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, minHeight: 98, alignment: .leading)
                .padding(.horizontal, 16)
                .background(.white.opacity(0.62), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Theme.line.opacity(0.55), lineWidth: 1)
                )
            }
        }
    }
}

private struct StockProductRow: View {
    let product: SalesProduct

    private var statusIcon: String {
        product.availability == "In boutique" ? "checkmark.seal" : "clock.badge"
    }

    var body: some View {
        HStack(spacing: 14) {
            ProductImageView(imageName: product.imageName)
                .frame(width: 88, height: 74)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(product.name)
                        .font(.headline.weight(.black))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)

                    Text(product.id)
                        .font(.caption.weight(.black))
                        .foregroundStyle(Theme.gold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Theme.selected, in: Capsule())

                    if !product.existsInDB {
                        Text("Not in DB")
                            .font(.system(size: 9, weight: .black))
                            .foregroundStyle(.red)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Color.red.opacity(0.12), in: Capsule())
                    }
                }

                Text(product.stockNote)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.muted)
                    .lineLimit(2)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                Label(product.availability, systemImage: statusIcon)
                    .font(.caption.weight(.black))
                    .foregroundStyle(Theme.gold)
                    .lineLimit(1)

                Text(product.isInStock ? "\(product.stockQuantity) in stock" : "Out of stock")
                    .font(.caption.weight(.black))
                    .foregroundStyle(product.isInStock ? Theme.ink : .red)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        product.isInStock ? AnyShapeStyle(Theme.selected) : AnyShapeStyle(Color.red.opacity(0.12)),
                        in: Capsule()
                    )
            }
        }
        .padding(12)
        .background(.white.opacity(0.56), in: RoundedRectangle(cornerRadius: 23, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 23, style: .continuous)
                .stroke(Theme.line.opacity(0.45), lineWidth: 1)
        )
    }
}

private struct StockReceivingIssuePane: View {
    let issueTypes: [StockIssueType]
    @Binding var selectedIssueTypeID: String
    let selectedIssueType: StockIssueType
    @Binding var notes: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Stock Issue")
                        .font(.title2.weight(.black))
                    Text("Report missing, damaged, or mismatched received inventory to Store Manager")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.muted)
                }

                Spacer()

                Text("SM route")
                    .font(.caption.weight(.black))
                    .foregroundStyle(Theme.gold)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 8)
                    .background(Theme.selected, in: Capsule())
            }

            StockIssueDropdown(
                issueTypes: issueTypes,
                selectedIssueTypeID: $selectedIssueTypeID,
                selectedIssueType: selectedIssueType
            )

            HStack(alignment: .top, spacing: 14) {
                StockEvidenceUploadTile(
                    title: "Photo",
                    subtitle: "Add received item, box, tag, or damage proof",
                    icon: "camera"
                )

                StockEvidenceUploadTile(
                    title: "Receipt",
                    subtitle: "Attach receiving slip or handoff receipt",
                    icon: "doc.text"
                )
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Notes")
                    .font(.headline.weight(.black))
                Text(selectedIssueType.description)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.muted)
                TextEditor(text: $notes)
                    .scrollContentBackground(.hidden)
                    .padding(10)
                    .frame(minHeight: 150)
                    .background(.white.opacity(0.58), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Theme.line.opacity(0.45), lineWidth: 1)
                    )
                    .overlay(alignment: .topLeading) {
                        if notes.isEmpty {
                            Text("Add what was received, what was expected, and any visible issue...")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.muted.opacity(0.66))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 18)
                        }
                    }
            }
            .frame(maxWidth: .infinity)

            HStack(spacing: 12) {
                Image(systemName: selectedIssueType.icon)
                    .font(.title2.weight(.black))
                    .foregroundStyle(Theme.gold)
                    .frame(width: 52, height: 52)
                    .background(Theme.selected, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text("\(selectedIssueType.title) issue ready")
                        .font(.headline.weight(.black))
                    Text("This goes to Store Manager for review. SA is not creating a reorder or transfer request here.")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(14)
            .background(Theme.selected.opacity(0.55), in: RoundedRectangle(cornerRadius: 20, style: .continuous))

            Button {
            } label: {
                Label("Submit to SM", systemImage: "paperplane")
                    .font(.headline.weight(.black))
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .foregroundStyle(.white)
                    .background(Theme.goldGradient, in: Capsule())
            }
            .buttonStyle(.plain)
        }
    }
}

private struct StockIssueDropdown: View {
    let issueTypes: [StockIssueType]
    @Binding var selectedIssueTypeID: String
    let selectedIssueType: StockIssueType

    var body: some View {
        Menu {
            ForEach(issueTypes) { issueType in
                Button {
                    selectedIssueTypeID = issueType.id
                } label: {
                    Label(issueType.title, systemImage: issueType.icon)
                }
            }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: selectedIssueType.icon)
                    .font(.title3.weight(.black))
                    .foregroundStyle(Theme.gold)
                    .frame(width: 48, height: 48)
                    .background(Theme.selected, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                VStack(alignment: .leading, spacing: 5) {
                    Text("ISSUE TYPE")
                        .font(.caption.weight(.black))
                        .foregroundStyle(Theme.muted)
                    Text(selectedIssueType.title)
                        .font(.title3.weight(.black))
                        .foregroundStyle(Theme.ink)
                    Text(selectedIssueType.description)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.muted)
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: "chevron.down")
                    .font(.headline.weight(.black))
                    .foregroundStyle(Theme.gold)
                    .frame(width: 38, height: 38)
                    .background(.white.opacity(0.72), in: Circle())
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 84)
            .background(.white.opacity(0.62), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Theme.line.opacity(0.45), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct StockEvidenceUploadTile: View {
    let title: String
    let subtitle: String
    let icon: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 42, weight: .black))
                .foregroundStyle(Theme.gold)
                .frame(width: 78, height: 78)
                .background(Theme.selected, in: RoundedRectangle(cornerRadius: 24, style: .continuous))

            Text(title)
                .font(.title3.weight(.black))
            Text(subtitle)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 168)
        .background(.white.opacity(0.58), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Theme.line.opacity(0.48), style: StrokeStyle(lineWidth: 1, dash: [8, 7]))
        )
    }
}

private struct StockScanPane: View {
    let product: SalesProduct?
    let checks: [StockScanCheck]

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(Theme.goldGradient)
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(.white.opacity(0.42), style: StrokeStyle(lineWidth: 2, dash: [12, 10]))
                        .padding(22)
                    Image(systemName: "qrcode.viewfinder")
                        .font(.system(size: 78, weight: .bold))
                        .foregroundStyle(.white.opacity(0.88))
                }
                .frame(height: 306)

                Button {
                } label: {
                    Label("Scan SKU / Certificate", systemImage: "viewfinder")
                        .font(.headline.weight(.black))
                        .frame(maxWidth: .infinity, minHeight: 54)
                        .foregroundStyle(.white)
                        .background(Theme.goldGradient, in: Capsule())
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 12) {
                if let product {
                    HStack(spacing: 12) {
                        ProductImageView(imageName: product.imageName)
                            .frame(width: 82, height: 82)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                        VStack(alignment: .leading, spacing: 5) {
                            Text("Last scanned")
                                .font(.caption.weight(.black))
                                .tracking(1)
                                .foregroundStyle(Theme.muted)
                            Text(product.name)
                                .font(.headline.weight(.black))
                                .foregroundStyle(Theme.ink)
                            Text(product.id)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Theme.gold)
                        }
                    }
                    .padding(12)
                    .background(Theme.selected.opacity(0.58), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                }

                ForEach(checks) { check in
                    StockScanCheckRow(check: check)
                }

                Button {
                } label: {
                    Label("Save Scan Record", systemImage: "checkmark.circle")
                        .font(.headline.weight(.black))
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .foregroundStyle(Theme.ink)
                        .background(.white.opacity(0.70), in: Capsule())
                }
                .buttonStyle(.plain)
            }
            .frame(width: 330)
        }
    }
}

private struct StockScanCheckRow: View {
    let check: StockScanCheck

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: check.icon)
                .font(.headline.weight(.black))
                .foregroundStyle(Theme.gold)
                .frame(width: 42, height: 42)
                .background(Theme.selected, in: RoundedRectangle(cornerRadius: 15, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(check.title)
                    .font(.headline.weight(.black))
                Text(check.status)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.muted)
            }

            Spacer()
        }
        .padding(12)
        .background(.white.opacity(0.58), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct StoreManagerReviewPane: View {
    let reviews: [StoreManagerReview]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Store Manager Review")
                        .font(.title2.weight(.black))
                    Text("Track what SM decided after issue submission")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.muted)
                }

                Spacer()

                Text("\(reviews.count) updates")
                    .font(.caption.weight(.black))
                    .foregroundStyle(Theme.gold)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 8)
                    .background(Theme.selected, in: Capsule())
            }

            ForEach(reviews) { review in
                HStack(spacing: 14) {
                    Image(systemName: review.icon)
                        .font(.headline.weight(.black))
                        .foregroundStyle(Theme.gold)
                        .frame(width: 48, height: 48)
                        .background(Theme.selected, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(review.title)
                                .font(.headline.weight(.black))
                            Spacer()
                            Text(review.time)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Theme.muted)
                        }
                        Text(review.status)
                            .font(.subheadline.weight(.black))
                            .foregroundStyle(Theme.gold)
                        Text(review.note)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.muted)
                    }
                }
                .padding(14)
                .background(.white.opacity(0.58), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Theme.line.opacity(0.45), lineWidth: 1)
                )
            }
        }
    }
}

private struct EmptyStockState: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "shippingbox")
                .font(.title.weight(.bold))
                .foregroundStyle(Theme.gold)
            Text("No stock record found")
                .font(.headline.weight(.bold))
            Text("Try another product name or SKU.")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity, minHeight: 240)
    }
}
