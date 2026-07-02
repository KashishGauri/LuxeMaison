import SwiftUI
import MapKit
import Combine

struct SalesAssociateRootView: View {
    let onBack: () -> Void
    let loggedInDashboard: SalesAssociateDashboard
    let onLogout: () -> Void
    
    @State private var selectedTab: SalesAssociateTab = .today
    @State private var navigationMode: SalesNavigationMode = .sidebar
    @State private var recentlyViewedClients: [ClientProfile] = []
    @State private var clientProfiles = ClientProfileJSONStore.loadProfiles()
    @State private var sellingSession = SellingSessionState()
    // Seeded once with on-hand stock counts so a completed sale can decrement them.
    @State private var products: [SalesProduct] = SalesProduct.sampleProducts.map { $0.seededStockQuantity() }

    private let categories = ProductCategory.sampleCategories
    private let stockDashboard = StockDashboard.sample
    private let issueDashboard = IssueDashboard.sample

    @State private var appointments: [DBAppointment] = []

    /// Merges upcoming Supabase appointments into the dashboard's priority queue.
    private var customizedDashboard: SalesAssociateDashboard {
        let now = Date()

        func parseApptDate(_ dateString: String) -> Date? {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let d = formatter.date(from: dateString) { return d }

            let altFormatter = ISO8601DateFormatter()
            altFormatter.formatOptions = [.withInternetDateTime]
            if let d = altFormatter.date(from: dateString) { return d }

            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
            return dateFormatter.date(from: dateString)
        }

        let upcomingAppts = appointments.filter { appt in
            guard let apptDate = parseApptDate(appt.date) else { return false }
            return apptDate.timeIntervalSince(now) > -900
        }.sorted { appt1, appt2 in
            let d1 = parseApptDate(appt1.date) ?? Date.distantFuture
            let d2 = parseApptDate(appt2.date) ?? Date.distantFuture
            return d1 < d2
        }

        let apptPriorities = upcomingAppts.map { appt -> PriorityItem in
            let clientName = clientProfiles.first(where: { $0.id == appt.customerID })?.name ?? appt.customerID
            let timeString = appt.parsedDateTime.time
            let isVideo = appt.isVideo

            let diffMinutes = Int((parseApptDate(appt.date)?.timeIntervalSince(now) ?? 0) / 60)
            let badgeText: String?
            if diffMinutes <= 0 {
                badgeText = "Now"
            } else if diffMinutes <= 15 {
                badgeText = "In \(diffMinutes)m"
            } else {
                badgeText = "Upcoming"
            }

            return PriorityItem(
                icon: isVideo ? "video.fill" : "calendar.badge.clock",
                title: isVideo ? "Video Appointment" : "Boutique Visit",
                subtitle: "\(clientName), \(timeString)",
                badge: badgeText
            )
        }

        var combinedPriorities = apptPriorities
        for item in loggedInDashboard.priorityItems {
            if !item.title.lowercased().contains("appointment") {
                combinedPriorities.append(item)
            }
        }

        return SalesAssociateDashboard(
            associate: loggedInDashboard.associate,
            monthlyGoal: loggedInDashboard.monthlyGoal,
            priorityItems: combinedPriorities,
            quickActions: loggedInDashboard.quickActions,
            metrics: loggedInDashboard.metrics,
            weeklySales: loggedInDashboard.weeklySales
        )
    }

    /// Appointments starting within the next 15 minutes — surfaced as a bell badge.
    private var upcomingReminderCount: Int {
        appointments.filter { $0.isWithinReminderWindow }.count
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            TodayDashboardView(
                dashboard: customizedDashboard,
                reminderCount: upcomingReminderCount,
                appointments: appointments,
                clientProfiles: $clientProfiles,
                categories: categories,
                products: $products,
                stockDashboard: stockDashboard,
                issueDashboard: issueDashboard,
                selectedTab: $selectedTab,
                navigationMode: $navigationMode,
                recentlyViewedClients: $recentlyViewedClients,
                sellingSession: $sellingSession,
                onLogout: onLogout
            )
            .transition(.opacity)
            .task {
                await syncProfilesWithSupabase()
                await loadAppointments()
            }
        }
    }

    private func loadAppointments() async {
        do {
            let fetched = try await SupabaseDBService.shared.fetchAppointments(for: loggedInDashboard.associate.id)
            await MainActor.run {
                self.appointments = fetched.sorted { $0.date < $1.date }
                NotificationManager.shared.scheduleAppointmentNotifications(appointments: fetched, clientProfiles: clientProfiles)
            }
        } catch {
            #if DEBUG
            print("Failed to load appointments: \(error)")
            #endif
        }
    }

    private func syncProfilesWithSupabase() async {
        print("Supabase Sync: Starting sync...")
        do {
            let dbProfiles = try await SupabaseDBService.shared.fetchProfiles()
            print("Supabase Sync: Fetched \(dbProfiles.count) profiles from DB.")
            if dbProfiles.isEmpty {
                let localProfiles = ClientProfileJSONStore.loadProfiles()
                print("Supabase Sync: DB is empty. Uploading \(localProfiles.count) local profiles for migration...")
                if !localProfiles.isEmpty {
                    try await SupabaseDBService.shared.uploadBatchProfiles(localProfiles)
                    print("Supabase Sync: Migration successful!")
                }
            } else {
                await MainActor.run {
                    self.clientProfiles = dbProfiles
                    ClientProfileJSONStore.saveProfiles(dbProfiles)
                    print("Supabase Sync: Local state updated with DB profiles.")
                }
            }
        } catch {
            print("Supabase Sync ERROR: \(error)")
            print("Supabase Sync ERROR Details: \(error.localizedDescription)")
        }
    }
}

enum SalesNavigationMode: Equatable {
    case sidebar
    case top
}

struct TodayDashboardView: View {
    let dashboard: SalesAssociateDashboard
    var reminderCount: Int = 0
    var appointments: [DBAppointment] = []
    @Binding var clientProfiles: [ClientProfile]
    let categories: [ProductCategory]
    @Binding var products: [SalesProduct]
    let stockDashboard: StockDashboard
    let issueDashboard: IssueDashboard

    @Binding var selectedTab: SalesAssociateTab
    @Binding var navigationMode: SalesNavigationMode
    @Binding var recentlyViewedClients: [ClientProfile]
    @Binding var sellingSession: SellingSessionState
    @State private var isAssociateProfilePresented = false
    @State private var isAppointmentsSheetPresented = false
    @State private var isNotificationsSheetPresented = false
    let onLogout: () -> Void

    var body: some View {
        GeometryReader { proxy in
            Group {
                switch navigationMode {
                case .sidebar:
                    HStack(spacing: 0) {
                        SidebarView(
                            associate: dashboard.associate,
                            selectedTab: $selectedTab,
                            navigationMode: $navigationMode,
                            onProfileTap: {
                                isAssociateProfilePresented = true
                            }
                        )
                        .frame(width: sidebarWidth(for: proxy.size.width))

                        content
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                case .top:
                    VStack(spacing: 0) {
                        TopNavigationBar(
                            selectedTab: $selectedTab,
                            navigationMode: $navigationMode
                        )

                        content
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
            .background(Theme.background)
            .animation(.snappy(duration: 0.26), value: navigationMode)
            .sheet(isPresented: $isAssociateProfilePresented) {
                AssociateProfileSheet(associate: dashboard.associate, onLogout: onLogout)
            }
            .sheet(isPresented: $isAppointmentsSheetPresented) {
                AppointmentsSheet(associateID: dashboard.associate.id, clientProfiles: clientProfiles)
            }
            .sheet(isPresented: $isNotificationsSheetPresented) {
                NotificationsSheet(appointments: appointments, clientProfiles: clientProfiles)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch selectedTab {
        case .today:
            DashboardContent(
                dashboard: dashboard,
                reminderCount: reminderCount,
                onStartClient: startGuestSelling,
                onShowAppointments: { isAppointmentsSheetPresented = true },
                onShowNotifications: { isNotificationsSheetPresented = true }
            )
        case .client:
            ClientelingContent(
                clientProfiles: $clientProfiles,
                products: products,
                onStartGuestClient: startGuestSelling,
                onBuildCuratedCart: startClientSelling,
                recentlyViewedClients: $recentlyViewedClients
            )
        case .sell:
            SellContent(
                categories: categories,
                products: products,
                session: $sellingSession,
                onDiscardClient: discardSellingSession,
                onCreateProfile: saveCreatedProfile,
                onCheckoutCompleted: completeSale
            )
        case .stock:
            StockContent(dashboard: stockDashboard, products: products)
        case .issue:
            IssueContent(dashboard: issueDashboard, products: products)
        }
    }

    private func sidebarWidth(for width: CGFloat) -> CGFloat {
        width > 900 ? 210 : 150
    }

    private func startGuestSelling() {
        sellingSession.startNewGuest()
        selectedTab = .sell
    }

    private func startClientSelling(_ client: ClientProfile) {
        sellingSession.startForClient(client)
        selectedTab = .sell
    }

    private func discardSellingSession() {
        sellingSession.discard()
        selectedTab = .today
    }

    private func saveCreatedProfile(_ profile: ClientProfile) {
        clientProfiles.removeAll { $0.id == profile.id }
        clientProfiles.insert(profile, at: 0)
        ClientProfileJSONStore.saveProfiles(clientProfiles)
        recentlyViewedClients.removeAll { $0.id == profile.id }
        recentlyViewedClients.insert(profile, at: 0)
        
        Task {
            do {
                try await SupabaseDBService.shared.upsertProfile(profile)
            } catch {
                #if DEBUG
                print("Failed to sync new profile to Supabase: \(error)")
                #endif
            }
        }
    }

    /// Called when the associate finishes the payment flow (taps Done). When a
    /// sale was actually paid, records it from the finalized order, then clears
    /// the session.
    private func completeSale(paidOrder: FrozenOrder?) {
        if let paidOrder {
            recordCompletedSale(order: paidOrder)
        }
        discardSellingSession()
    }

    /// Applies the effects of a completed sale: decrements on-hand stock for each
    /// purchased product and appends the order (all its items grouped together)
    /// to the client's purchase history.
    private func recordCompletedSale(order: FrozenOrder) {
        guard !order.lineItems.isEmpty else { return }

        // 1) Reduce on-hand stock by the purchased quantity.
        for item in order.lineItems {
            if let index = products.firstIndex(where: { $0.id == item.id }) {
                products[index].stockQuantity = max(0, products[index].stockQuantity - item.quantity)
            }
        }

        // 2) Append to the client's purchase history (guests have no profile).
        guard let client = sellingSession.createdClient else { return }
        let productsByID = Dictionary(uniqueKeysWithValues: products.map { ($0.id, $0) })
        let purchasedOn = Self.purchaseDateString()
        let boutique = client.boutique.isEmpty ? dashboard.associate.boutique : client.boutique
        // Every item shares the order's ID so they render as one grouped order.
        let newPurchases: [ClientPurchase] = order.lineItems.map { item in
            let unitPrice = productsByID[item.id]?.price
                ?? IndianMoney.format(paise: item.grossInclusivePaise / max(1, item.quantity))
            return ClientPurchase(
                id: "PUR-\(order.orderID)-\(item.id)",
                productID: item.id,
                productName: item.name,
                price: unitPrice,
                purchasedOn: purchasedOn,
                boutique: boutique,
                orderID: order.orderID,
                quantity: item.quantity,
                grossPaise: item.grossInclusivePaise,
                hsn: item.classification.hsn,
                gstRate: item.classification.rate,
                invoiceNumber: order.invoiceNumber
            )
        }
        guard !newPurchases.isEmpty else { return }

        let updatedClient = client.addingPurchases(newPurchases)
        clientProfiles.removeAll { $0.id == updatedClient.id }
        clientProfiles.insert(updatedClient, at: 0)
        ClientProfileJSONStore.saveProfiles(clientProfiles)
        recentlyViewedClients.removeAll { $0.id == updatedClient.id }
        recentlyViewedClients.insert(updatedClient, at: 0)

        Task {
            do {
                try await SupabaseDBService.shared.upsertProfile(updatedClient)
            } catch {
                #if DEBUG
                print("Failed to sync purchase history to Supabase: \(error)")
                #endif
            }
        }
    }

    private static func purchaseDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM yyyy"
        return formatter.string(from: Date())
    }
}

enum SalesAssociateTab: String, CaseIterable, Identifiable {
    case today = "Today"
    case client = "Clienteling"
    case sell = "Sell"
    case stock = "Stock"
    case issue = "Issue"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .today:
            return "square.grid.2x2"
        case .client:
            return "person"
        case .sell:
            return "bag"
        case .stock:
            return "shippingbox"
        case .issue:
            return "list.clipboard"
        }
    }

    // allCases is synthesized by CaseIterable and includes every tab
    // (today, client, sell, stock, issue) so all appear in the sidebar and top nav.
}

//Dashboard content view
private struct SidebarView: View {
    let associate: AssociateProfile

    @Binding var selectedTab: SalesAssociateTab
    @Binding var navigationMode: SalesNavigationMode
    let onProfileTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(spacing: 12) {
                ForEach(SalesAssociateTab.allCases) { tab in
                    SidebarItem(
                        tab: tab,
                        isSelected: selectedTab == tab
                    ) {
                        selectedTab = tab
                    }
                }
            }
            .padding(.top, 58)

            Spacer()

            SidebarAssociateProfileButton(
                associate: associate,
                action: onProfileTap
            )
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 22)
        .background(.white.opacity(0.55))
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(Theme.line)
                .frame(width: 1)
        }
        .contentShape(Rectangle())
        .gesture(sidebarCollapseGesture)
        .accessibilityAction(named: "Collapse Sidebar") {
            navigationMode = .top
        }
    }

    private var sidebarCollapseGesture: some Gesture {
        DragGesture(minimumDistance: 32, coordinateSpace: .local)
            .onEnded { value in
                let horizontalDrag = abs(value.translation.width) > abs(value.translation.height)

                guard horizontalDrag, value.translation.width < -70 else { return }

                withAnimation(.snappy(duration: 0.26)) {
                    navigationMode = .top
                }
            }
    }
}

private struct TopNavigationBar: View {
    @Binding var selectedTab: SalesAssociateTab
    @Binding var navigationMode: SalesNavigationMode

    var body: some View {
        HStack(spacing: 14) {
            Spacer(minLength: 0)

            HStack(spacing: 12) {
                NavigationModeButton(symbol: "sidebar.left") {
                    navigationMode = .sidebar
                }
                .frame(width: 52)

                HStack(spacing: 8) {
                    ForEach(SalesAssociateTab.allCases) { tab in
                        TopNavigationItem(
                            tab: tab,
                            isSelected: selectedTab == tab
                        ) {
                            selectedTab = tab
                        }
                    }
                }
                .padding(6)
                .background(.white.opacity(0.62), in: Capsule())
                .overlay(
                    Capsule()
                        .stroke(Theme.line.opacity(0.6), lineWidth: 1)
                )
            }
            .fixedSize(horizontal: true, vertical: false)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 28)
        .padding(.top, 10)
        .padding(.bottom, 4)
    }
}

//Top Navigation view
private struct TopNavigationItem: View {
    let tab: SalesAssociateTab
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(tab.rawValue, systemImage: tab.symbol)
                .font(.subheadline.weight(.black))
                .lineLimit(1)
                .padding(.horizontal, 16)
                .frame(height: 44)
                .foregroundStyle(isSelected ? Theme.gold : Theme.muted)
                .background(
                    isSelected ? AnyShapeStyle(Theme.selected) : AnyShapeStyle(Color.clear),
                    in: Capsule()
                )
        }
        .buttonStyle(.plain)
    }
}

private struct NavigationModeButton: View {
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.headline.weight(.black))
                .frame(maxWidth: .infinity, minHeight: 44)
                .foregroundStyle(Theme.gold)
                .background(.white.opacity(0.70), in: Capsule())
                .overlay(
                    Capsule()
                        .stroke(Theme.line.opacity(0.62), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Show Sidebar")
    }
}

// SideBar items
private struct SidebarItem: View {
    let tab: SalesAssociateTab
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: tab.symbol)
                    .font(.headline)
                    .frame(width: 22)
                Text(tab.rawValue)
                    .font(.headline.weight(.bold))
            }
            .foregroundStyle(isSelected ? Theme.gold : Theme.muted)
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
            .padding(.horizontal, 14)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .fill(Theme.selected)
                        .overlay(
                            RoundedRectangle(cornerRadius: 17, style: .continuous)
                                .stroke(Theme.line, lineWidth: 1)
                        )
                }
            }
        }
        .buttonStyle(.plain)
    }
}

private struct SidebarAssociateProfileButton: View {
    let associate: AssociateProfile
    let action: () -> Void

    var body: some View {
        HStack {
            Spacer()
            Button(action: action) {
                Text(associate.initials)
                    .font(.headline.weight(.black))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(Theme.goldGradient, in: Circle())
                    .shadow(color: Theme.gold.opacity(0.15), radius: 6, x: 0, y: 3)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open sales associate profile")
            Spacer()
        }
    }
}

private struct AssociateProfileSheet: View {
    let associate: AssociateProfile
    let onLogout: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var shifts: [DBShift] = []
    @State private var dailyTasks: [DBDailyTask] = []
    @State private var isLoading = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top, spacing: 14) {
                    Text(associate.initials)
                        .font(.title.weight(.black))
                        .foregroundStyle(.white)
                        .frame(width: 68, height: 68)
                        .background(Theme.goldGradient, in: RoundedRectangle(cornerRadius: 22, style: .continuous))

                    VStack(alignment: .leading, spacing: 5) {
                        Text(associate.name)
                            .font(.title2.weight(.black))
                            .foregroundStyle(Theme.ink)
                        Text(associate.role)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(Theme.muted)
                        Text(associate.boutique)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Theme.gold)
                    }

                    Spacer()

                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.headline.weight(.black))
                            .foregroundStyle(Theme.muted)
                            .frame(width: 42, height: 42)
                            .background(.white.opacity(0.74), in: Circle())
                    }
                    .buttonStyle(.plain)
                }

                VStack(spacing: 12) {
                    AssociateProfileInfoRow(title: "Email", value: associate.email, icon: "envelope")
                    AssociateProfileInfoRow(title: "Phone", value: associate.phone, icon: "phone")
                    AssociateProfileInfoRow(title: "Employee ID", value: associate.employeeID, icon: "person.text.rectangle")
                }

                if isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                            .tint(Theme.gold)
                        Spacer()
                    }
                    .padding(.vertical, 10)
                } else {
                    if !shifts.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("ASSIGNED SHIFTS")
                                .font(.caption.weight(.black))
                                .tracking(1.1)
                                .foregroundStyle(Theme.muted)

                            ForEach(shifts) { shift in
                                HStack(spacing: 12) {
                                    Image(systemName: "calendar.badge.clock")
                                        .font(.headline.weight(.black))
                                        .foregroundStyle(Theme.gold)
                                        .frame(width: 44, height: 44)
                                        .background(Theme.selected, in: RoundedRectangle(cornerRadius: 15, style: .continuous))

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text("SHIFT TYPE")
                                            .font(.caption.weight(.black))
                                            .tracking(1.1)
                                            .foregroundStyle(Theme.muted)
                                        Text(shift.shiftType.uppercased())
                                            .font(.headline.weight(.bold))
                                            .foregroundStyle(Theme.ink)
                                    }
                                    Spacer()
                                }
                                .padding(14)
                                .background(.white.opacity(0.62), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .stroke(Theme.line.opacity(0.45), lineWidth: 1)
                                )
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("DAILY TASKS")
                            .font(.caption.weight(.black))
                            .tracking(1.1)
                            .foregroundStyle(Theme.muted)

                        if dailyTasks.isEmpty {
                            Text("No daily tasks assigned for today.")
                                .font(.subheadline)
                                .foregroundStyle(Theme.muted)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(.white.opacity(0.42), in: RoundedRectangle(cornerRadius: 15))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 15)
                                        .stroke(Theme.line.opacity(0.3), lineWidth: 1)
                                )
                        } else {
                            VStack(spacing: 12) {
                                ForEach(dailyTasks.indices, id: \.self) { index in
                                    Button {
                                        dailyTasks[index].isCompleted.toggle()
                                        if !associate.id.hasSuffix("-id") {
                                            let task = dailyTasks[index]
                                            Task {
                                                await SupabaseDBService.shared.updateDailyTaskStatus(taskId: task.id, isCompleted: task.isCompleted)
                                            }
                                        }
                                    } label: {
                                        HStack(spacing: 12) {
                                            Image(systemName: dailyTasks[index].isCompleted ? "checkmark.circle.fill" : "circle")
                                                .font(.headline.weight(.black))
                                                .foregroundStyle(dailyTasks[index].isCompleted ? .green : Theme.gold)
                                                .frame(width: 44, height: 44)
                                                .background(Theme.selected, in: RoundedRectangle(cornerRadius: 15, style: .continuous))

                                            VStack(alignment: .leading, spacing: 3) {
                                                Text(dailyTasks[index].date)
                                                    .font(.caption.weight(.black))
                                                    .tracking(1.1)
                                                    .foregroundStyle(Theme.muted)
                                                Text(dailyTasks[index].title)
                                                    .font(.headline.weight(.bold))
                                                    .foregroundStyle(Theme.ink)
                                                    .multilineTextAlignment(.leading)
                                            }
                                            Spacer()
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    .padding(14)
                                    .background(.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                                            .stroke(Theme.line.opacity(0.4), lineWidth: 1)
                                    )
                                }
                            }
                        }
                    }
                }

                Spacer(minLength: 16)

                Button {
                    dismiss()
                    onLogout()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "power")
                            .font(.headline.weight(.black))
                        Text("LOG OUT")
                            .font(.headline.weight(.black))
                            .tracking(1.2)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(
                        LinearGradient(
                            colors: [Color(red: 0.48, green: 0.14, blue: 0.14), Color(red: 0.68, green: 0.22, blue: 0.22)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(26)
        }
        .frame(minWidth: 420, minHeight: 480)
        .background(Theme.background)
        .task {
            isLoading = true
            do {
                if associate.id.hasSuffix("-id") {
                    shifts = [DBShift(id: "mock-shift-1", userID: associate.id, storeID: "mock-store", shiftType: associate.shift)]
                    dailyTasks = [
                        DBDailyTask(id: "mock-task-1", userID: associate.id, date: "2026-07-02", title: "Verify boutique planogram guidelines", isCompleted: true),
                        DBDailyTask(id: "mock-task-2", userID: associate.id, date: "2026-07-02", title: "Welcome premium VIP clients", isCompleted: false),
                        DBDailyTask(id: "mock-task-3", userID: associate.id, date: "2026-07-02", title: "Complete shift checklist handover", isCompleted: false)
                    ]
                } else {
                    shifts = try await SupabaseDBService.shared.fetchShifts(for: associate.id)
                    dailyTasks = try await SupabaseDBService.shared.fetchDailyTasks(for: associate.id)
                }
            } catch {
                #if DEBUG
                print("Failed to fetch shifts/tasks: \(error)")
                #endif
            }
            isLoading = false
        }
    }
}

private struct AssociateProfileInfoRow: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.headline.weight(.black))
                .foregroundStyle(Theme.gold)
                .frame(width: 44, height: 44)
                .background(Theme.selected, in: RoundedRectangle(cornerRadius: 15, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(title.uppercased())
                    .font(.caption.weight(.black))
                    .tracking(1.1)
                    .foregroundStyle(Theme.muted)
                Text(value)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(.white.opacity(0.62), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Theme.line.opacity(0.45), lineWidth: 1)
        )
    }
}

// client content


struct AppointmentsSheet: View {
    let associateID: String
    let clientProfiles: [ClientProfile]
    @Environment(\.dismiss) private var dismiss

    @State private var appointments: [DBAppointment] = []
    @State private var isLoading = true
    @State private var errorMessage: String? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background
                    .ignoresSafeArea()

                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                            .tint(Theme.gold)
                        Text("Fetching appointments...")
                            .font(.headline)
                            .foregroundStyle(Theme.muted)
                    }
                } else if let errorMessage = errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundStyle(.red)
                        Text(errorMessage)
                            .font(.headline)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                        Button("Retry") {
                            Task {
                                await loadAppointments()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.gold)
                    }
                } else if appointments.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 48))
                            .foregroundStyle(Theme.muted)
                        Text("No appointments scheduled")
                            .font(.headline)
                            .foregroundStyle(Theme.muted)
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 14) {
                            ForEach(appointments.indices, id: \.self) { index in
                                AppointmentRow(
                                    appointment: appointments[index],
                                    clientProfile: findClientProfile(for: appointments[index].customerID),
                                    onToggleStatus: {
                                        let currentStatus = appointments[index].status
                                        let newStatus = currentStatus == "completed" ? "scheduled" : "completed"
                                        
                                        appointments[index].status = newStatus
                                        
                                        let appointmentId = appointments[index].id
                                        Task {
                                            await SupabaseDBService.shared.updateAppointmentStatus(appointmentId: appointmentId, status: newStatus)
                                        }
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 18)
                    }
                }
            }
            .navigationTitle("Appointments")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.body.weight(.bold))
                    .foregroundStyle(Theme.gold)
                }
            }
            .task {
                await loadAppointments()
            }
        }
        .presentationDragIndicator(.visible)
        .presentationDetents([.medium, .large])
    }

    private func findClientProfile(for customerID: String) -> ClientProfile? {
        clientProfiles.first { $0.id == customerID }
    }

    private func loadAppointments() async {
        isLoading = true
        errorMessage = nil
        do {
            let fetched = try await SupabaseDBService.shared.fetchAppointments(for: associateID)
            await MainActor.run {
                self.appointments = fetched.sorted { $0.date < $1.date }
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load appointments: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
}

struct AppointmentRow: View {
    let appointment: DBAppointment
    let clientProfile: ClientProfile?
    let onToggleStatus: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            Button(action: onToggleStatus) {
                Image(systemName: appointment.status == "completed" ? "checkmark.circle.fill" : "circle")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(appointment.status == "completed" ? .green : Theme.gold)
                    .frame(width: 44, height: 44)
                    .background(Theme.selected, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Toggle appointment completion status")

            VStack(alignment: .leading, spacing: 6) {
                // Name
                Text(clientProfile?.name ?? appointment.customerID)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Theme.ink)

                // Date & Time
                HStack(spacing: 8) {
                    Image(systemName: "calendar")
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                    Text(appointment.parsedDateTime.date)
                        .font(.subheadline)
                        .foregroundStyle(Theme.muted)

                    Text("•")
                        .foregroundStyle(Theme.line)

                    Image(systemName: "clock")
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                    Text(appointment.parsedDateTime.time)
                        .font(.subheadline)
                        .foregroundStyle(Theme.muted)
                }

                // Preference
                if let preference = appointment.preferences ?? clientProfile?.note, !preference.isEmpty {
                    Text("Preference: \(preference)")
                        .font(.subheadline)
                        .foregroundStyle(Theme.muted)
                        .padding(.top, 2)
                }
            }

            Spacer()

            // Video calls show only the tap-to-FaceTime button; other types keep
            // their label (e.g. "walk in").
            HStack(spacing: 8) {
                if appointment.isVideo {
                    Button {
                        openFaceTime()
                    } label: {
                        Image(systemName: "video.fill")
                            .font(.title3)
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(Theme.goldGradient, in: Circle())
                    }
                    .buttonStyle(.plain)
                } else {
                    Text(appointment.displayType)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Theme.selected, in: Capsule())
                }
            }
        }
        .padding()
        .background(.white.opacity(0.68), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Theme.line, lineWidth: 1)
        )
    }

    private func openFaceTime() {
        if let email = clientProfile?.email, !email.isEmpty {
            let sanitizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
            if let encodedEmail = sanitizedEmail.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed),
               let url = URL(string: "facetime://\(encodedEmail)") {
                UIApplication.shared.open(url)
                return
            }
        }

        if let phone = clientProfile?.phone, !phone.isEmpty {
            // Extract digits only
            let digits = phone.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
            // Add '+' prefix if original number had it
            let hasPlus = phone.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("+")
            let finalPhone = (hasPlus ? "+" : "") + digits

            if let encodedPhone = finalPhone.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed),
               let url = URL(string: "facetime://\(encodedPhone)") {
                UIApplication.shared.open(url)
                return
            }
        }

        if let url = URL(string: "facetime://") {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Notifications

/// A single alert shown in the notifications screen (built from appointments).
private struct NotificationItem: Identifiable {
    let id: String
    let icon: String
    let title: String
    let message: String
    let timeText: String
    let isImminent: Bool
}

/// iOS-style notifications screen. The bell in the header opens this; it lists
/// appointment reminders soonest-first, mirroring the push reminders.
struct NotificationsSheet: View {
    let appointments: [DBAppointment]
    let clientProfiles: [ClientProfile]
    @Environment(\.dismiss) private var dismiss

    private static func parse(_ dateString: String) -> Date? {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: dateString) { return d }
        let alt = ISO8601DateFormatter()
        alt.formatOptions = [.withInternetDateTime]
        if let d = alt.date(from: dateString) { return d }
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
        return df.date(from: dateString)
    }

    private var items: [NotificationItem] {
        let now = Date()
        let upcoming: [(DBAppointment, Date)] = appointments.compactMap { appt in
            guard let date = Self.parse(appt.date) else { return nil }
            // Keep future ones (and those that just started in the last 15 min).
            return date.timeIntervalSince(now) > -900 ? (appt, date) : nil
        }
        .sorted { $0.1 < $1.1 }

        return upcoming.map { appt, date in
            let name = clientProfiles.first(where: { $0.id == appt.customerID })?.name ?? appt.customerID
            let minutes = Int((date.timeIntervalSince(now) / 60).rounded())
            let imminent = date.timeIntervalSince(now) <= 900

            let timeText: String
            let message: String
            if minutes <= 0 {
                timeText = "Now"
                message = "Your appointment with \(name) is starting now."
            } else if minutes < 60 {
                timeText = "in \(minutes)m"
                message = "Your appointment with \(name) starts in \(minutes) minutes."
            } else {
                timeText = appt.parsedDateTime.time
                message = "Appointment with \(name) at \(appt.parsedDateTime.time) · \(appt.parsedDateTime.date)."
            }

            return NotificationItem(
                id: appt.id,
                icon: appt.isVideo ? "video.fill" : "bell.badge.fill",
                title: appt.isVideo ? "Video Consultation" : "Upcoming Appointment",
                message: message,
                timeText: timeText,
                isImminent: imminent
            )
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                if items.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "bell.slash")
                            .font(.system(size: 42, weight: .regular))
                            .foregroundStyle(Theme.muted)
                        Text("No Notifications")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(Theme.ink)
                        Text("Appointment reminders will appear here.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.muted)
                            .multilineTextAlignment(.center)
                    }
                    .padding(40)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(items) { item in
                                NotificationRow(item: item)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                    }
                    .scrollIndicators(.hidden)
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }
}

private struct NotificationRow: View {
    let item: NotificationItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: item.icon)
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(
                    item.isImminent ? AnyShapeStyle(Theme.goldGradient) : AnyShapeStyle(Theme.muted.opacity(0.55)),
                    in: RoundedRectangle(cornerRadius: 13, style: .continuous)
                )

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(item.title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Theme.ink)
                    Spacer()
                    Text(item.timeText)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(item.isImminent ? Color.red : Theme.muted)
                }
                Text(item.message)
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Theme.line.opacity(0.4), lineWidth: 1)
        )
    }
}

