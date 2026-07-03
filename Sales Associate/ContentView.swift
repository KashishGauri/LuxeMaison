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
    // Loaded dynamically from Supabase database Product table.
    @State private var products: [SalesProduct] = []

    private let categories = ProductCategory.sampleCategories
    private let stockDashboard = StockDashboard.sample
    private let issueDashboard = IssueDashboard.sample

    @State private var appointments: [DBAppointment] = []
    @State private var dailyTasks: [DBDailyTask] = []
    @State private var sales: [DBSale] = []
    @State private var activeStoreID: String = "mock-store"
    @State private var dynamicSalesGoal: SalesGoal? = nil
    @State private var dynamicWeeklySales: WeeklySalesSummary? = nil
    @State private var dynamicMetrics: [DashboardMetric]? = nil

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
            let parsed = appt.parsedDateTime
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
                subtitle: "Appointment with \(clientName) on \(parsed.date) at \(parsed.time)",
                badge: badgeText
            )
        }

        var combinedPriorities = apptPriorities
        if combinedPriorities.isEmpty {
            combinedPriorities = [
                PriorityItem(
                    icon: "calendar",
                    title: "Queue Clear",
                    subtitle: "No upcoming appointments today",
                    badge: nil
                )
            ]
        }

        return SalesAssociateDashboard(
            associate: loggedInDashboard.associate,
            monthlyGoal: dynamicSalesGoal ?? loggedInDashboard.monthlyGoal,
            priorityItems: combinedPriorities,
            quickActions: loggedInDashboard.quickActions,
            metrics: dynamicMetrics ?? loggedInDashboard.metrics.filter { $0.title != "VIP Today" },
            weeklySales: dynamicWeeklySales ?? loggedInDashboard.weeklySales
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
                stockDashboard: customizedStockDashboard,
                issueDashboard: issueDashboard,
                dailyTasks: $dailyTasks,
                sales: $sales,
                activeStoreID: activeStoreID,
                selectedTab: $selectedTab,
                navigationMode: $navigationMode,
                recentlyViewedClients: $recentlyViewedClients,
                sellingSession: $sellingSession,
                onReloadProducts: { await loadProductsFromDB() },
                onLogout: onLogout
            )
            .transition(.opacity)
            .task {
                await syncProfilesWithSupabase()
                await loadAppointments()
                await loadSalesAndGoal()
                await loadProductsFromDB()
                await loadActiveStoreID()
            }
        }
    }

    private func loadActiveStoreID() async {
        do {
            let shifts = try await SupabaseDBService.shared.fetchShifts(for: loggedInDashboard.associate.id)
            if let firstShift = shifts.first {
                await MainActor.run {
                    self.activeStoreID = firstShift.storeID
                    print("Supabase Sync: Active store ID loaded: \(self.activeStoreID)")
                }
            }
        } catch {
            print("Supabase Sync Shifts ERROR: \(error)")
        }
    }

    private var customizedStockDashboard: StockDashboard {
        let totalStock = products.reduce(0) { $0 + $1.stockQuantity }
        let totalStockString = String(format: "%02d", totalStock)
        
        let updatedMetrics = [
            StockMetric(title: "In Boutique", value: totalStockString, detail: "sellable pieces"),
            StockMetric(title: "SM Review", value: "03", detail: "fulfillment checks"),
            StockMetric(title: "Scanned Today", value: "12", detail: "certificate checks")
        ]
        
        return StockDashboard(
            metrics: updatedMetrics,
            issueTypes: stockDashboard.issueTypes,
            scanChecks: stockDashboard.scanChecks,
            reviews: stockDashboard.reviews
        )
    }

    private func loadSalesAndGoal() async {
        let associateID = loggedInDashboard.associate.id
        do {
            if !associateID.hasSuffix("-id") {
                let sales = try await SupabaseDBService.shared.fetchSales(for: associateID)
                let target = try await SupabaseDBService.shared.fetchAssociateSalesTarget(for: associateID)
                let tasks = try await SupabaseDBService.shared.fetchDailyTasks(for: associateID)
                
                let achievedSum = sales.reduce(0.0) { $0 + $1.totalAmount }
                let achievedStr = achievedSum >= 100000.0 ? String(format: "Rs. %.1fL", achievedSum / 100000.0) : String(format: "Rs. %.0f", achievedSum)
                
                let targetSum = target?.targetAmount ?? 500000.0
                let targetStr = targetSum >= 100000.0 ? String(format: "Rs. %.1fL", targetSum / 100000.0) : String(format: "Rs. %.0f", targetSum)
                
                let goalProgress = targetSum > 0 ? min(1.0, achievedSum / targetSum) : 0.0
                
                let salesGoal = SalesGoal(
                    title: "Monthly Sales Goal",
                    progress: goalProgress,
                    achieved: achievedStr,
                    target: targetStr
                )
                
                let weeklySalesSummary = SupabaseDBService.shared.calculateWeeklySalesSummary(sales: sales)
                
                let uniqueClientsCount = Set(sales.compactMap { $0.customerID }).count
                let openCartsValue = String(format: "%02d", uniqueClientsCount)
                let followUpsValue = String(format: "%02d", tasks.filter { !$0.isCompleted }.count)
                
                let metrics = [
                    DashboardMetric(title: "Open Carts", value: openCartsValue),
                    DashboardMetric(title: "Follow-ups", value: followUpsValue)
                ]
                
                await MainActor.run {
                    self.dynamicSalesGoal = salesGoal
                    self.dynamicWeeklySales = weeklySalesSummary
                    self.dailyTasks = tasks
                    self.sales = sales
                    self.dynamicMetrics = metrics
                }
            } else {
                let achievedSum = 100000.0
                let targetSum = 500000.0
                let goalProgress = achievedSum / targetSum
                
                let salesGoal = SalesGoal(
                    title: "Monthly Sales Goal",
                    progress: goalProgress,
                    achieved: "Rs. 1.0L",
                    target: "Rs. 5.0L"
                )
                
                let mockDays = [
                    DailySales(day: "Mon", amount: "10k", progress: 0.25, isBest: false),
                    DailySales(day: "Tue", amount: "15k", progress: 0.38, isBest: false),
                    DailySales(day: "Wed", amount: "8k", progress: 0.20, isBest: false),
                    DailySales(day: "Thu", amount: "40k", progress: 1.00, isBest: true),
                    DailySales(day: "Fri", amount: "12k", progress: 0.30, isBest: false),
                    DailySales(day: "Sat", amount: "10k", progress: 0.25, isBest: false),
                    DailySales(day: "Sun", amount: "5k", progress: 0.12, isBest: false)
                ]
                
                let weeklySalesSummary = WeeklySalesSummary(
                    total: "Rs. 1.0L",
                    change: "+12%",
                    comparison: "vs last week",
                    bestDay: "Thu",
                    bestDayLabel: "Best sales day",
                    days: mockDays
                )
                
                let mockTasks = [
                    DBDailyTask(id: "mock-task-1", userID: associateID, date: "2026-07-02", title: "Verify boutique planogram guidelines", isCompleted: true),
                    DBDailyTask(id: "mock-task-2", userID: associateID, date: "2026-07-02", title: "Welcome premium VIP clients", isCompleted: false),
                    DBDailyTask(id: "mock-task-3", userID: associateID, date: "2026-07-02", title: "Complete shift checklist handover", isCompleted: false)
                ]
                
                let mockSales = [
                    DBSale(id: "s1", customerID: "bf8300be-664e-4606-8497-37c5a2ea836a", salesAssociateID: associateID, storeID: "mock-store", salesDate: "2026-07-02", currency: "INR", preTaxAmount: 40000.0, taxAmount: 4000.0, totalAmount: 44000.0),
                    DBSale(id: "s2", customerID: "701d1f4e-5af8-4772-990d-b0b96c0e3e83", salesAssociateID: associateID, storeID: "mock-store", salesDate: "2026-07-01", currency: "INR", preTaxAmount: 50000.0, taxAmount: 5000.0, totalAmount: 55000.0),
                    DBSale(id: "s3", customerID: "3c193803-be64-4a46-bcaf-a00ccfa497da", salesAssociateID: associateID, storeID: "mock-store", salesDate: "2026-07-02", currency: "INR", preTaxAmount: 1000.0, taxAmount: 100.0, totalAmount: 1100.0)
                ]
                
                let metrics = [
                    DashboardMetric(title: "Open Carts", value: "03"),
                    DashboardMetric(title: "Follow-ups", value: "02")
                ]
                
                await MainActor.run {
                    self.dynamicSalesGoal = salesGoal
                    self.dynamicWeeklySales = weeklySalesSummary
                    self.dailyTasks = mockTasks
                    self.sales = mockSales
                    self.dynamicMetrics = metrics
                }
            }
        } catch {
            #if DEBUG
            print("Failed to fetch sales target / weekly sales/tasks: \(error)")
            #endif
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

    private func formatPrice(_ amount: Double) -> String {
        if amount >= 10000000 { // 1 Crore
            return String(format: "Rs. %.2fCr", amount / 10000000.0)
        } else if amount >= 100000 { // 1 Lakh
            return String(format: "Rs. %.2fL", amount / 100000.0)
        } else if amount >= 1000 { // Thousands
            return String(format: "Rs. %.1fk", amount / 1000.0)
        } else {
            return String(format: "Rs. %.0f", amount)
        }
    }

    private func normalizeCategoryID(_ category: String) -> String {
        let lower = category.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if lower.contains("handbag") || lower.contains("bag") || lower.contains("clutch") || lower.contains("pouch") || lower.contains("backpack") || lower.contains("case") || lower.contains("tote") || lower.contains("briefcase") {
            return "handbags"
        } else if lower.contains("watch") || lower.contains("chrono") || lower.contains("president") {
            return "watches"
        } else if lower.contains("fragrance") || lower.contains("perfume") || lower.contains("scent") || lower.contains("cologne") || lower.contains("mist") || lower.contains("spray") || lower.contains("wind") {
            return "fragrances"
        } else if lower.contains("footwear") || lower.contains("shoe") || lower.contains("heel") || lower.contains("flat") || lower.contains("loafer") || lower.contains("oxford") || lower.contains("slip") {
            return "footwear"
        } else if lower.contains("jewel") || lower.contains("gem") || lower.contains("ring") || lower.contains("necklace") || lower.contains("bracelet") || lower.contains("pendant") || lower.contains("earring") || lower.contains("bangle") || lower.contains("set") || lower.contains("brooch") || lower.contains("sparkle") {
            // Redirect jewellery/sets to watches (accessories)
            return "watches"
        }
        return "handbags" // Default fallback
    }

    private func loadProductsFromDB() async {
        print("Supabase Sync: Starting product sync...")
        do {
            let dbProducts = try await SupabaseDBService.shared.fetchDBProducts()
            print("Supabase Sync: Fetched \(dbProducts.count) products from DB.")

            // On-hand stock is sourced from StoreInventory.currentquantity, keyed
            // by productid (= Product.id). Summed across rows in case a product
            // spans more than one inventory row.
            var inventoryByProductID: [String: Int] = [:]
            do {
                let inventory = try await SupabaseDBService.shared.fetchStoreInventory()
                for row in inventory {
                    inventoryByProductID[row.productid, default: 0] += row.currentquantity
                }
                print("Supabase Sync: Fetched \(inventory.count) StoreInventory rows.")
            } catch {
                print("Supabase Sync: StoreInventory fetch failed, falling back to Product.current_stock: \(error)")
            }

            await MainActor.run {
                self.products = dbProducts.map { dbProduct in
                    // Format price
                    let rawPrice = dbProduct.basePrice ?? 0
                    let normalizedPrice = rawPrice < 1000 ? rawPrice * 100000 : rawPrice
                    let formattedPrice = self.formatPrice(normalizedPrice)
                    let normalizedCat = self.normalizeCategoryID(dbProduct.category ?? "accessories")

                    // Prefer StoreInventory; fall back to Product.current_stock only
                    // when the product has no inventory row.
                    let stockQty = inventoryByProductID[dbProduct.id] ?? dbProduct.currentStock ?? 0

                    return SalesProduct(
                        id: dbProduct.sku ?? dbProduct.id,
                        name: dbProduct.name,
                        brand: dbProduct.brand ?? "LuxeMaison",
                        categoryID: normalizedCat,
                        audience: "Women",
                        price: formattedPrice,
                        originalPrice: nil,
                        imageName: dbProduct.imageUrl ?? "default_product",
                        badge: nil,
                        availability: stockQty > 0 ? "In boutique" : "Out of stock",
                        stockNote: stockQty > 0 ? "\(stockQty) pieces available in boutique" : "Not in boutique",
                        sizes: ["One size"],
                        materials: ["Standard"],
                        colors: ["Default"],
                        suggestedReason: "Boutique verified luxury item",
                        isWishlisted: false,
                        stockQuantity: stockQty,
                        existsInDB: true,
                        dbID: dbProduct.id,
                        barcode: dbProduct.barcode,
                        isActive: dbProduct.isActive,
                        reorderThreshold: dbProduct.reorderThreshold
                    )
                }
                print("Supabase Sync: Products loaded from database successfully.")
            }
        } catch {
            print("Supabase Sync Products ERROR: \(error)")
            // Keep whatever products are already loaded — a failed refresh (e.g. the
            // reload right after a sale) must not blank out the Stock/Billing tabs.
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
    @Binding var dailyTasks: [DBDailyTask]
    @Binding var sales: [DBSale]
    let activeStoreID: String

    @Binding var selectedTab: SalesAssociateTab
    @Binding var navigationMode: SalesNavigationMode
    @Binding var recentlyViewedClients: [ClientProfile]
    @Binding var sellingSession: SellingSessionState
    /// Re-fetches the product catalogue (and its StoreInventory stock) from Supabase.
    /// Called after a sale so the Stock tab shows the real remaining quantity.
    var onReloadProducts: () async -> Void = {}
    @State private var isAssociateProfilePresented = false
    @State private var isAppointmentsSheetPresented = false
    @State private var isNotificationsSheetPresented = false
    @State private var isHandledClientsPresented = false
    @State private var isDailyTasksSheetPresented = false
    /// Order ids already recorded, so a sale is never written twice (it is recorded
    /// at receipt generation, and Done may fire the same path again).
    @State private var recordedOrderIDs: Set<String> = []
    /// True once a receipt has been generated but the associate hasn't tapped Done.
    /// If they leave the Billing tab in this state, the client session is closed so
    /// Billing reopens fresh next time.
    @State private var saleAwaitingClose = false
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
                AssociateProfileSheet(associate: dashboard.associate, dailyTasks: $dailyTasks, onLogout: onLogout)
            }
            .sheet(isPresented: $isAppointmentsSheetPresented) {
                AppointmentsSheet(associateID: dashboard.associate.id, clientProfiles: clientProfiles)
            }
            .sheet(isPresented: $isNotificationsSheetPresented) {
                NotificationsSheet(appointments: appointments, clientProfiles: clientProfiles)
            }
            .sheet(isPresented: $isHandledClientsPresented) {
                HandledClientsSheet(sales: sales, clientProfiles: clientProfiles)
            }
            .sheet(isPresented: $isDailyTasksSheetPresented) {
                DailyTasksSheet(dailyTasks: $dailyTasks, associateId: dashboard.associate.id)
            }
            .onChange(of: selectedTab) { oldTab, newTab in
                // If a receipt was generated but the associate left Billing without
                // tapping Done, close the client session so Billing reopens as a
                // normal, client-free billing screen next time.
                if oldTab == .sell, newTab != .sell, saleAwaitingClose {
                    sellingSession.discard()
                    saleAwaitingClose = false
                }
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
                onShowNotifications: { isNotificationsSheetPresented = true },
                onShowDailyTasks: { isDailyTasksSheetPresented = true },
                onShowHandledClients: { isHandledClientsPresented = true }
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
                onCheckoutCompleted: completeSale,
                onOrderFinalized: { order in
                    recordCompletedSale(order: order)
                    saleAwaitingClose = true
                }
            )
        case .stock:
            StockContent(dashboard: stockDashboard, products: products)
        case .issue:
            IssueContent(
                dashboard: issueDashboard,
                products: products,
                associateID: dashboard.associate.id,
                storeID: activeStoreID
            )
        }
    }

    private func sidebarWidth(for width: CGFloat) -> CGFloat {
        width > 900 ? 210 : 150
    }

    private func startGuestSelling() {
        saleAwaitingClose = false
        sellingSession.startNewGuest()
        selectedTab = .sell
    }

    private func startClientSelling(_ client: ClientProfile) {
        saleAwaitingClose = false
        sellingSession.startForClient(client)
        selectedTab = .sell
    }

    private func discardSellingSession() {
        saleAwaitingClose = false
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
        // Record each order exactly once — the sale is captured at receipt
        // generation, and tapping Done can trigger this same path again.
        guard !recordedOrderIDs.contains(order.orderID) else { return }
        recordedOrderIDs.insert(order.orderID)

        // 1) Reduce on-hand stock locally for an instant UI update.
        for item in order.lineItems {
            if let index = products.firstIndex(where: { $0.id == item.id }) {
                products[index].stockQuantity = max(0, products[index].stockQuantity - item.quantity)
            }
        }

        let productsByID = Dictionary(uniqueKeysWithValues: products.map { ($0.id, $0) })

        // 2) Persist the sale to Supabase — decrement StoreInventory, write the
        //    Sales + SalesItem rows (one item per purchased product), then reload
        //    the catalogue so the Stock tab shows the real remaining quantity.
        //    Runs for guests too (the sale is still recorded).
        let associateID = dashboard.associate.id
        let saleItems: [SupabaseDBService.SaleItemInput] = order.lineItems.compactMap { item in
            guard let dbID = productsByID[item.id]?.dbID, !dbID.isEmpty else { return nil }
            let quantity = max(1, item.quantity)
            let subTotal = Double(item.grossInclusivePaise) / 100.0   // paise → rupees
            return SupabaseDBService.SaleItemInput(
                productID: dbID,
                quantity: quantity,
                unitPriceRupees: subTotal / Double(quantity),
                subTotalRupees: subTotal
            )
        }
        let preTaxRupees = Double(order.taxablePaise) / 100.0
        let taxRupees = Double(order.taxPaise) / 100.0
        let totalRupees = Double(order.totalPaise) / 100.0
        let saleDate = Self.saleDateString()

        Task {
            for item in order.lineItems {
                if let dbID = productsByID[item.id]?.dbID, !dbID.isEmpty {
                    await SupabaseDBService.shared.decrementStoreInventory(productID: dbID, by: item.quantity)
                }
            }
            // Skip Sales recording for mock associates without a real DB uuid.
            if !associateID.hasSuffix("-id") {
                await SupabaseDBService.shared.recordSale(
                    salesAssociateID: associateID,
                    salesDate: saleDate,
                    preTaxAmount: preTaxRupees,
                    taxAmount: taxRupees,
                    totalAmount: totalRupees,
                    items: saleItems
                )
            }
            // Refresh from Supabase so the Stock tab reflects the DB quantities.
            await onReloadProducts()
        }

        // 3) Append to the client's purchase history (guests have no profile).
        guard let client = sellingSession.createdClient else { return }
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

    /// Date for the Supabase `Sales.salesDate` column (matches the DB's `yyyy-MM-dd`).
    private static func saleDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}

enum SalesAssociateTab: String, CaseIterable, Identifiable {
    case today = "Today"
    case client = "Clienteling"
    case sell = "Billing"
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
    @Binding var dailyTasks: [DBDailyTask]
    let onLogout: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var shifts: [DBShift] = []
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
                } else {
                    shifts = try await SupabaseDBService.shared.fetchShifts(for: associate.id)
                }
            } catch {
                #if DEBUG
                print("Failed to fetch shifts: \(error)")
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
                        Text("No upcoming appointments")
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
            let now = Date()
            // Only surface upcoming appointments. Anything that started more than
            // 15 minutes ago has passed, so yesterday's appointments no longer
            // linger in the list. Unparseable dates are kept rather than hidden.
            let upcoming = fetched.filter { appt in
                guard let start = appt.startDate else { return true }
                return start.timeIntervalSince(now) > -900
            }.sorted { ($0.startDate ?? .distantFuture) < ($1.startDate ?? .distantFuture) }
            await MainActor.run {
                self.appointments = upcoming
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

    private var isTimeReached: Bool {
        guard let startDate = appointment.startDate else { return true }
        return Date() >= startDate
    }

    var body: some View {
        HStack(spacing: 16) {
            Button(action: onToggleStatus) {
                Image(systemName: appointment.status == "completed" ? "checkmark.circle.fill" : "circle")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(
                        !isTimeReached ? Theme.muted.opacity(0.4) :
                        (appointment.status == "completed" ? .green : Theme.gold)
                    )
                    .frame(width: 44, height: 44)
                    .background(Theme.selected, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(!isTimeReached)
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


struct HandledClientsSheet: View {
    let sales: [DBSale]
    let clientProfiles: [ClientProfile]
    @Environment(\.dismiss) private var dismiss

    private var handledClients: [ClientProfile] {
        let uniqueCustomerIDs = Array(Set(sales.compactMap { $0.customerID }))
        return uniqueCustomerIDs.compactMap { customerID in
            clientProfiles.first(where: { $0.id == customerID })
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top, spacing: 14) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.title2.weight(.black))
                            .foregroundStyle(Theme.ink)
                            .frame(width: 44, height: 44)
                            .background(.white.opacity(0.85), in: Circle())
                    }
                    .buttonStyle(.plain)

                    VStack(alignment: .leading, spacing: 5) {
                        Text("Handled Clients")
                            .font(.title2.weight(.black))
                            .foregroundStyle(Theme.ink)
                        Text("Clients you have handled or assisted today")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.muted)
                    }

                    Spacer()

                    Text("\(handledClients.count) Clients")
                        .font(.caption.weight(.black))
                        .foregroundStyle(Theme.gold)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Theme.selected, in: Capsule())
                }

                if handledClients.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "person.3.sequence.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(Theme.muted.opacity(0.6))
                            .padding(.top, 40)
                        Text("No Clients Handled Today")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(Theme.ink)
                        Text("Any sales checkout or profile update you complete will show up here.")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Theme.muted)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                    .frame(maxWidth: .infinity, minHeight: 280)
                } else {
                    VStack(spacing: 12) {
                        ForEach(handledClients) { client in
                            HStack(spacing: 16) {
                                ClientAvatar(initials: client.initials, size: 54)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(client.name)
                                        .font(.headline.weight(.bold))
                                        .foregroundStyle(Theme.ink)
                                    Text("\(client.phone) • \(client.boutique)")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(Theme.muted)
                                }

                                Spacer()

                                VStack(alignment: .trailing, spacing: 4) {
                                    Text(client.tier.uppercased())
                                        .font(.caption.weight(.black))
                                        .foregroundStyle(Theme.gold)
                                        .padding(.horizontal, 9)
                                        .padding(.vertical, 4)
                                        .background(Theme.selected, in: Capsule())
                                    
                                    Text(client.lifetimePurchaseText)
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(Theme.ink)
                                }
                            }
                            .padding(14)
                            .background(.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(Theme.line.opacity(0.4), lineWidth: 1)
                            )
                        }
                    }
                }
            }
            .padding(26)
        }
        .frame(minWidth: 460, minHeight: 520)
        .background(Theme.background)
    }
}

private struct DailyTasksSheet: View {
    @Binding var dailyTasks: [DBDailyTask]
    let associateId: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
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
                        ForEach(dailyTasks.indices, id: \.self) { index in
                            Button {
                                dailyTasks[index].isCompleted.toggle()
                                if !associateId.hasSuffix("-id") {
                                    let task = dailyTasks[index]
                                    Task {
                                        await SupabaseDBService.shared.updateDailyTaskStatus(taskId: task.id, isCompleted: task.isCompleted)
                                    }
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: dailyTasks[index].isCompleted ? "checkmark.circle.fill" : "circle")
                                        .font(.title3.weight(.bold))
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
                                .padding(14)
                                .background(.white.opacity(0.62), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .stroke(Theme.line.opacity(0.45), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(20)
            }
            .background(Theme.background)
            .navigationTitle("Daily Tasks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.headline)
                    .foregroundStyle(Theme.gold)
                }
            }
        }
        .frame(minWidth: 460, minHeight: 520)
    }
}

