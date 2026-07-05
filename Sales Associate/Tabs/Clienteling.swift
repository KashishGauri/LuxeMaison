import SwiftUI

struct ClientelingContent: View {
    @Binding var clientProfiles: [ClientProfile]
    let products: [SalesProduct]
    let onStartGuestClient: () -> Void
    let onBuildCuratedCart: (ClientProfile) -> Void

    @Binding var recentlyViewedClients: [ClientProfile]

    @State private var query = ""
    @State private var selectedClient: ClientProfile?
    @State private var missedSearchTerm: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                ClientHeader()

                HStack(alignment: .top, spacing: 18) {
                    if let selectedClient {
                        ClientSearchPanel(
                            query: $query,
                            clients: recentlyViewedClients,
                            selectedClient: $selectedClient,
                            missedSearchTerm: $missedSearchTerm,
                            onSearch: searchExistingClient,
                            onSelectClient: openClientProfile,
                            onStartClient: onStartGuestClient
                        )
                        .frame(width: 318)

                        ClientDetailCard(
                            client: selectedClient,
                            products: products,
                            onBuildCuratedCart: {
                                onBuildCuratedCart(selectedClient)
                            },
                            onUpdateClient: { updatedClient in
                                updateClientProfile(updatedClient)
                            }
                        )
                            .frame(maxWidth: .infinity)
                            .transition(.opacity.combined(with: .move(edge: .trailing)))
                    } else {
                        ClientSearchPanel(
                            query: $query,
                            clients: recentlyViewedClients,
                            selectedClient: $selectedClient,
                            missedSearchTerm: $missedSearchTerm,
                            onSearch: searchExistingClient,
                            onSelectClient: openClientProfile,
                            onStartClient: onStartGuestClient
                        )
                        .frame(maxWidth: .infinity)
                    }
                }
                .animation(.snappy(duration: 0.28), value: selectedClient)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 22)
        }
        .scrollIndicators(.hidden)
    }

//search the existing client
    private func searchExistingClient() {
        let searchTerm = query.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !searchTerm.isEmpty else {
            missedSearchTerm = nil
            return
        }

        guard let match = clientProfiles.first(where: { $0.matches(searchTerm) }) else {
            missedSearchTerm = searchTerm
            return
        }

        missedSearchTerm = nil
        rememberRecentlyViewed(match)
        query = ""
    }

    private func openClientProfile(_ client: ClientProfile) {
        rememberRecentlyViewed(client)
        selectedClient = client
    }

    private func rememberRecentlyViewed(_ client: ClientProfile) {
        recentlyViewedClients.removeAll { $0.id == client.id }
        recentlyViewedClients.insert(client, at: 0)
    }

    private func updateClientProfile(_ updatedClient: ClientProfile) {
        clientProfiles.removeAll { $0.id == updatedClient.id }
        clientProfiles.insert(updatedClient, at: 0)
        rememberRecentlyViewed(updatedClient)
        selectedClient = updatedClient
        
        Task {
            do {
                try await SupabaseDBService.shared.upsertProfile(updatedClient)
            } catch {
                #if DEBUG
                print("Failed to sync updated profile to Supabase: \(error)")
                #endif
            }
        }
    }
}

private struct ClientHeader: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Clienteling")
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ClientSearchPanel: View {
    @Binding var query: String
    let clients: [ClientProfile]
    @Binding var selectedClient: ClientProfile?
    @Binding var missedSearchTerm: String?
    let onSearch: () -> Void
    let onSelectClient: (ClientProfile) -> Void
    let onStartClient: () -> Void

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(Theme.muted)

                    TextField("Search clients, phone, ID", text: $query)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.search)
                        .onSubmit(onSearch)
                        .onChange(of: query) { _, _ in
                            missedSearchTerm = nil
                        }

                    if !query.isEmpty {
                        Button {
                            query = ""
                            missedSearchTerm = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(Theme.muted.opacity(0.7))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .font(.headline.weight(.semibold))
                .padding(.horizontal, 14)
                .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
                .background(.white.opacity(0.70), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Theme.line.opacity(0.55), lineWidth: 1)
                )

                if let missedSearchTerm {
                    NoProfileFoundCard(searchTerm: missedSearchTerm, onStartClient: onStartClient)
                }

                if !clients.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Recently Viewed")
                            .font(.caption.weight(.black))
                            .tracking(1.1)
                            .foregroundStyle(Theme.muted)
                            .padding(.horizontal, 4)

                        ForEach(clients) { client in
                            Button {
                                onSelectClient(client)
                            } label: {
                                ClientResultRow(
                                    client: client,
                                    isSelected: selectedClient == client
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: 490, alignment: .top)
        }
    }
}

// if there is no profile avialable
private struct NoProfileFoundCard: View {
    let searchTerm: String
    let onStartClient: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "person.crop.circle.badge.questionmark")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Theme.gold)
                    .frame(width: 42, height: 42)
                    .background(Theme.selected, in: Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text("No profile found")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(Theme.ink)
                    Text("No client profile matched \(searchTerm).")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.muted)
                }

                Spacer()
            }

            Button(action: onStartClient) {
                Label("Start Client", systemImage: "person.badge.plus")
                    .font(.headline.weight(.bold))
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .foregroundStyle(.white)
                    .background(Theme.goldGradient, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Theme.selected.opacity(0.58), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Theme.line.opacity(0.55), lineWidth: 1)
        )
    }
}

private struct ClientResultRow: View {
    let client: ClientProfile
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            ClientAvatar(initials: client.initials, size: 48)

            VStack(alignment: .leading, spacing: 3) {
                Text(client.name)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                Text(client.tier)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(12)
        .background(isSelected ? Theme.selected : .white.opacity(0.54), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(isSelected ? Theme.line : .clear, lineWidth: 1)
        )
    }
}

private struct ClientDetailCard: View {
    let client: ClientProfile
    let products: [SalesProduct]
    let onBuildCuratedCart: () -> Void
    let onUpdateClient: (ClientProfile) -> Void

    @State private var activeTaskPanel: ClientTaskPanel?

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    private var hasInsightConsent: Bool {
        client.hasClientInsightConsent
    }

    private var visibleAttributes: [ClientAttribute] {
        client.allowsPreferenceVisibility ? client.visiblePreferenceAttributes : []
    }

    private var visibleDefaultDeliveryAddress: String? {
        guard client.allowsPreferenceVisibility else { return nil }

        let address = client.defaultDeliveryAddress?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return address.isEmpty ? nil : address
    }

    private var visibleDeliveryAddressDetail: String? {
        guard client.allowsPreferenceVisibility else { return nil }

        let detail = client.deliveryAddressDetail?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return detail.isEmpty ? nil : detail
    }

    private var wishlistProducts: [SalesProduct] {
        let wishlistIDs = Set(client.wishlistProductIDs)
        return products.filter { wishlistIDs.contains($0.id) }
    }

    var body: some View {
        Card {
            Group {
                switch activeTaskPanel {
                case .consentApproval:
                    ClientConsentApprovalPanel(
                        client: client,
                        onBack: {
                            activeTaskPanel = nil
                        },
                        onSave: updateConsent
                    )
                case .preferences:
                    ClientPreferenceEditPanel(
                        client: client,
                        onBack: {
                            activeTaskPanel = nil
                        },
                        onSave: updatePreferences
                    )
                case nil:
                    overviewContent
                }
            }
            .animation(.snappy(duration: 0.24), value: activeTaskPanel)
        }
    }

    private func updateConsent(
        preferenceVisibilityAllowed: Bool,
        purchaseHistoryAllowed: Bool,
        marketingAllowed: Bool
    ) {
        // Display is driven by the explicit flags below; keep the stored task list
        // coherent so any other consumer (and re-decode) sees matching data.
        let updatedTasks = client.tasks.map { task -> ClientTask in
            let title = task.title.lowercased()
            if title.contains("marketing") {
                return ClientTask(
                    icon: marketingAllowed ? "megaphone.fill" : "bell.slash",
                    title: marketingAllowed ? "Marketing consent on" : "Marketing consent off",
                    subtitle: marketingAllowed
                        ? "Client can receive campaigns by \(client.preferredContactMethod)"
                        : "Do not send marketing campaigns"
                )
            }
            if title.contains("consent") {
                return ClientTask(
                    icon: (preferenceVisibilityAllowed || purchaseHistoryAllowed) ? "checkmark.shield" : "eye.slash",
                    title: "Client insight consent on",
                    subtitle: consentSubtitle(
                        preferenceVisibilityAllowed: preferenceVisibilityAllowed,
                        purchaseHistoryAllowed: purchaseHistoryAllowed
                    )
                )
            }
            return task
        }

        onUpdateClient(
            ClientProfile(
                id: client.id,
                phone: client.phone,
                initials: client.initials,
                name: client.name,
                email: client.email,
                birthday: client.birthday,
                preferredLanguage: client.preferredLanguage,
                preferredContactMethod: client.preferredContactMethod,
                marketingConsent: marketingAllowed,
                preferenceVisibilityConsent: preferenceVisibilityAllowed,
                purchaseHistoryVisibilityConsent: purchaseHistoryAllowed,
                followUpDate: client.followUpDate,
                tier: client.tier,
                lifetimePurchaseAmount: client.lifetimePurchaseAmount,
                boutique: client.boutique,
                status: consentStatus(
                    preferenceVisibilityAllowed: preferenceVisibilityAllowed,
                    purchaseHistoryAllowed: purchaseHistoryAllowed
                ),
                note: client.note,
                attributes: client.attributes,
                tasks: updatedTasks,
                purchaseHistory: client.purchaseHistory,
                wishlistProductIDs: client.wishlistProductIDs,
                defaultDeliveryAddress: client.defaultDeliveryAddress,
                deliveryAddressDetail: client.deliveryAddressDetail
            )
        )
    }

    private func consentSubtitle(
        preferenceVisibilityAllowed: Bool,
        purchaseHistoryAllowed: Bool
    ) -> String {
        switch (preferenceVisibilityAllowed, purchaseHistoryAllowed) {
        case (true, true):
            return "Preferences and purchase history visible"
        case (true, false):
            return "Preferences visible"
        case (false, true):
            return "Purchase history visible"
        case (false, false):
            return "Only identity is visible to sales associate"
        }
    }

    private func consentStatus(
        preferenceVisibilityAllowed: Bool,
        purchaseHistoryAllowed: Bool
    ) -> String {
        switch (preferenceVisibilityAllowed, purchaseHistoryAllowed) {
        case (true, true), (true, false):
            return "Preferences visible"
        case (false, true):
            return "Purchase history visible"
        case (false, false):
            return "Profile created - preferences hidden"
        }
    }

    private func updatePreferences(
        preferredStyle: String,
        budget: String,
        size: String,
        materialPreference: String,
        colorPreference: String,
        preferenceNote: String
    ) {
        let preferenceAttributes = makePreferenceAttributes(
            preferredStyle: preferredStyle,
            budget: budget,
            size: size,
            materialPreference: materialPreference,
            colorPreference: colorPreference
        )

        let replacedTitles = Set(["Size", "Style", "Budget", "Preference", "Color"])
        let retainedAttributes = client.attributes.filter { !replacedTitles.contains($0.title) }
        let note = preferenceNote.trimmingCharacters(in: .whitespacesAndNewlines)
        let summary = preferenceAttributes.map(\.value).joined(separator: ", ")
        let updatedTasks = client.tasks.map { task in
            guard task.title.lowercased().contains("preference") && !task.title.lowercased().contains("consent") else {
                return task
            }

            return ClientTask(
                icon: "heart.fill",
                title: "Preferences saved",
                subtitle: summary.isEmpty ? "Preference details updated" : summary
            )
        }

        onUpdateClient(
            ClientProfile(
                id: client.id,
                phone: client.phone,
                initials: client.initials,
                name: client.name,
                email: client.email,
                birthday: client.birthday,
                preferredLanguage: client.preferredLanguage,
                preferredContactMethod: client.preferredContactMethod,
                marketingConsent: client.marketingConsent,
                preferenceVisibilityConsent: client.preferenceVisibilityConsent,
                purchaseHistoryVisibilityConsent: client.purchaseHistoryVisibilityConsent,
                followUpDate: client.followUpDate,
                tier: client.tier,
                lifetimePurchaseAmount: client.lifetimePurchaseAmount,
                boutique: client.boutique,
                status: client.status,
                note: note,
                attributes: retainedAttributes + preferenceAttributes,
                tasks: updatedTasks,
                purchaseHistory: client.purchaseHistory,
                wishlistProductIDs: client.wishlistProductIDs,
                defaultDeliveryAddress: client.defaultDeliveryAddress,
                deliveryAddressDetail: client.deliveryAddressDetail
            )
        )
    }

    private func makePreferenceAttributes(
        preferredStyle: String,
        budget: String,
        size: String,
        materialPreference: String,
        colorPreference: String
    ) -> [ClientAttribute] {
        var attributes: [ClientAttribute] = []
        appendAttribute("Size", value: size, to: &attributes)
        appendAttribute("Style", value: preferredStyle, to: &attributes)
        appendAttribute("Budget", value: budget, to: &attributes)
        appendAttribute("Preference", value: materialPreference, to: &attributes)
        appendAttribute("Color", value: colorPreference, to: &attributes)
        return attributes
    }

    private func appendAttribute(_ title: String, value: String, to attributes: inout [ClientAttribute]) {
        let resolvedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !resolvedValue.isEmpty && resolvedValue != "N/A" else { return }
        attributes.append(ClientAttribute(title: title, value: resolvedValue))
    }

    private var visibleClientNote: String? {
        let note = client.note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !note.isEmpty else { return nil }

        let generatedNotes = [
            "New client profile created. Preferences pending."
        ]
        let isGeneratedPreferenceNote = note.lowercased().hasPrefix("new client prefers ")

        guard !generatedNotes.contains(note) && !isGeneratedPreferenceNote else {
            return nil
        }

        return note
    }

    /// Single merged consent row shown in "Consent & Tasks" — summarises all three
    /// consents. Marketing, when on, simply shows the contact method.
    private var consentSummaryTask: ClientTask {
        var parts: [String] = []
        if client.allowsPreferenceVisibility { parts.append("Preferences") }
        if client.allowsPurchaseHistoryVisibility { parts.append("Purchase history") }
        if client.marketingConsent { parts.append("Marketing · \(client.preferredContactMethod)") }
        let anyOn = !parts.isEmpty
        return ClientTask(
            icon: anyOn ? "checkmark.shield" : "eye.slash",
            title: "Client consent",
            subtitle: anyOn ? parts.joined(separator: " • ") : "Only identity is visible to sales associate"
        )
    }

    /// Tasks other than the consent / marketing rows (which the single merged
    /// consent row replaces) — i.e. preferences and follow-up.
    private var nonConsentTasks: [ClientTask] {
        client.tasks.filter { task in
            let title = task.title.lowercased()
            return !title.contains("consent") && !title.contains("marketing")
        }
    }

    private var overviewContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 16) {
                ClientAvatar(initials: client.initials, size: 74)

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(client.tier.uppercased())
                            .font(.caption.weight(.black))
                            .tracking(1.2)
                            .foregroundStyle(Theme.gold)
                        if client.tier != "Normal" {
                            Text("VIP")
                                .font(.caption.weight(.black))
                                .foregroundStyle(Theme.gold)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Theme.selected, in: Capsule())
                        }
                    }

                    Text(client.name)
                        .font(.system(size: 36, weight: .black, design: .rounded))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.78)

                    Text("\(client.boutique) • \(client.status.lowercased())")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.muted)
                        .lineLimit(2)
                }

                Spacer()
            }
            .padding(18)
            .background(Theme.selected.opacity(0.72), in: RoundedRectangle(cornerRadius: 26, style: .continuous))

            ClientLoyaltySummary(client: client)

            if !visibleAttributes.isEmpty {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(visibleAttributes) { attribute in
                        ClientAttributeTile(attribute: attribute)
                    }
                }
            } else if !hasInsightConsent {
                ClientRestrictedInsightNotice()
            }

            if let visibleDefaultDeliveryAddress {
                ClientDeliveryAddressCard(
                    address: visibleDefaultDeliveryAddress,
                    detail: visibleDeliveryAddressDetail
                )
            }

            if hasInsightConsent, let visibleClientNote {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Client Note")
                        .font(.headline.weight(.black))
                    Text(visibleClientNote)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.muted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(Theme.selected.opacity(0.65), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            }

            if client.allowsPurchaseHistoryVisibility {
                ClientPurchaseHistorySection(
                    purchases: client.purchaseHistory,
                    products: products,
                    clientName: client.name,
                    clientPhone: client.phone
                )
                ClientWishlistInsightSection(products: wishlistProducts)
            }

            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Consent & Tasks")
                        .font(.title3.weight(.black))
                    Spacer()
                    Text("Protected")
                        .font(.caption.weight(.black))
                        .foregroundStyle(Theme.gold)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 7)
                        .background(Theme.selected, in: Capsule())
                }

                // One merged consent row (preferences + purchase history + marketing).
                ClientTaskRow(task: consentSummaryTask, isActionable: true) {
                    activeTaskPanel = .consentApproval
                }

                ForEach(nonConsentTasks) { task in
                    ClientTaskRow(
                        task: task,
                        isActionable: taskPanel(for: task) != nil
                    ) {
                        activeTaskPanel = taskPanel(for: task)
                    }
                }

                Button(action: onBuildCuratedCart) {
                    Label("Build Curated Cart", systemImage: "bag")
                        .font(.headline.weight(.black))
                        .frame(maxWidth: .infinity, minHeight: 54)
                        .foregroundStyle(.white)
                        .background(Theme.goldGradient, in: Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            .background(.white.opacity(0.56), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Theme.line.opacity(0.55), lineWidth: 1)
            )
        }
    }

    private func taskPanel(for task: ClientTask) -> ClientTaskPanel? {
        let title = task.title.lowercased()

        if title.contains("consent") {
            return .consentApproval
        }

        if title.contains("preference") {
            return .preferences
        }

        return nil
    }
}

private enum ClientTaskPanel: Equatable {
    case consentApproval
    case preferences
}

private struct ClientLoyaltySummary: View {
    let client: ClientProfile

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ClientLoyaltyTile(title: "Tier", value: client.tier, icon: "crown")
            ClientLoyaltyTile(title: "Reward Points", value: client.rewardPointsText, icon: "sparkles")
            ClientLoyaltyTile(title: "Lifetime Purchase", value: client.lifetimePurchaseText, icon: "creditcard")
        }
    }
}

private struct ClientLoyaltyTile: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.headline.weight(.black))
                .foregroundStyle(Theme.gold)
                .frame(width: 42, height: 42)
                .background(Theme.selected, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                Text(title.uppercased())
                    .font(.caption.weight(.black))
                    .tracking(1.1)
                    .foregroundStyle(Theme.muted)
                Text(value)
                    .font(.title3.weight(.black))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 82, alignment: .leading)
        .background(.white.opacity(0.60), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Theme.line.opacity(0.45), lineWidth: 1)
        )
    }
}

private struct ClientAttributeTile: View {
    let attribute: ClientAttribute

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(attribute.title.uppercased())
                .font(.caption.weight(.black))
                .tracking(1.1)
                .foregroundStyle(Theme.muted)
            Text(attribute.value)
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(Theme.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, minHeight: 106, alignment: .leading)
        .padding(16)
        .background(.white.opacity(0.60), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Theme.line.opacity(0.45), lineWidth: 1)
        )
    }
}

private struct ClientDeliveryAddressCard: View {
    let address: String
    let detail: String?

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "location.fill")
                .font(.headline.weight(.black))
                .foregroundStyle(Theme.gold)
                .frame(width: 44, height: 44)
                .background(Theme.selected, in: RoundedRectangle(cornerRadius: 15, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                Text("Default Delivery Address".uppercased())
                    .font(.caption.weight(.black))
                    .tracking(1.1)
                    .foregroundStyle(Theme.muted)

                Text(address)
                    .font(.headline.weight(.black))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)

                if let detail {
                    Text(detail)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.muted)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.60), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Theme.line.opacity(0.45), lineWidth: 1)
        )
    }
}

private struct ClientRestrictedInsightNotice: View {
    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 4) {
                Text("Other preferences are hidden until clients consent")
                    .font(.headline.weight(.black))
                    .foregroundStyle(Theme.ink)
                Text("Purchase history, wishlist, delivery address, style notes, and detailed preferences will appear after consent is captured.")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.muted)
            }
        } icon: {
            Image(systemName: "eye.slash")
                .font(.headline.weight(.black))
                .foregroundStyle(Theme.gold)
                .frame(width: 44, height: 44)
                .background(Theme.selected, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.58), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Theme.line.opacity(0.45), lineWidth: 1)
        )
    }
}

/// One checkout, grouping every item bought together (shared `orderID`).
private struct PurchaseOrderGroup: Identifiable {
    let id: String
    let date: String
    let boutique: String
    let invoiceNumber: String?
    let items: [ClientPurchase]

    var isMultiItem: Bool { items.count > 1 }
    var totalItemCount: Int { items.reduce(0) { $0 + max(1, $1.quantity ?? 1) } }

    /// Sum of the stored line totals; nil when any item predates paise tracking.
    var totalPaise: Int? {
        let paises = items.compactMap { $0.grossPaise }
        guard paises.count == items.count, !paises.isEmpty else { return nil }
        return paises.reduce(0, +)
    }
}

private struct ClientPurchaseHistorySection: View {
    let purchases: [ClientPurchase]
    let products: [SalesProduct]
    let clientName: String
    let clientPhone: String

    @State private var receiptOrder: PurchaseOrderGroup?
    @State private var showsAllOrders = false

    /// The profile shows only the two most recent orders; the rest live behind
    /// the "View all" sheet.
    private var visibleOrders: [PurchaseOrderGroup] { Array(orders.prefix(2)) }

    /// Groups flat purchases into orders, preserving history order (newest first).
    private var orders: [PurchaseOrderGroup] {
        var keyOrder: [String] = []
        var itemsByKey: [String: [ClientPurchase]] = [:]
        for purchase in purchases {
            let key = purchase.orderID ?? purchase.id
            if itemsByKey[key] == nil { keyOrder.append(key) }
            itemsByKey[key, default: []].append(purchase)
        }
        return keyOrder.map { key in
            let items = itemsByKey[key] ?? []
            return PurchaseOrderGroup(
                id: key,
                date: items.first?.purchasedOn ?? "",
                boutique: items.first?.boutique ?? "",
                invoiceNumber: items.first?.invoiceNumber,
                items: items
            )
        }
    }

    var body: some View {
        if !purchases.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Purchase History")
                        .font(.title3.weight(.black))
                    Spacer()
                    if orders.count > 2 {
                        Button {
                            showsAllOrders = true
                        } label: {
                            HStack(spacing: 5) {
                                Text("View all")
                                Image(systemName: "chevron.right")
                            }
                            .font(.caption.weight(.black))
                            .foregroundStyle(Theme.gold)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(Theme.selected, in: Capsule())
                        }
                        .buttonStyle(.plain)
                    } else {
                        Text("\(purchases.count) items")
                            .font(.caption.weight(.black))
                            .foregroundStyle(Theme.gold)
                            .padding(.horizontal, 11)
                            .padding(.vertical, 7)
                            .background(Theme.selected, in: Capsule())
                    }
                }

                ForEach(visibleOrders) { order in
                    PurchaseOrderCard(order: order) {
                        receiptOrder = order
                    }
                }
            }
            .padding(16)
            .background(.white.opacity(0.56), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Theme.line.opacity(0.45), lineWidth: 1)
            )
            .sheet(item: $receiptOrder) { order in
                PurchaseReceiptSheet(
                    order: order,
                    products: products,
                    clientName: clientName,
                    clientPhone: clientPhone,
                    onClose: { receiptOrder = nil }
                )
            }
            .sheet(isPresented: $showsAllOrders) {
                AllPurchaseOrdersSheet(
                    orders: orders,
                    products: products,
                    clientName: clientName,
                    clientPhone: clientPhone,
                    onClose: { showsAllOrders = false }
                )
            }
        }
    }
}

/// Full-height sheet listing every past order, opened from "View all". Holds its
/// own receipt-sheet state so it can present a receipt without colliding with the
/// profile's own receipt sheet.
private struct AllPurchaseOrdersSheet: View {
    let orders: [PurchaseOrderGroup]
    let products: [SalesProduct]
    let clientName: String
    let clientPhone: String
    let onClose: () -> Void

    @State private var receiptOrder: PurchaseOrderGroup?

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Purchase History")
                        .font(.title2.weight(.black))
                        .foregroundStyle(Theme.ink)
                    Text("\(orders.count) orders")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.muted)
                }

                Spacer()

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.headline.weight(.black))
                        .foregroundStyle(Theme.ink)
                        .frame(width: 40, height: 40)
                        .background(.white.opacity(0.72), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
            }
            .padding(20)

            ScrollView {
                VStack(spacing: 12) {
                    ForEach(orders) { order in
                        PurchaseOrderCard(order: order) {
                            receiptOrder = order
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.background)
        .sheet(item: $receiptOrder) { order in
            PurchaseReceiptSheet(
                order: order,
                products: products,
                clientName: clientName,
                clientPhone: clientPhone,
                onClose: { receiptOrder = nil }
            )
        }
    }
}

private struct PurchaseOrderCard: View {
    let order: PurchaseOrderGroup
    let onViewReceipt: () -> Void

    private var headerTitle: String {
        if order.isMultiItem { return "Order · \(order.totalItemCount) items" }
        return itemTitle(order.items.first)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: order.isMultiItem ? "bag.badge.plus" : "bag.fill")
                    .font(.headline.weight(.black))
                    .foregroundStyle(Theme.gold)
                    .frame(width: 42, height: 42)
                    .background(Theme.selected, in: RoundedRectangle(cornerRadius: 15, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(headerTitle)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                    Text("\(order.date) • \(order.boutique)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.muted)
                        .lineLimit(1)
                }

                Spacer()

                Group {
                    if let total = order.totalPaise {
                        Text(IndianMoney.format(paise: total))
                    } else {
                        Text(order.items.first?.price ?? "")
                    }
                }
                .font(.headline.weight(.black))
                .foregroundStyle(Theme.ink)
            }

            // Multi-item orders list their products so grouped items appear together.
            if order.isMultiItem {
                VStack(spacing: 8) {
                    ForEach(order.items) { item in
                        HStack(spacing: 10) {
                            Text("•")
                                .font(.subheadline.weight(.black))
                                .foregroundStyle(Theme.gold)
                            Text(itemTitle(item))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.ink)
                                .lineLimit(1)
                            Spacer()
                            Text(item.price)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(Theme.muted)
                        }
                    }
                }
                .padding(.leading, 4)
            }

            Button(action: onViewReceipt) {
                Label("View Receipt", systemImage: "doc.text")
                    .font(.subheadline.weight(.black))
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .foregroundStyle(Theme.gold)
                    .background(Theme.selected, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(.white.opacity(0.54), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func itemTitle(_ item: ClientPurchase?) -> String {
        guard let item else { return "Order" }
        let quantity = max(1, item.quantity ?? 1)
        return quantity > 1 ? "\(item.productName) × \(quantity)" : item.productName
    }
}

/// Rebuilds a tax invoice from a stored order and shows it in the receipt view.
private struct PurchaseReceiptSheet: View {
    let order: PurchaseOrderGroup
    let products: [SalesProduct]
    let clientName: String
    let clientPhone: String
    let onClose: () -> Void

    var body: some View {
        let frozen = reconstructedOrder
        ReceiptView(
            order: frozen,
            paidPaise: frozen.totalPaise,
            invoiceDate: order.date,
            onDone: onClose
        )
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.background)
    }

    private var reconstructedOrder: FrozenOrder {
        let productsByID = Dictionary(uniqueKeysWithValues: products.map { ($0.id, $0) })
        let lineItems: [PaymentLineItem] = order.items.map { item in
            let quantity = max(1, item.quantity ?? 1)
            let product = productsByID[item.productID]
            let grossPaise = item.grossPaise
                ?? product.map { IndianMoney.paise(fromLakhs: $0.priceValue) * quantity }
                ?? 0
            let classification: GSTClassification
            if let hsn = item.hsn, let rate = item.gstRate {
                classification = GSTClassification(hsn: hsn, unitOfMeasure: "NOS", rate: rate)
            } else if let product {
                classification = GSTClassification.infer(for: product)
            } else {
                classification = GSTClassification(hsn: "9999", unitOfMeasure: "NOS", rate: 0.18)
            }
            return PaymentLineItem(
                id: item.productID,
                name: item.productName,
                brand: product?.brand ?? "",
                imageName: product?.imageName ?? "",
                quantity: quantity,
                classification: classification,
                grossInclusivePaise: grossPaise
            )
        }
        // Rebuild the fulfilment (and tracking id) from what was stored at checkout;
        // legacy orders with no stored fulfilment fall back to pickup.
        let firstItem = order.items.first
        let isDelivery = firstItem?.fulfillmentKind == "delivery"
        let fulfillment = PaymentFulfillmentSummary(
            kind: isDelivery ? .delivery : .pickup,
            address: isDelivery ? firstItem?.deliveryAddress : nil
        )
        return FrozenOrder(
            orderID: order.id,
            lineItems: lineItems,
            placeOfSupply: .supplierState,
            treatment: .intraState,
            buyerType: .b2c,
            fulfillment: fulfillment,
            clientName: clientName,
            clientPhone: clientPhone,
            invoiceNumber: order.invoiceNumber ?? "LM/26-27/\(order.id.suffix(5))",
            trackingID: isDelivery ? firstItem?.trackingID : nil
        )
    }
}

private struct ClientWishlistInsightSection: View {
    let products: [SalesProduct]

    var body: some View {
        if !products.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Wishlist")
                        .font(.title3.weight(.black))
                    Spacer()
                    Text("\(products.count) saved")
                        .font(.caption.weight(.black))
                        .foregroundStyle(Theme.gold)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 7)
                        .background(Theme.selected, in: Capsule())
                }

                ScrollView(.horizontal) {
                    HStack(spacing: 12) {
                        ForEach(products) { product in
                            ClientWishlistProductCard(product: product)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .scrollIndicators(.hidden)
            }
            .padding(16)
            .background(.white.opacity(0.56), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Theme.line.opacity(0.45), lineWidth: 1)
            )
        }
    }
}

private struct ClientWishlistProductCard: View {
    let product: SalesProduct

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ProductImageView(imageName: product.imageName)
                .frame(width: 126, height: 92)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            Text(product.name)
                .font(.subheadline.weight(.black))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)

            Text(product.price)
                .font(.caption.weight(.black))
                .foregroundStyle(Theme.muted)
        }
        .frame(width: 140, alignment: .leading)
        .padding(10)
        .background(.white.opacity(0.58), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Theme.line.opacity(0.45), lineWidth: 1)
        )
    }
}

private struct ClientTaskRow: View {
    let task: ClientTask
    let isActionable: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 13) {
                Image(systemName: task.icon)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Theme.gold)
                    .frame(width: 42, height: 42)
                    .background(Theme.selected, in: RoundedRectangle(cornerRadius: 15, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(task.title)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(Theme.ink)
                    Text(task.subtitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.muted)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(isActionable ? Theme.muted.opacity(0.72) : Theme.muted.opacity(0.24))
            }
        }
        .buttonStyle(.plain)
        .disabled(!isActionable)
        .accessibilityLabel(task.title)
    }
}

struct ClientPanelBackButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
                .font(.headline.weight(.black))
                .foregroundStyle(Theme.ink)
                .frame(width: 44, height: 44)
                .background(.white.opacity(0.72), in: Circle())
                .overlay(
                    Circle()
                        .stroke(Theme.line.opacity(0.45), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Back")
    }
}

private struct ClientConsentApprovalPanel: View {
    let client: ClientProfile
    let onBack: () -> Void
    let onSave: (_ preferenceVisibility: Bool, _ purchaseHistory: Bool, _ marketing: Bool) -> Void

    @State private var preferenceVisibilityAllowed = false
    @State private var purchaseHistoryAllowed = false
    @State private var marketingAllowed = false
    @State private var isSaved = false

    init(
        client: ClientProfile,
        onBack: @escaping () -> Void,
        onSave: @escaping (Bool, Bool, Bool) -> Void
    ) {
        self.client = client
        self.onBack = onBack
        self.onSave = onSave
        // Seed each toggle from its own stored flag so they are independent.
        _preferenceVisibilityAllowed = State(initialValue: client.allowsPreferenceVisibility)
        _purchaseHistoryAllowed = State(initialValue: client.allowsPurchaseHistoryVisibility)
        _marketingAllowed = State(initialValue: client.marketingConsent)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 14) {
                ClientPanelBackButton(action: onBack)

                VStack(alignment: .leading, spacing: 5) {
                    Text("Client Consent")
                        .font(.title2.weight(.black))
                        .foregroundStyle(Theme.ink)
                    Text("Capture the client's approval before showing preferences, purchase history, or sending marketing.")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.muted)
                }

                Spacer()

                Text(isSaved ? "Saved" : "Pending")
                    .font(.caption.weight(.black))
                    .foregroundStyle(Theme.gold)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Theme.selected, in: Capsule())
            }

            HStack(spacing: 14) {
                ClientAvatar(initials: client.initials, size: 58)

                VStack(alignment: .leading, spacing: 4) {
                    Text(client.name)
                        .font(.title3.weight(.black))
                    Text("\(client.phone) • \(client.boutique)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.muted)
                }

                Spacer()
            }
            .padding(16)
            .background(Theme.selected.opacity(0.65), in: RoundedRectangle(cornerRadius: 22, style: .continuous))

            VStack(spacing: 12) {
                ConsentToggleRow(
                    title: "Client allows preference visibility",
                    subtitle: "Style, size, material and budget can be visible in clienteling.",
                    icon: "eye",
                    isOn: $preferenceVisibilityAllowed
                )

                ConsentToggleRow(
                    title: "Client allows purchase history visibility",
                    subtitle: "Past purchases can be used for recommendations and follow-up.",
                    icon: "bag.fill",
                    isOn: $purchaseHistoryAllowed
                )

                ConsentToggleRow(
                    title: "Marketing consent",
                    subtitle: "Client can receive campaigns via \(client.preferredContactMethod).",
                    icon: "megaphone.fill",
                    isOn: $marketingAllowed
                )
            }

            Button {
                onSave(preferenceVisibilityAllowed, purchaseHistoryAllowed, marketingAllowed)
                isSaved = true
            } label: {
                Label(isSaved ? "Consent Captured" : "Capture Consent", systemImage: isSaved ? "checkmark.seal.fill" : "checkmark.shield")
                    .font(.headline.weight(.black))
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .foregroundStyle(.white)
                    .background(Theme.goldGradient, in: Capsule())
            }
            .buttonStyle(.plain)
            // Capturing "all off" is a valid consent state (revocation), so always enabled.
        }
        // Re-enable the button label if the associate flips a toggle after saving.
        .onChange(of: preferenceVisibilityAllowed) { _, _ in isSaved = false }
        .onChange(of: purchaseHistoryAllowed) { _, _ in isSaved = false }
        .onChange(of: marketingAllowed) { _, _ in isSaved = false }
    }
}

private struct ConsentToggleRow: View {
    let title: String
    let subtitle: String
    let icon: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.headline.weight(.black))
                .foregroundStyle(Theme.gold)
                .frame(width: 44, height: 44)
                .background(Theme.selected, in: RoundedRectangle(cornerRadius: 15, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline.weight(.black))
                    .foregroundStyle(Theme.ink)
                Text(subtitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(Theme.gold)
        }
        .padding(14)
        .background(.white.opacity(0.58), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Theme.line.opacity(0.45), lineWidth: 1)
        )
    }
}

private struct ClientPreferenceEditPanel: View {
    let client: ClientProfile
    let onBack: () -> Void
    let onSave: (String, String, String, String, String, String) -> Void

    @State private var preferredStyle: String
    @State private var budget: String
    @State private var size: String
    @State private var materialPreference: String
    @State private var colorPreference: String
    @State private var preferenceNote: String
    @State private var savedSummary: String?

    private let styles = ["N/A", "Minimal", "Statement", "Classic", "Bridal", "Evening"]
    private let budgets = ["N/A", "Rs. 50K+", "Rs. 1L+", "Rs. 2L+", "Rs. 5L+"]
    private let sizes = ["N/A", "EU 36", "EU 38", "EU 40", "One size"]
    private let materials = ["N/A", "Gold hardware", "Silver hardware", "Pearl", "Diamond", "Leather"]

    init(
        client: ClientProfile,
        onBack: @escaping () -> Void,
        onSave: @escaping (String, String, String, String, String, String) -> Void
    ) {
        self.client = client
        self.onBack = onBack
        self.onSave = onSave
        _preferredStyle = State(initialValue: Self.savedAttribute("Style", in: client))
        _budget = State(initialValue: Self.savedAttribute("Budget", in: client))
        _size = State(initialValue: Self.savedAttribute("Size", in: client))
        _materialPreference = State(initialValue: Self.savedAttribute("Preference", in: client))
        _colorPreference = State(initialValue: Self.savedAttribute("Color", in: client, fallback: ""))
        _preferenceNote = State(initialValue: Self.savedNote(in: client))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 14) {
                ClientPanelBackButton(action: onBack)

                VStack(alignment: .leading, spacing: 5) {
                    Text("Add Preferences")
                        .font(.title2.weight(.black))
                        .foregroundStyle(Theme.ink)
                    Text("Capture optional preferences only when client shares them.")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.muted)
                }

                Spacer()

                Text(client.name)
                    .font(.caption.weight(.black))
                    .foregroundStyle(Theme.gold)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Theme.selected, in: Capsule())
            }

            HStack(alignment: .top, spacing: 14) {
                ProfileDropdown(title: "Style", options: styles, selection: $preferredStyle)
                ProfileDropdown(title: "Budget", options: budgets, selection: $budget)
            }

            HStack(alignment: .top, spacing: 14) {
                ProfileDropdown(title: "Size", options: sizes, selection: $size)
                ProfileDropdown(title: "Material", options: materials, selection: $materialPreference)
            }

            ProfileTextField(title: "Color Preference", placeholder: "champagne, black, emerald...", text: $colorPreference)

            VStack(alignment: .leading, spacing: 8) {
                Text("Preference Note")
                    .font(.headline.weight(.black))
                TextEditor(text: $preferenceNote)
                    .scrollContentBackground(.hidden)
                    .padding(10)
                    .frame(minHeight: 130)
                    .background(.white.opacity(0.58), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Theme.line.opacity(0.45), lineWidth: 1)
                    )
                    .overlay(alignment: .topLeading) {
                        if preferenceNote.isEmpty {
                            Text("Add occasion, product interest, dislikes, or follow-up preference...")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.muted.opacity(0.66))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 18)
                        }
                    }
            }

            if let savedSummary {
                Label(savedSummary, systemImage: "checkmark.seal")
                    .font(.subheadline.weight(.black))
                    .foregroundStyle(Theme.gold)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.selected.opacity(0.62), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }

            Button {
                let summary = preferenceSummary
                onSave(preferredStyle, budget, size, materialPreference, colorPreference, preferenceNote)
                savedSummary = summary
            } label: {
                Label("Save Preferences", systemImage: "heart.text.square")
                    .font(.headline.weight(.black))
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .foregroundStyle(.white)
                    .background(Theme.goldGradient, in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(preferenceSummary == "No preference selected")
            .opacity(preferenceSummary == "No preference selected" ? 0.55 : 1)
        }
    }

    private var preferenceSummary: String {
        let values = [
            preferredStyle,
            budget,
            size,
            materialPreference,
            colorPreference,
            preferenceNote
        ]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0 != "N/A" }

        guard !values.isEmpty else {
            return "No preference selected"
        }

        return "Saved: \(values.prefix(3).joined(separator: ", "))"
    }

    private static func savedAttribute(_ title: String, in client: ClientProfile, fallback: String = "N/A") -> String {
        guard let rawValue = client.attributes.first(where: { $0.title.caseInsensitiveCompare(title) == .orderedSame })?.value else {
            return fallback
        }

        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            !value.isEmpty,
            value != "N/A",
            value != "Hidden until consent"
        else {
            return fallback
        }

        return value
    }

    private static func savedNote(in client: ClientProfile) -> String {
        let note = client.note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !note.isEmpty,
              note != "New client profile created. Preferences pending.",
              !note.lowercased().hasPrefix("new client prefers ")
        else {
            return ""
        }

        return note
    }
}

struct ClientAvatar: View {
    let initials: String
    let size: CGFloat

    var body: some View {
        Text(initials)
            .font(.system(size: size * 0.34, weight: .black, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(Theme.goldGradient, in: RoundedRectangle(cornerRadius: size * 0.32, style: .continuous))
    }
}
