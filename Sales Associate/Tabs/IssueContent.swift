import SwiftUI

//Issue Module Main Screen
enum IssueWorkspaceMode: String, CaseIterable, Identifiable, Equatable {
    case issue = "Issue"
    case pastRequests = "Past Requests"

    var id: String { rawValue }
}

// in this there is option that is avaiable in on the screen
struct IssueContent: View {
    let dashboard: IssueDashboard
    let products: [SalesProduct]

    @State private var selectedMode: IssueWorkspaceMode = .issue
    @State private var selectedIssueTypeID: String
    @State private var issueReason = ""
    @State private var selectedRepairDiagnosis: String
    @State private var selectedRepairServicePrice: String
    @State private var selectedRepairWarranty: String
    @State private var sparePartsCost = "Rs. 0"
    @State private var labourCharge = "Included"

    init(dashboard: IssueDashboard, products: [SalesProduct]) {
        self.dashboard = dashboard
        self.products = products
        _selectedIssueTypeID = State(initialValue: dashboard.issueTypes.first?.id ?? "missing")
        _selectedRepairDiagnosis = State(initialValue: dashboard.repairDiagnosisTypes.first ?? "Inspection pending")
        _selectedRepairServicePrice = State(initialValue: dashboard.repairServicePrices.first ?? "Standard price pending")
        _selectedRepairWarranty = State(initialValue: dashboard.repairWarrantyOptions.first ?? "Warranty check pending")
    }

    private var selectedIssueType: IssueRequestType {
        dashboard.issueTypes.first(where: { $0.id == selectedIssueTypeID })
        ?? dashboard.issueTypes.first
        ?? IssueRequestType(id: "issue", title: "Issue", icon: "exclamationmark.circle", description: "Send issue details to Store Manager.")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                IssueHeader()

                Card {
                    VStack(alignment: .leading, spacing: 18) {
                        IssueModePicker(selectedMode: $selectedMode)

// here are the cases that it direct on the tab that we select
                        switch selectedMode {
                        case .issue:
                            IssueRequestPane(
                                issueTypes: dashboard.issueTypes,
                                selectedIssueType: selectedIssueType,
                                selectedIssueTypeID: $selectedIssueTypeID,
                                reason: $issueReason,
                                repairDiagnosisOptions: dashboard.repairDiagnosisTypes,
                                repairServicePriceOptions: dashboard.repairServicePrices,
                                repairWarrantyOptions: dashboard.repairWarrantyOptions,
                                selectedRepairDiagnosis: $selectedRepairDiagnosis,
                                selectedRepairServicePrice: $selectedRepairServicePrice,
                                selectedRepairWarranty: $selectedRepairWarranty,
                                sparePartsCost: $sparePartsCost,
                                labourCharge: $labourCharge
                            )
                        case .pastRequests:
                            IssueHistoryPane(items: dashboard.historyItems)
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

private struct IssueHeader: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Issue")
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct IssueModePicker: View {
    @Binding var selectedMode: IssueWorkspaceMode

    var body: some View {
        HStack(spacing: 6) {
            ForEach(IssueWorkspaceMode.allCases) { mode in
                Button {
                    selectedMode = mode
                } label: {
                    Text(mode.rawValue)
                        .font(.subheadline.weight(.black))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
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

// this is for returnexchanghe part
private struct IssueRequestPane: View {
    let issueTypes: [IssueRequestType]
    let selectedIssueType: IssueRequestType
    @Binding var selectedIssueTypeID: String
    @Binding var reason: String
    let repairDiagnosisOptions: [String]
    let repairServicePriceOptions: [String]
    let repairWarrantyOptions: [String]
    @Binding var selectedRepairDiagnosis: String
    @Binding var selectedRepairServicePrice: String
    @Binding var selectedRepairWarranty: String
    @Binding var sparePartsCost: String
    @Binding var labourCharge: String

    private var isRepairSelected: Bool {
        selectedIssueType.id == "repair"
    }

    private var reasonPlaceholder: String {
        switch selectedIssueType.id {
        case "missing":
            return "Write what is missing, when it was noticed, and what proof is attached..."
        case "exchange":
            return "Write the exchange reason, client context, and any policy exception required..."
        case "repair":
            return "Write the repair concern, visible damage, client statement, and urgency..."
        default:
            return "Write the service issue, client request, and any visible proof..."
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            IssuePaneTitle(
                title: "Issue Request",
                subtitle: "Send missing, exchange, repair, or service issue details to Store Manager",
                badge: "SM route"
            )

            IssueRequestTypeDropdown(
                issueTypes: issueTypes,
                selectedIssueTypeID: $selectedIssueTypeID,
                selectedIssueType: selectedIssueType
            )

            HStack(alignment: .top, spacing: 14) {
                IssueEvidenceButton(title: "Photo", subtitle: "Add product or issue proof", icon: "camera")
                IssueEvidenceButton(title: "Receipt", subtitle: "Attach purchase or service receipt", icon: "doc.text")
            }

            IssueTextArea(
                title: "Reason",
                placeholder: reasonPlaceholder,
                text: $reason,
                minHeight: isRepairSelected ? 128 : 188
            )

            if isRepairSelected {
                RepairChargeDetailsSection(
                    diagnosisOptions: repairDiagnosisOptions,
                    servicePriceOptions: repairServicePriceOptions,
                    warrantyOptions: repairWarrantyOptions,
                    selectedDiagnosis: $selectedRepairDiagnosis,
                    selectedServicePrice: $selectedRepairServicePrice,
                    selectedWarranty: $selectedRepairWarranty,
                    sparePartsCost: $sparePartsCost,
                    labourCharge: $labourCharge
                )
            }

            IssueGuidanceBanner(
                icon: selectedIssueType.icon,
                title: "\(selectedIssueType.title) request ready",
                subtitle: "Sales Associate captures evidence and reason. Store Manager reviews approval, rejection, or next action."
            )

            IssuePrimaryButton(title: "Submit to SM", icon: "paperplane")
        }
    }
}

// this is for service issue
private struct IssueRequestTypeDropdown: View {
    let issueTypes: [IssueRequestType]
    @Binding var selectedIssueTypeID: String
    let selectedIssueType: IssueRequestType

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

// this is for repair mode
private struct RepairChargeDetailsSection: View {
    let diagnosisOptions: [String]
    let servicePriceOptions: [String]
    let warrantyOptions: [String]
    @Binding var selectedDiagnosis: String
    @Binding var selectedServicePrice: String
    @Binding var selectedWarranty: String
    @Binding var sparePartsCost: String
    @Binding var labourCharge: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "wrench.and.screwdriver")
                    .font(.headline.weight(.black))
                    .foregroundStyle(Theme.gold)
                    .frame(width: 44, height: 44)
                    .background(Theme.selected, in: RoundedRectangle(cornerRadius: 15, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text("Repair Assessment")
                        .font(.headline.weight(.black))
                    Text("Used only when repair is selected")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.muted)
                }
            }

            HStack(spacing: 12) {
                IssueDropdownMenu(
                    title: "Inspection / Diagnosis",
                    options: diagnosisOptions,
                    selection: $selectedDiagnosis
                )
                IssueDropdownMenu(
                    title: "Standard Service Price",
                    options: servicePriceOptions,
                    selection: $selectedServicePrice
                )
            }

            HStack(spacing: 12) {
                IssueTextField(title: "Spare Parts Cost", placeholder: "Add parts cost", text: $sparePartsCost)
                IssueTextField(title: "Labour Charges", placeholder: "Add labour charge", text: $labourCharge)
            }

            IssueDropdownMenu(
                title: "Warranty Check",
                options: warrantyOptions,
                selection: $selectedWarranty
            )

            VStack(alignment: .leading, spacing: 8) {
                RepairRuleRow(text: "Manufacturing defect inside warranty can be free after SM or service-center approval.")
                RepairRuleRow(text: "Accidental damage, broken glass, strap replacement, and model-specific spare parts are chargeable.")
                RepairRuleRow(text: "Final repair amount depends on service price list, spare part price, and labour charges.")
            }
            .padding(14)
            .background(.white.opacity(0.5), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .padding(14)
        .background(Theme.selected.opacity(0.45), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Theme.line.opacity(0.45), lineWidth: 1)
        )
    }
}

private struct RepairRuleRow: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.seal")
                .font(.caption.weight(.black))
                .foregroundStyle(Theme.gold)
                .padding(.top, 2)
            Text(text)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// this is for issue history 
private struct IssueHistoryPane: View {
    let items: [IssueHistoryItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            IssuePaneTitle(
                title: "Past Requests",
                subtitle: "Past requests sent to Store Manager with approval or rejection status",
                badge: "\(items.count) updates"
            )

            LazyVStack(spacing: 12) {
                ForEach(items) { item in
                    IssueHistoryRow(item: item)
                }
            }
        }
    }
}

private struct IssuePaneTitle: View {
    let title: String
    let subtitle: String
    let badge: String

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title2.weight(.black))
                Text(subtitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            Text(badge)
                .font(.caption.weight(.black))
                .foregroundStyle(Theme.gold)
                .padding(.horizontal, 13)
                .padding(.vertical, 8)
                .background(Theme.selected, in: Capsule())
        }
    }
}

private struct IssueDropdownMenu: View {
    let title: String
    let options: [String]
    @Binding var selection: String

    var body: some View {
        Menu {
            ForEach(options, id: \.self) { option in
                Button {
                    selection = option
                } label: {
                    Text(option)
                }
            }
        } label: {
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(title.uppercased())
                        .font(.caption.weight(.black))
                        .tracking(1.1)
                        .foregroundStyle(Theme.muted)
                    Text(selection)
                        .font(.headline.weight(.black))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Image(systemName: "chevron.down")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Theme.gold)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
            .background(.white.opacity(0.62), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Theme.line.opacity(0.55), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct IssueTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title.uppercased())
                .font(.caption.weight(.black))
                .tracking(1.1)
                .foregroundStyle(Theme.muted)

            TextField(placeholder, text: $text)
                .font(.headline.weight(.black))
                .textInputAutocapitalization(.words)
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, minHeight: 70, alignment: .leading)
        .background(.white.opacity(0.62), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Theme.line.opacity(0.55), lineWidth: 1)
        )
    }
}

private struct IssueTextArea: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    let minHeight: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline.weight(.black))

            TextEditor(text: $text)
                .font(.subheadline.weight(.semibold))
                .scrollContentBackground(.hidden)
                .padding(10)
                .frame(minHeight: minHeight)
                .background(.white.opacity(0.58), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Theme.line.opacity(0.45), lineWidth: 1)
                )
                .overlay(alignment: .topLeading) {
                    if text.isEmpty {
                        Text(placeholder)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.muted.opacity(0.66))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 18)
                    }
                }
        }
    }
}

private struct IssueEvidenceButton: View {
    let title: String
    let subtitle: String
    let icon: String

    var body: some View {
        Button {
        } label: {
            VStack(spacing: 11) {
                Image(systemName: icon)
                    .font(.system(size: 32, weight: .black))
                    .foregroundStyle(Theme.gold)
                    .frame(width: 66, height: 66)
                    .background(Theme.selected, in: RoundedRectangle(cornerRadius: 22, style: .continuous))

                VStack(spacing: 4) {
                    Text(title)
                        .font(.title3.weight(.black))
                        .foregroundStyle(Theme.ink)
                    Text(subtitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.muted)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 152)
            .padding(.horizontal, 14)
            .background(.white.opacity(0.58), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Theme.line.opacity(0.48), style: StrokeStyle(lineWidth: 1, dash: [8, 7]))
            )
        }
        .buttonStyle(.plain)
    }
}

private struct IssueProductSummaryCard: View {
    let product: SalesProduct?
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title.uppercased())
                .font(.caption.weight(.black))
                .tracking(1.1)
                .foregroundStyle(Theme.muted)

            if let product {
                ProductImageView(imageName: product.imageName)
                    .frame(height: 176)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

                VStack(alignment: .leading, spacing: 5) {
                    Text(product.name)
                        .font(.title3.weight(.black))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                    Text("\(product.id) • \(product.price)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.muted)
                    Text(product.availability)
                        .font(.caption.weight(.black))
                        .foregroundStyle(Theme.gold)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 7)
                        .background(Theme.selected, in: Capsule())
                }
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "photo")
                        .font(.title.weight(.bold))
                        .foregroundStyle(Theme.gold)
                    Text("No product selected")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(Theme.ink)
                }
                .frame(maxWidth: .infinity, minHeight: 232)
            }
        }
        .padding(14)
        .background(.white.opacity(0.58), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Theme.line.opacity(0.45), lineWidth: 1)
        )
    }
}

private struct IssueGuidanceBanner: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3.weight(.black))
                .foregroundStyle(Theme.gold)
                .frame(width: 48, height: 48)
                .background(Theme.selected, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline.weight(.black))
                    .foregroundStyle(Theme.ink)
                Text(subtitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(14)
        .background(Theme.selected.opacity(0.55), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct IssuePrimaryButton: View {
    let title: String
    let icon: String

    var body: some View {
        Button {
        } label: {
            Label(title, systemImage: icon)
                .font(.headline.weight(.black))
                .frame(maxWidth: .infinity, minHeight: 56)
                .foregroundStyle(.white)
                .background(Theme.goldGradient, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

private struct IssueHistoryRow: View {
    let item: IssueHistoryItem

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: item.icon)
                .font(.headline.weight(.black))
                .foregroundStyle(item.status.tint)
                .frame(width: 50, height: 50)
                .background(item.status.background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline) {
                    Text(item.title)
                        .font(.headline.weight(.black))
                        .foregroundStyle(Theme.ink)
                    Spacer()
                    Text(item.time)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.muted)
                }

                HStack(spacing: 8) {
                    Text(item.requestType)
                        .font(.caption.weight(.black))
                        .foregroundStyle(Theme.muted)
                    Text(item.status.rawValue)
                        .font(.caption.weight(.black))
                        .foregroundStyle(item.status.tint)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(item.status.background, in: Capsule())
                }

                Text(item.note)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
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

private extension IssueApprovalStatus {
    var tint: Color {
        switch self {
        case .approved:
            return Theme.gold
        case .rejected:
            return Color(red: 0.68, green: 0.28, blue: 0.24)
        case .pending:
            return Theme.muted
        }
    }

    var background: Color {
        switch self {
        case .approved:
            return Theme.selected
        case .rejected:
            return Color(red: 0.98, green: 0.88, blue: 0.84)
        case .pending:
            return .white.opacity(0.66)
        }
    }
}
