import SwiftUI
import MapKit
import Combine

struct SellContent: View {
    let categories: [ProductCategory]
    let products: [SalesProduct]
    @Binding var session: SellingSessionState
    let onDiscardClient: () -> Void
    let onCreateProfile: (ClientProfile) -> Void
    let onCheckoutCompleted: (_ paidOrder: FrozenOrder?) -> Void
    var onOrderFinalized: (_ finalizedOrder: FrozenOrder, _ payment: PaymentSummary) -> Void = { _, _ in }

    @State private var query = ""
    @State private var selectedCategoryID: String
    @State private var selectedProduct: SalesProduct?
    @State private var returnPanelAfterProfile: SellingSessionPanel = .wishlist
    @State private var isFilterPresented = false
    @State private var audienceFilter = SellAudienceFilter.all
    @State private var availabilityFilter = SellAvailabilityFilter.all
    @State private var priceFilter = SellPriceFilter.all
    @State private var showsDiscountedOnly = false
    @State private var expandedCategoryIDs: Set<String> = []
    @State private var isTopSuggestionsExpanded = false
    @State private var paymentFulfillment: PaymentFulfillmentSummary?
    @State private var paymentSessionID = UUID()

    init(
        categories: [ProductCategory],
        products: [SalesProduct],
        session: Binding<SellingSessionState>,
        onDiscardClient: @escaping () -> Void,
        onCreateProfile: @escaping (ClientProfile) -> Void,
        onCheckoutCompleted: @escaping (_ paidOrder: FrozenOrder?) -> Void,
        onOrderFinalized: @escaping (_ finalizedOrder: FrozenOrder, _ payment: PaymentSummary) -> Void = { _, _ in }
    ) {
        self.categories = categories
        self.products = products
        _session = session
        self.onDiscardClient = onDiscardClient
        self.onCreateProfile = onCreateProfile
        self.onCheckoutCompleted = onCheckoutCompleted
        self.onOrderFinalized = onOrderFinalized
        _selectedCategoryID = State(initialValue: categories.first?.id ?? "")
    }

    private var activeCategoryTitle: String {
        categories.first(where: { $0.id == selectedCategoryID })?.title ?? "Products"
    }

    private var browserTitle: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? activeCategoryTitle : "Search Results"
    }

    private var filteredProducts: [SalesProduct] {
        let searchTerm = query.trimmingCharacters(in: .whitespacesAndNewlines)

        let baseProducts: [SalesProduct]
        if !searchTerm.isEmpty {
            baseProducts = products.filter { $0.matches(searchTerm) }
        } else {
            baseProducts = products.filter { $0.categoryID == selectedCategoryID }
        }

        return applyActiveFilters(to: baseProducts)
    }

    private var suggestedProducts: [SalesProduct] {
        let categoryMatches = applyActiveFilters(to: products.filter { $0.categoryID == selectedCategoryID })
        return categoryMatches.isEmpty ? applyActiveFilters(to: products) : categoryMatches
    }

    private var wishlistProducts: [SalesProduct] {
        products.filter { session.wishlistProductIDs.contains($0.id) }
    }

    private var cartProducts: [SalesProduct] {
        products.filter { session.cartProductIDs.contains($0.id) }
    }

    private var selectedPanelTitle: String {
        session.activePanel == .cart ? "View Cart" : "Wishlist"
    }

    private var isCategoryExpanded: Bool {
        expandedCategoryIDs.contains(selectedCategoryID)
    }

    private func applyActiveFilters(to sourceProducts: [SalesProduct]) -> [SalesProduct] {
        sourceProducts.filter { product in
            // Billing only browses sellable stock — out-of-stock products are hidden.
            product.isInStock
                && audienceFilter.matches(product)
                && availabilityFilter.matches(product)
                && priceFilter.matches(product)
                && (!showsDiscountedOnly || product.originalPrice != nil)
        }
    }

    private func toggleCurrentCategoryViewAll() {
        if expandedCategoryIDs.contains(selectedCategoryID) {
            expandedCategoryIDs.remove(selectedCategoryID)
        } else {
            expandedCategoryIDs.insert(selectedCategoryID)
        }
    }

    /// Persists the active client with the current session merged into their wishlist
    /// (cart items are folded in, de-duplicated), then closes the session and returns to Today.
    private func commitSessionToClient() {
        guard let client = session.createdClient else { return }
        let mergedWishlist = session.combinedWishlistProductIDs
        let updatedClient = client.updatingWishlist(mergedWishlist)
        onCreateProfile(updatedClient)
        onDiscardClient()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SellHeader(
                    session: session,
                    onCommitClient: session.hasCreatedProfile ? { commitSessionToClient() } : nil
                )

                if session.activePanel == nil {
                    SellSearchRow(
                        query: $query,
                        showsClientActions: session.hasActiveClient,
                        cartCount: session.cartItemCount,
                        onOpenFilters: {
                            isFilterPresented = true
                        },
                        onOpenWishlist: {
                            selectedProduct = nil
                            session.activePanel = .wishlist
                        },
                        onOpenCart: {
                            selectedProduct = nil
                            session.activePanel = .cart
                        }
                    )

                    CategoryStrip(
                        categories: categories,
                        selectedCategoryID: selectedCategoryID
                    ) { category in
                        selectedCategoryID = category.id
                        selectedProduct = nil
                        query = ""
                        isTopSuggestionsExpanded = false
                        session.activePanel = nil
                    }
                }

                if session.activePanel == .wishlist {
                    collectionPanelLayout(
                        panel: .wishlist,
                        products: wishlistProducts,
                        count: session.wishlistItemCount,
                        title: "Wishlist",
                        subtitle: "Saved for \(session.displayName)",
                        emptyTitle: "No wishlist items yet",
                        emptySubtitle: "Tap the heart on product cards to save pieces here.",
                        primaryActionTitle: "Move All Items to Cart",
                        primaryActionIcon: "bag.badge.plus",
                        quantityForProduct: { _ in nil },
                        onMoveProductToCart: { product in
                            session.moveToCart(product)
                            if selectedProduct?.id == product.id {
                                selectedProduct = nil
                            }
                        },
                        onPrimaryAction: {
                            session.moveWishlistToCart()
                            selectedProduct = nil
                        }
                    )
                } else if session.activePanel == .cart {
                    collectionPanelLayout(
                        panel: .cart,
                        products: cartProducts,
                        count: session.cartItemCount,
                        title: "View Cart",
                        subtitle: "Cart for \(session.displayName)",
                        emptyTitle: "Cart is empty",
                        emptySubtitle: "Use Add to Cart from product details to build this order.",
                        primaryActionTitle: "Proceed",
                        primaryActionIcon: "arrow.right.circle",
                        quantityForProduct: { product in
                            session.quantity(for: product)
                        },
                        onIncrementQuantity: { product in
                            session.incrementCartQuantity(for: product)
                        },
                        onDecrementQuantity: { product in
                            session.decrementCartQuantity(for: product)
                        },
                        onPrimaryAction: {
                            selectedProduct = nil
                            session.activePanel = .fulfillment
                        }
                    )
                } else if session.activePanel == .fulfillment {
                    CheckoutFulfillmentPanel(
                        client: session.createdClient,
                        onBack: {
                            session.activePanel = .cart
                        },
                        onSaveDefaultAddress: { updatedClient in
                            session.createdClient = updatedClient
                            onCreateProfile(updatedClient)
                        },
                        onProceedToPay: { fulfillment in
                            paymentFulfillment = fulfillment
                            paymentSessionID = UUID()   // fresh payment view built from the current cart
                            session.activePanel = .payment
                        }
                    )
                } else if session.activePanel == .payment {
                    PaymentFlowView(
                        products: products,
                        session: session,
                        fulfillment: paymentFulfillment ?? PaymentFulfillmentSummary(kind: .pickup, address: nil),
                        onExit: {
                            session.activePanel = .fulfillment
                        },
                        onCompleted: { paidOrder in
                            onCheckoutCompleted(paidOrder)
                        },
                        onOrderFinalized: { finalizedOrder, payment in
                            onOrderFinalized(finalizedOrder, payment)
                        }
                    )
                    .id(paymentSessionID)
                } else if session.activePanel == .createProfile {
                    CreateClientProfilePanel(
                        guestID: session.guestID ?? "Guest",
                        onBack: {
                            session.activePanel = returnPanelAfterProfile
                        },
                        onSave: { profile in
                            session.createdClient = profile
                            session.activePanel = returnPanelAfterProfile
                            onCreateProfile(profile)
                        }
                    )
                } else if let selectedProduct {
                    HStack(alignment: .top, spacing: 18) {
                        SellProductBrowser(
                            title: browserTitle,
                            products: filteredProducts,
                            suggestedProducts: suggestedProducts,
                            selectedProduct: selectedProduct,
                            allowsWishlist: session.hasActiveClient,
                            isExpanded: isCategoryExpanded,
                            isTopSuggestionsExpanded: isTopSuggestionsExpanded,
                            isWishlisted: { product in
                                session.isWishlisted(product)
                            },
                            onToggleWishlist: { product in
                                session.toggleWishlist(product)
                            },
                            onToggleTopSuggestions: {
                                isTopSuggestionsExpanded.toggle()
                            },
                            onToggleViewAll: {
                                toggleCurrentCategoryViewAll()
                            }
                        ) { product in
                            self.selectedProduct = product
                        }
                        .frame(maxWidth: .infinity)

                        SellProductDetailCard(
                            product: selectedProduct,
                            allowsClientActions: session.hasActiveClient,
                            isWishlisted: session.isWishlisted(selectedProduct),
                            onClose: {
                                self.selectedProduct = nil
                            },
                            onToggleWishlist: {
                                session.toggleWishlist(selectedProduct)
                            },
                            onAddToCart: { quantity in
                                session.addToCart(selectedProduct, quantity: quantity)
                            }
                        )
                            .id(selectedProduct.id)
                            .frame(width: 390)
                            .transition(.opacity.combined(with: .move(edge: .trailing)))
                    }
                } else {
                    SellProductBrowser(
                        title: browserTitle,
                        products: filteredProducts,
                        suggestedProducts: suggestedProducts,
                        selectedProduct: nil,
                        allowsWishlist: session.hasActiveClient,
                        isExpanded: isCategoryExpanded,
                        isTopSuggestionsExpanded: isTopSuggestionsExpanded,
                        isWishlisted: { product in
                            session.isWishlisted(product)
                        },
                        onToggleWishlist: { product in
                            session.toggleWishlist(product)
                        },
                        onToggleTopSuggestions: {
                            isTopSuggestionsExpanded.toggle()
                        },
                        onToggleViewAll: {
                            toggleCurrentCategoryViewAll()
                        }
                    ) { product in
                        selectedProduct = product
                        session.activePanel = nil
                    }
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 22)
        }
        .scrollIndicators(.hidden)
        .animation(.snappy(duration: 0.28), value: selectedProduct)
        .sheet(isPresented: $isFilterPresented) {
            SellFilterPanel(
                audienceFilter: $audienceFilter,
                availabilityFilter: $availabilityFilter,
                priceFilter: $priceFilter,
                showsDiscountedOnly: $showsDiscountedOnly
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        // Persist wishlist/cart changes for an existing client straight to
        // client_profiles (by product id) as items are added or removed — not only
        // when the session is committed.
        .onChange(of: session.combinedWishlistProductIDs) { _, newProductIDs in
            guard let client = session.createdClient else { return }
            let updatedClient = client.updatingWishlist(newProductIDs)
            Task {
                do {
                    try await SupabaseDBService.shared.upsertProfile(updatedClient)
                } catch {
                    #if DEBUG
                    print("Failed to persist client wishlist to Supabase: \(error)")
                    #endif
                }
            }
        }
    }

    @ViewBuilder
    private func collectionPanelLayout(
        panel: SellingSessionPanel,
        products: [SalesProduct],
        count: Int,
        title: String,
        subtitle: String,
        emptyTitle: String,
        emptySubtitle: String,
        primaryActionTitle: String,
        primaryActionIcon: String,
        quantityForProduct: @escaping (SalesProduct) -> Int?,
        onIncrementQuantity: ((SalesProduct) -> Void)? = nil,
        onDecrementQuantity: ((SalesProduct) -> Void)? = nil,
        onMoveProductToCart: ((SalesProduct) -> Void)? = nil,
        onPrimaryAction: @escaping () -> Void
    ) -> some View {
        HStack(alignment: .top, spacing: 18) {
            SellingCollectionPanel(
                title: title,
                subtitle: subtitle,
                emptyTitle: emptyTitle,
                emptySubtitle: emptySubtitle,
                products: products,
                itemCount: count,
                hasCreatedProfile: session.hasCreatedProfile,
                primaryActionTitle: primaryActionTitle,
                primaryActionIcon: primaryActionIcon,
                quantityForProduct: quantityForProduct,
                onIncrementQuantity: onIncrementQuantity,
                onDecrementQuantity: onDecrementQuantity,
                onMoveProductToCart: onMoveProductToCart,
                onSelectProduct: { product in
                    selectedProduct = product
                },
                onBack: {
                    selectedProduct = nil
                    session.activePanel = nil
                },
                onDiscardClient: onDiscardClient,
                onProceed: {
                    returnPanelAfterProfile = panel
                    session.activePanel = .createProfile
                },
                onPrimaryAction: onPrimaryAction
            )
            .frame(maxWidth: .infinity)

            if let selectedProduct {
                SellProductDetailCard(
                    product: selectedProduct,
                    allowsClientActions: session.hasActiveClient,
                    isWishlisted: session.isWishlisted(selectedProduct),
                    onClose: {
                        self.selectedProduct = nil
                    },
                    onToggleWishlist: {
                        session.toggleWishlist(selectedProduct)
                    },
                    onAddToCart: { quantity in
                        session.addToCart(selectedProduct, quantity: quantity)
                    }
                )
                .id("\(selectedPanelTitle)-\(selectedProduct.id)")
                .frame(width: 390)
                .transition(.opacity.combined(with: .move(edge: .trailing)))
            }
        }
    }
}

private struct SellHeader: View {
    let session: SellingSessionState
    var onCommitClient: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Sell")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.ink)
            }

            Spacer()

            if session.hasActiveClient {
                clientBadge
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var clientBadge: some View {
        let badge = Text(session.displayName)
            .font(.headline.weight(.black))
            .foregroundStyle(Theme.gold)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Theme.selected, in: Capsule())

        if session.hasCreatedProfile, let onCommitClient {
            Button(action: onCommitClient) { badge }
                .buttonStyle(.plain)
                .accessibilityLabel("Save \(session.displayName) and return to Today")
        } else {
            badge
        }
    }
}

private struct SellSearchRow: View {
    @Binding var query: String
    let showsClientActions: Bool
    let cartCount: Int
    let onOpenFilters: () -> Void
    let onOpenWishlist: () -> Void
    let onOpenCart: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Theme.muted)

                TextField("Search product name or product ID", text: $query)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.search)
            }
            .font(.headline.weight(.semibold))
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
            .background(.white.opacity(0.72), in: Capsule())
            .overlay(
                Capsule()
                    .stroke(Theme.line.opacity(0.55), lineWidth: 1)
            )

            ToolbarPillButton(title: "Filters", icon: "slider.horizontal.3", action: onOpenFilters)
            if showsClientActions {
                ToolbarPillButton(
                    title: "Wishlist",
                    icon: "heart",
                    action: onOpenWishlist
                )
                ToolbarPillButton(
                    title: "View Cart",
                    icon: "bag",
                    count: cartCount,
                    showsCount: true,
                    action: onOpenCart
                )
            }
        }
    }
}

private struct ToolbarPillButton: View {
    let title: String
    let icon: String
    var count: Int = 0
    var showsCount: Bool = false
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: icon)
                    .font(.title2.weight(.black))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 54, height: 54)

                if showsCount, count > 0 {
                    Text("\(count)")
                        .font(.caption2.weight(.black))
                        .foregroundStyle(.white)
                        .frame(minWidth: 18, minHeight: 18)
                        .background(Theme.goldGradient, in: Circle())
                        .overlay(
                            Circle()
                                .stroke(.white.opacity(0.92), lineWidth: 1.5)
                        )
                        .offset(x: 5, y: 3)
                        .accessibilityHidden(true)
                }
            }
            .frame(width: 54, height: 54)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(showsCount && count > 0 ? "\(title), \(count) items" : title)
    }
}

private struct CategoryStrip: View {
    let categories: [ProductCategory]
    let selectedCategoryID: String
    let onSelect: (ProductCategory) -> Void

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 22) {
                ForEach(categories) { category in
                    Button {
                        onSelect(category)
                    } label: {
                        VStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(selectedCategoryID == category.id ? AnyShapeStyle(Theme.goldGradient) : AnyShapeStyle(.white.opacity(0.85)))
                                    .shadow(color: .black.opacity(selectedCategoryID == category.id ? 0.12 : 0.04), radius: 8, x: 0, y: 4)
                                
                                Image(systemName: category.icon)
                                    .font(.system(size: 22, weight: .medium))
                                    .foregroundStyle(selectedCategoryID == category.id ? .white : Theme.ink)
                            }
                            .frame(width: 64, height: 64)
                            .overlay(
                                Circle()
                                    .stroke(selectedCategoryID == category.id ? Theme.gold.opacity(0.3) : Theme.line.opacity(0.55), lineWidth: 1)
                            )
                            
                            Text(category.title)
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(selectedCategoryID == category.id ? Theme.gold : Theme.ink)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 6)
        }
        .scrollIndicators(.hidden)
    }
}

private enum SellAudienceFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case women = "Women"
    case men = "Men"

    var id: String { rawValue }

    func matches(_ product: SalesProduct) -> Bool {
        switch self {
        case .all:
            return true
        case .women, .men:
            return product.audience.localizedCaseInsensitiveContains(rawValue)
        }
    }
}

private enum SellAvailabilityFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case inBoutique = "In Boutique"
    case transfer = "Transfer"
    case limited = "Limited"

    var id: String { rawValue }

    func matches(_ product: SalesProduct) -> Bool {
        switch self {
        case .all:
            return true
        case .inBoutique:
            return product.availability.localizedCaseInsensitiveContains("boutique")
        case .transfer:
            return product.availability.localizedCaseInsensitiveContains("transfer")
                || product.stockNote.localizedCaseInsensitiveContains("transfer")
                || product.availability.localizedCaseInsensitiveContains("store manager")
        case .limited:
            return product.badge?.localizedCaseInsensitiveContains("limited") == true
                || product.stockNote.localizedCaseInsensitiveContains("limited")
        }
    }
}

private enum SellPriceFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case underOnePointFive = "Under Rs. 1.5L"
    case onePointFiveToThree = "Rs. 1.5L - 3L"
    case aboveThree = "Above Rs. 3L"

    var id: String { rawValue }

    func matches(_ product: SalesProduct) -> Bool {
        guard let price = product.priceInLakhs else {
            return self == .all
        }

        switch self {
        case .all:
            return true
        case .underOnePointFive:
            return price < 1.5
        case .onePointFiveToThree:
            return price >= 1.5 && price <= 3
        case .aboveThree:
            return price > 3
        }
    }
}

private extension SalesProduct {
    var priceInLakhs: Double? {
        let normalized = price
            .replacingOccurrences(of: "Rs.", with: "")
            .replacingOccurrences(of: "₹", with: "")
            .replacingOccurrences(of: "L", with: "")
            .replacingOccurrences(of: " ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return Double(normalized)
    }
}

private struct SellFilterPanel: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var audienceFilter: SellAudienceFilter
    @Binding var availabilityFilter: SellAvailabilityFilter
    @Binding var priceFilter: SellPriceFilter
    @Binding var showsDiscountedOnly: Bool

    var body: some View {
        ZStack {
            Theme.background
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Filters")
                            .font(.system(size: 34, weight: .black, design: .rounded))
                            .foregroundStyle(Theme.ink)
                        Text("Refine the visible catalogue for this client conversation.")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.muted)
                    }

                    Spacer()

                    Button {
                        resetFilters()
                    } label: {
                        Text("Reset")
                            .font(.headline.weight(.black))
                            .foregroundStyle(Theme.gold)
                            .padding(.horizontal, 16)
                            .frame(height: 44)
                            .background(Theme.selected, in: Capsule())
                    }
                    .buttonStyle(.plain)

                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.headline.weight(.black))
                            .foregroundStyle(Theme.ink)
                            .frame(width: 44, height: 44)
                            .background(.white.opacity(0.72), in: Circle())
                    }
                    .buttonStyle(.plain)
                }

                HStack(alignment: .top, spacing: 16) {
                    FilterSection(title: "Audience") {
                        FilterChipWrap {
                            ForEach(SellAudienceFilter.allCases) { option in
                                SellFilterChip(
                                    title: option.rawValue,
                                    isSelected: audienceFilter == option
                                ) {
                                    audienceFilter = option
                                }
                            }
                        }
                    }

                    FilterSection(title: "Availability") {
                        FilterChipWrap {
                            ForEach(SellAvailabilityFilter.allCases) { option in
                                SellFilterChip(
                                    title: option.rawValue,
                                    isSelected: availabilityFilter == option
                                ) {
                                    availabilityFilter = option
                                }
                            }
                        }
                    }
                }

                HStack(alignment: .top, spacing: 16) {
                    FilterSection(title: "Price Range") {
                        FilterChipWrap {
                            ForEach(SellPriceFilter.allCases) { option in
                                SellFilterChip(
                                    title: option.rawValue,
                                    isSelected: priceFilter == option
                                ) {
                                    priceFilter = option
                                }
                            }
                        }
                    }

                    FilterSection(title: "Offers") {
                        Toggle(isOn: $showsDiscountedOnly) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Discounted pieces only")
                                    .font(.headline.weight(.black))
                                    .foregroundStyle(Theme.ink)
                                Text("Show products that have a listed original price.")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Theme.muted)
                            }
                        }
                        .toggleStyle(.switch)
                        .tint(Theme.gold)
                        .padding(16)
                        .background(.white.opacity(0.58), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }
                }

                Spacer(minLength: 0)

                Button {
                    dismiss()
                } label: {
                    Label("Apply Filters", systemImage: "checkmark")
                        .font(.headline.weight(.black))
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .foregroundStyle(.white)
                        .background(Theme.goldGradient, in: Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(28)
        }
    }

    private func resetFilters() {
        audienceFilter = .all
        availabilityFilter = .all
        priceFilter = .all
        showsDiscountedOnly = false
    }
}

private struct FilterSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                Text(title)
                    .font(.headline.weight(.black))
                    .foregroundStyle(Theme.ink)
                content
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }
}

private struct FilterChipWrap<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 10) {
                content
            }
            .padding(.vertical, 1)
        }
        .scrollIndicators(.hidden)
    }
}

private struct SellFilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.black))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .padding(.horizontal, 14)
                .frame(height: 42)
                .foregroundStyle(isSelected ? .white : Theme.ink)
                .background(
                    isSelected ? AnyShapeStyle(Theme.goldGradient) : AnyShapeStyle(.white.opacity(0.68)),
                    in: Capsule()
                )
                .overlay(
                    Capsule()
                        .stroke(Theme.line.opacity(0.55), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

private struct SellProductBrowser: View {
    let title: String
    let products: [SalesProduct]
    let suggestedProducts: [SalesProduct]
    let selectedProduct: SalesProduct?
    let allowsWishlist: Bool
    let isExpanded: Bool
    let isTopSuggestionsExpanded: Bool
    let isWishlisted: (SalesProduct) -> Bool
    let onToggleWishlist: (SalesProduct) -> Void
    let onToggleTopSuggestions: () -> Void
    let onToggleViewAll: () -> Void
    let onSelect: (SalesProduct) -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 176), spacing: 14)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            SuggestedProductsRow(
                products: suggestedProducts,
                allowsWishlist: allowsWishlist,
                isExpanded: isTopSuggestionsExpanded,
                isWishlisted: isWishlisted,
                onToggleWishlist: onToggleWishlist,
                onToggleViewAll: onToggleTopSuggestions,
                onSelect: onSelect
            )

            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text(title)
                        .font(.title2.weight(.black))

                    Spacer()

                    if !products.isEmpty {
                        Button(action: onToggleViewAll) {
                            Text(isExpanded ? "Show Less" : "View All")
                                .font(.caption.weight(.black))
                                .foregroundStyle(Theme.gold)
                                .padding(.horizontal, 13)
                                .padding(.vertical, 8)
                                .background(Theme.selected, in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }

                Card {
                    Group {
                        if products.isEmpty {
                            VStack(spacing: 10) {
                                Image(systemName: "magnifyingglass")
                                    .font(.title.weight(.bold))
                                    .foregroundStyle(Theme.gold)
                                Text("No products found")
                                    .font(.headline.weight(.bold))
                                Text("Try another product name, product ID, or category.")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Theme.muted)
                            }
                            .frame(maxWidth: .infinity, minHeight: 220)
                        } else if isExpanded {
                            LazyVGrid(columns: columns, spacing: 14) {
                                ForEach(products) { product in
                                    ProductGridCard(
                                        product: product,
                                        isSelected: selectedProduct == product,
                                        allowsWishlist: allowsWishlist,
                                        isWishlisted: isWishlisted(product),
                                        onToggleWishlist: {
                                            onToggleWishlist(product)
                                        }
                                    ) {
                                        onSelect(product)
                                    }
                                    .frame(height: 288)
                                }
                            }
                        } else {
                            ScrollView(.horizontal) {
                                HStack(spacing: 14) {
                                    ForEach(Array(products.prefix(10))) { product in
                                        ProductGridCard(
                                            product: product,
                                            isSelected: selectedProduct == product,
                                            allowsWishlist: allowsWishlist,
                                            isWishlisted: isWishlisted(product),
                                            onToggleWishlist: {
                                                onToggleWishlist(product)
                                            }
                                        ) {
                                            onSelect(product)
                                        }
                                        .frame(width: 176, height: 288)
                                    }
                                }
                            }
                            .scrollIndicators(.hidden)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }
}

private struct SuggestedProductsRow: View {
    let products: [SalesProduct]
    let allowsWishlist: Bool
    let isExpanded: Bool
    let isWishlisted: (SalesProduct) -> Bool
    let onToggleWishlist: (SalesProduct) -> Void
    let onToggleViewAll: () -> Void
    let onSelect: (SalesProduct) -> Void

    private let visibleLimit = 10
    private let columns = [
        GridItem(.adaptive(minimum: 170), spacing: 12)
    ]

    private var visibleProducts: [SalesProduct] {
        isExpanded ? products : Array(products.prefix(visibleLimit))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Popular")
                    .font(.title2.weight(.black))
                Spacer()

                if products.count > visibleLimit {
                    Button(action: onToggleViewAll) {
                        Text(isExpanded ? "Show Less" : "View All")
                            .font(.caption.weight(.black))
                            .foregroundStyle(Theme.gold)
                            .padding(.horizontal, 13)
                            .padding(.vertical, 8)
                            .background(Theme.selected, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }

            Card {
                if isExpanded {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(visibleProducts) { product in
                            SuggestedProductCard(
                                product: product,
                                allowsWishlist: allowsWishlist,
                                isWishlisted: isWishlisted(product),
                                onToggleWishlist: {
                                    onToggleWishlist(product)
                                }
                            ) {
                                onSelect(product)
                            }
                            .frame(height: 202)
                        }
                    }
                } else {
                    ScrollView(.horizontal) {
                        HStack(spacing: 12) {
                            ForEach(visibleProducts) { product in
                                SuggestedProductCard(
                                    product: product,
                                    allowsWishlist: allowsWishlist,
                                    isWishlisted: isWishlisted(product),
                                    onToggleWishlist: {
                                        onToggleWishlist(product)
                                    }
                                ) {
                                    onSelect(product)
                                }
                                .frame(width: 170, height: 202)
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                }
            }
        }
    }
}

private struct SuggestedProductCard: View {
    let product: SalesProduct
    let allowsWishlist: Bool
    let isWishlisted: Bool
    let onToggleWishlist: () -> Void
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ProductImageView(imageName: product.imageName)
                .frame(height: 118)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(alignment: .topTrailing) {
                    if allowsWishlist {
                        Button(action: onToggleWishlist) {
                            Image(systemName: isWishlisted ? "heart.fill" : "heart")
                                .font(.caption.weight(.black))
                                .foregroundStyle(isWishlisted ? Theme.gold : Theme.ink)
                                .frame(width: 30, height: 30)
                                .background(.white.opacity(0.82), in: Circle())
                                .padding(7)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(isWishlisted ? "Remove from wishlist" : "Add to wishlist")
                    }
                }

            Text(product.name)
                .font(.subheadline.weight(.black))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .frame(height: 18, alignment: .leading)

            Text(product.price)
                .font(.caption.weight(.bold))
                .foregroundStyle(Theme.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .padding(10)
        .background(.white.opacity(0.58), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Theme.line.opacity(0.45), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .onTapGesture(perform: onTap)
    }
}

private struct ProductGridCard: View {
    let product: SalesProduct
    let isSelected: Bool
    let allowsWishlist: Bool
    let isWishlisted: Bool
    let onToggleWishlist: () -> Void
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ProductImageView(imageName: product.imageName)
                .frame(height: 142)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(alignment: .topTrailing) {
                    if allowsWishlist {
                        Button(action: onToggleWishlist) {
                            Image(systemName: isWishlisted ? "heart.fill" : "heart")
                                .font(.subheadline.weight(.black))
                                .foregroundStyle(isWishlisted ? Theme.gold : Theme.ink)
                                .frame(width: 34, height: 34)
                                .background(.white.opacity(0.78), in: Circle())
                                .padding(8)
                        }
                        .buttonStyle(.plain)
                    }
                }

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(product.name)
                        .font(.headline.weight(.black))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                    Text("\(product.audience) • \(product.id)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.muted)
                        .lineLimit(1)
                    if !product.existsInDB {
                        Text("Not in DB • Need DB Sync")
                            .font(.system(size: 9, weight: .black))
                            .foregroundStyle(.red)
                    }
                }

                Spacer(minLength: 8)
            }

            HStack {
                Text(product.price)
                    .font(.subheadline.weight(.black))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                Spacer()

                if let badge = product.badge {
                    Text(badge)
                        .font(.caption2.weight(.black))
                        .foregroundStyle(Theme.gold)
                        .lineLimit(1)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Theme.selected, in: Capsule())
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 288, maxHeight: 288, alignment: .topLeading)
        .background(isSelected ? Theme.selected.opacity(0.82) : .white.opacity(0.62), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(isSelected ? Theme.gold.opacity(0.45) : Theme.line.opacity(0.45), lineWidth: 1.2)
        )
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .onTapGesture(perform: onTap)
    }
}

private struct SellProductDetailCard: View {
    let product: SalesProduct
    let allowsClientActions: Bool
    let isWishlisted: Bool
    let onClose: () -> Void
    let onToggleWishlist: () -> Void
    let onAddToCart: (Int) -> Void

    @State private var selectedSize: String
    @State private var selectedMaterial: String
    @State private var selectedColor: String
    @State private var quantity = 1

    init(
        product: SalesProduct,
        allowsClientActions: Bool,
        isWishlisted: Bool,
        onClose: @escaping () -> Void,
        onToggleWishlist: @escaping () -> Void,
        onAddToCart: @escaping (Int) -> Void
    ) {
        self.product = product
        self.allowsClientActions = allowsClientActions
        self.isWishlisted = isWishlisted
        self.onClose = onClose
        self.onToggleWishlist = onToggleWishlist
        self.onAddToCart = onAddToCart
        _selectedSize = State(initialValue: product.sizes.first ?? "One size")
        _selectedMaterial = State(initialValue: product.materials.first ?? "Standard")
        _selectedColor = State(initialValue: product.colors.first ?? "Default")
        _quantity = State(initialValue: product.stockQuantity > 0 ? 1 : 0)
    }

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 16) {
                ProductImageView(imageName: product.imageName)
                    .frame(height: 248)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .overlay(alignment: .topLeading) {
                        Button(action: onClose) {
                            Image(systemName: "xmark")
                            .font(.headline.weight(.black))
                            .foregroundStyle(Theme.ink)
                            .frame(width: 42, height: 42)
                            .background(.white.opacity(0.78), in: Circle())
                            .padding(12)
                        }
                        .buttonStyle(.plain)
                    }

                VStack(alignment: .leading, spacing: 6) {
                    Text(product.name)
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(2)

                    HStack(spacing: 10) {
                        Text(product.price)
                            .font(.title3.weight(.black))
                        if let originalPrice = product.originalPrice {
                            Text(originalPrice)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(Theme.muted)
                                .strikethrough()
                        }
                    }

                    if !product.existsInDB {
                        Text("Product not found in database. Need DB Sync.")
                            .font(.subheadline.weight(.black))
                            .foregroundStyle(.red)
                            .padding(.top, 2)
                    }

                    Text(product.suggestedReason)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                ProductOptionSection(title: "Size", options: product.sizes, selectedValue: $selectedSize)
                ProductOptionSection(title: "Material", options: product.materials, selectedValue: $selectedMaterial)
                ProductOptionSection(title: "Color", options: product.colors, selectedValue: $selectedColor)

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Quantity")
                            .font(.caption.weight(.black))
                            .tracking(1)
                            .foregroundStyle(Theme.muted)
                        Text("\(quantity)")
                            .font(.title2.weight(.black))
                    }

                    Spacer()

                    HStack(spacing: 10) {
                        QuantityButton(symbol: "minus") {
                            quantity = max(product.stockQuantity > 0 ? 1 : 0, quantity - 1)
                        }
                        QuantityButton(symbol: "plus") {
                            quantity = min(quantity + 1, product.stockQuantity)
                        }
                    }
                }
                .padding(14)
                .background(.white.opacity(0.58), in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                VStack(alignment: .leading, spacing: 6) {
                    Label(product.availability, systemImage: "checkmark.seal")
                        .font(.headline.weight(.black))
                        .foregroundStyle(Theme.gold)
                    Text(product.stockNote)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.muted)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.selected.opacity(0.62), in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                if allowsClientActions {
                    HStack(spacing: 12) {
                        Button(action: onToggleWishlist) {
                            Label(isWishlisted ? "Saved" : "Wishlist", systemImage: isWishlisted ? "heart.fill" : "heart")
                                .font(.headline.weight(.black))
                                .frame(maxWidth: .infinity, minHeight: 54)
                                .foregroundStyle(Theme.ink)
                                .background(.white.opacity(0.76), in: Capsule())
                                .overlay(
                                    Capsule()
                                        .stroke(Theme.line.opacity(0.55), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)

                        Button {
                            onAddToCart(quantity)
                        } label: {
                            Label(product.stockQuantity > 0 ? "Add to Cart" : "Out of Stock", systemImage: product.stockQuantity > 0 ? "bag.badge.plus" : "exclamationmark.triangle")
                                .font(.headline.weight(.black))
                                .frame(maxWidth: .infinity, minHeight: 54)
                                .foregroundStyle(product.stockQuantity > 0 ? .white : Theme.muted)
                                .background(product.stockQuantity > 0 ? AnyShapeStyle(Theme.goldGradient) : AnyShapeStyle(Color.gray.opacity(0.24)), in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .disabled(product.stockQuantity == 0)
                    }
                }
            }
        }
    }
}

private enum CheckoutFulfillmentMethod: String, CaseIterable, Identifiable {
    case pickup
    case delivery

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pickup:
            return "Take from Store"
        case .delivery:
            return "Deliver to Address"
        }
    }

    var subtitle: String {
        switch self {
        case .pickup:
            return "Client will take products from the boutique now."
        case .delivery:
            return "Search the delivery address before payment."
        }
    }

    var icon: String {
        switch self {
        case .pickup:
            return "bag.fill"
        case .delivery:
            return "shippingbox.fill"
        }
    }
}

private struct AddressSuggestion: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let subtitle: String

    var displayText: String {
        let cleanSubtitle = subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanSubtitle.isEmpty else { return title }
        return "\(title), \(cleanSubtitle)"
    }
}

private final class AddressSearchCompleter: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var query = "" {
        didSet {
            let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmedQuery.count >= 2 else {
                suggestions = []
                completer.queryFragment = ""
                return
            }

            completer.queryFragment = trimmedQuery
        }
    }

    @Published var suggestions: [AddressSuggestion] = []

    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = .address
        completer.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 19.0760, longitude: 72.8777),
            span: MKCoordinateSpan(latitudeDelta: 0.70, longitudeDelta: 0.70)
        )
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let updatedSuggestions = completer.results.prefix(6).map {
            AddressSuggestion(title: $0.title, subtitle: $0.subtitle)
        }

        DispatchQueue.main.async {
            self.suggestions = updatedSuggestions
        }
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.suggestions = []
        }
    }
}

private struct CheckoutFulfillmentPanel: View {
    let client: ClientProfile?
    let onBack: () -> Void
    let onSaveDefaultAddress: (ClientProfile) -> Void
    let onProceedToPay: (PaymentFulfillmentSummary) -> Void

    @State private var method: CheckoutFulfillmentMethod = .pickup
    @StateObject private var addressCompleter = AddressSearchCompleter()
    @State private var buildingDetail = ""
    @State private var shouldSaveDefaultAddress = false
    @State private var showsAddressSuggestions = false
    @State private var didContinueToPayment = false
    @State private var didPrepareDefaultAddress = false

    private var resolvedAddress: String {
        addressCompleter.query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var resolvedBuildingDetail: String {
        buildingDetail.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canProceedToPay: Bool {
        method == .pickup || !resolvedAddress.isEmpty
    }

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 14) {
                    ClientPanelBackButton(action: onBack)

                    VStack(alignment: .leading, spacing: 5) {
                        Text("Fulfillment")
                            .font(.title2.weight(.black))
                            .foregroundStyle(Theme.ink)
                        Text("Choose how the client wants to take the products.")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.muted)
                    }

                    Spacer()

                    Text(client?.name ?? "Guest")
                        .font(.caption.weight(.black))
                        .foregroundStyle(Theme.gold)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Theme.selected, in: Capsule())
                }

                HStack(spacing: 14) {
                    ForEach(CheckoutFulfillmentMethod.allCases) { option in
                        FulfillmentMethodButton(
                            option: option,
                            isSelected: method == option
                        ) {
                            method = option
                            didContinueToPayment = false
                        }
                    }
                }

                if method == .pickup {
                    PickupSummaryCard()
                        .transition(.opacity.combined(with: .move(edge: .top)))
                } else {
                    DeliveryAddressSection(
                        query: Binding(
                            get: { addressCompleter.query },
                            set: { newValue in
                                addressCompleter.query = newValue
                                showsAddressSuggestions = true
                                didContinueToPayment = false
                            }
                        ),
                        buildingDetail: $buildingDetail,
                        shouldSaveDefaultAddress: $shouldSaveDefaultAddress,
                        suggestions: addressCompleter.suggestions,
                        showsSuggestions: showsAddressSuggestions,
                        defaultAddress: client?.defaultDeliveryAddress,
                        onUseDefaultAddress: useDefaultAddress,
                        onSelectSuggestion: selectAddressSuggestion
                    )
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                Spacer(minLength: 0)

                if didContinueToPayment {
                    Label("Ready to continue payment at POS", systemImage: "checkmark.seal.fill")
                        .font(.subheadline.weight(.black))
                        .foregroundStyle(Theme.gold)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.selected.opacity(0.66), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }

                Button {
                    saveDefaultAddressIfNeeded()
                    onProceedToPay(
                        PaymentFulfillmentSummary(
                            kind: method == .pickup ? .pickup : .delivery,
                            address: method == .delivery ? resolvedAddress : nil
                        )
                    )
                } label: {
                    Label("Proceed to Pay", systemImage: "creditcard")
                        .font(.headline.weight(.black))
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .foregroundStyle(.white)
                        .background(Theme.goldGradient, in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(!canProceedToPay)
                .opacity(canProceedToPay ? 1 : 0.55)
            }
            .frame(maxWidth: .infinity, minHeight: 560, alignment: .topLeading)
            .animation(.snappy(duration: 0.24), value: method)
            .onAppear(perform: prepareDefaultAddress)
        }
    }

    private func prepareDefaultAddress() {
        guard !didPrepareDefaultAddress else { return }
        didPrepareDefaultAddress = true

        guard let client else { return }
        if let defaultAddress = client.defaultDeliveryAddress, !defaultAddress.isEmpty {
            addressCompleter.query = defaultAddress
        }
        buildingDetail = client.deliveryAddressDetail ?? ""
    }

    private func useDefaultAddress() {
        guard let client, let defaultAddress = client.defaultDeliveryAddress else { return }
        addressCompleter.query = defaultAddress
        buildingDetail = client.deliveryAddressDetail ?? ""
        shouldSaveDefaultAddress = false
        showsAddressSuggestions = false
        didContinueToPayment = false
    }

    private func selectAddressSuggestion(_ suggestion: AddressSuggestion) {
        addressCompleter.query = suggestion.displayText
        showsAddressSuggestions = false
        didContinueToPayment = false
    }

    private func saveDefaultAddressIfNeeded() {
        guard method == .delivery,
              shouldSaveDefaultAddress,
              let client,
              !resolvedAddress.isEmpty
        else {
            return
        }

        onSaveDefaultAddress(
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
                followUpDate: client.followUpDate,
                tier: client.tier,
                lifetimePurchaseAmount: client.lifetimePurchaseAmount,
                boutique: client.boutique,
                status: client.status,
                note: client.note,
                attributes: client.attributes,
                tasks: client.tasks,
                purchaseHistory: client.purchaseHistory,
                wishlistProductIDs: client.wishlistProductIDs,
                defaultDeliveryAddress: resolvedAddress,
                deliveryAddressDetail: resolvedBuildingDetail.isEmpty ? nil : resolvedBuildingDetail
            )
        )
    }
}

private struct FulfillmentMethodButton: View {
    let option: CheckoutFulfillmentMethod
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: option.icon)
                    .font(.headline.weight(.black))
                    .foregroundStyle(isSelected ? .white : Theme.gold)
                    .frame(width: 44, height: 44)
                    .background(isSelected ? .white.opacity(0.20) : Theme.selected, in: RoundedRectangle(cornerRadius: 15, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(option.title)
                        .font(.headline.weight(.black))
                    Text(option.subtitle)
                        .font(.subheadline.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                        .opacity(0.78)
                }

                Spacer()
            }
            .padding(15)
            .frame(maxWidth: .infinity, minHeight: 102)
            .foregroundStyle(isSelected ? .white : Theme.ink)
            .background(isSelected ? AnyShapeStyle(Theme.goldGradient) : AnyShapeStyle(.white.opacity(0.58)), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(isSelected ? .white.opacity(0.22) : Theme.line.opacity(0.45), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct PickupSummaryCard: View {
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "storefront.fill")
                .font(.title2.weight(.black))
                .foregroundStyle(Theme.gold)
                .frame(width: 58, height: 58)
                .background(Theme.selected, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                Text("Store pickup selected")
                    .font(.title3.weight(.black))
                    .foregroundStyle(Theme.ink)
                Text("The client can take the confirmed products from South Mumbai boutique after payment.")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.58), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Theme.line.opacity(0.45), lineWidth: 1)
        )
    }
}

private struct DeliveryAddressSection: View {
    @Binding var query: String
    @Binding var buildingDetail: String
    @Binding var shouldSaveDefaultAddress: Bool

    let suggestions: [AddressSuggestion]
    let showsSuggestions: Bool
    let defaultAddress: String?
    let onUseDefaultAddress: () -> Void
    let onSelectSuggestion: (AddressSuggestion) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Delivery Details")
                    .font(.title3.weight(.black))
                    .foregroundStyle(Theme.ink)

                Spacer()

                if let defaultAddress, !defaultAddress.isEmpty {
                    Button(action: onUseDefaultAddress) {
                        Label("Use saved address", systemImage: "location.fill")
                            .font(.caption.weight(.black))
                            .foregroundStyle(Theme.gold)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Theme.selected, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Address".uppercased())
                    .font(.caption.weight(.black))
                    .foregroundStyle(Theme.muted)

                HStack(spacing: 10) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.headline.weight(.black))
                        .foregroundStyle(Theme.gold)
                    TextField("Search delivery address", text: $query)
                        .font(.headline.weight(.bold))
                        .textInputAutocapitalization(.words)
                }
                .padding(.horizontal, 14)
                .frame(minHeight: 52)
                .background(.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                if showsSuggestions && !suggestions.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(suggestions) { suggestion in
                            Button {
                                onSelectSuggestion(suggestion)
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "location")
                                        .font(.subheadline.weight(.black))
                                        .foregroundStyle(Theme.gold)
                                        .frame(width: 34, height: 34)
                                        .background(Theme.selected, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(suggestion.title)
                                            .font(.subheadline.weight(.black))
                                            .foregroundStyle(Theme.ink)
                                            .lineLimit(1)
                                        if !suggestion.subtitle.isEmpty {
                                            Text(suggestion.subtitle)
                                                .font(.caption.weight(.semibold))
                                                .foregroundStyle(Theme.muted)
                                                .lineLimit(1)
                                        }
                                    }

                                    Spacer()
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                            }
                            .buttonStyle(.plain)

                            if suggestion.id != suggestions.last?.id {
                                Divider()
                                    .overlay(Theme.line.opacity(0.36))
                            }
                        }
                    }
                    .background(.white.opacity(0.88), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Theme.line.opacity(0.45), lineWidth: 1)
                    )
                }
            }

            ProfileTextField(
                title: "Building / Flat / Floor",
                placeholder: "optional",
                text: $buildingDetail
            )

            Button {
                shouldSaveDefaultAddress.toggle()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: shouldSaveDefaultAddress ? "checkmark.square.fill" : "square")
                        .font(.title3.weight(.black))
                        .foregroundStyle(shouldSaveDefaultAddress ? Theme.gold : Theme.muted)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Set as default delivery address")
                            .font(.headline.weight(.black))
                            .foregroundStyle(Theme.ink)
                        Text("Save this address to the client's profile for future orders.")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.muted)
                    }

                    Spacer()
                }
                .padding(14)
                .background(.white.opacity(0.58), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Theme.line.opacity(0.45), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(.white.opacity(0.48), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Theme.line.opacity(0.45), lineWidth: 1)
        )
    }
}

private struct SellingCollectionPanel: View {
    let title: String
    let subtitle: String
    let emptyTitle: String
    let emptySubtitle: String
    let products: [SalesProduct]
    let itemCount: Int
    let hasCreatedProfile: Bool
    let primaryActionTitle: String
    let primaryActionIcon: String
    let quantityForProduct: (SalesProduct) -> Int?
    let onIncrementQuantity: ((SalesProduct) -> Void)?
    let onDecrementQuantity: ((SalesProduct) -> Void)?
    let onMoveProductToCart: ((SalesProduct) -> Void)?
    let onSelectProduct: (SalesProduct) -> Void
    let onBack: () -> Void
    let onDiscardClient: () -> Void
    let onProceed: () -> Void
    let onPrimaryAction: () -> Void

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .center, spacing: 12) {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.headline.weight(.black))
                            .foregroundStyle(Theme.ink)
                            .frame(width: 44, height: 44)
                            .background(.white.opacity(0.72), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Back to products")

                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.title2.weight(.black))
                        Text(subtitle)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.muted)
                    }

                    Spacer()

                    Text("\(itemCount) item\(itemCount == 1 ? "" : "s")")
                        .font(.caption.weight(.black))
                        .foregroundStyle(Theme.gold)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 8)
                        .background(Theme.selected, in: Capsule())
                }

                if products.isEmpty {
                    EmptySellingCollection(title: emptyTitle, subtitle: emptySubtitle)
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(products) { product in
                            SellingCollectionRow(
                                product: product,
                                quantity: quantityForProduct(product),
                                onSelectProduct: {
                                    onSelectProduct(product)
                                },
                                onIncrementQuantity: onIncrementQuantity.map { action in
                                    { action(product) }
                                },
                                onDecrementQuantity: onDecrementQuantity.map { action in
                                    { action(product) }
                                },
                                onMoveToCart: onMoveProductToCart.map { action in
                                    { action(product) }
                                }
                            )
                        }
                    }
                }

                Spacer(minLength: 0)

                if hasCreatedProfile {
                    Button(action: onPrimaryAction) {
                        Label(primaryActionTitle, systemImage: primaryActionIcon)
                            .font(.headline.weight(.black))
                            .frame(maxWidth: .infinity, minHeight: 56)
                            .foregroundStyle(.white)
                            .background(Theme.goldGradient, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(products.isEmpty)
                    .opacity(products.isEmpty ? 0.55 : 1)
                } else {
                    HStack(spacing: 12) {
                        Button(action: onDiscardClient) {
                            Label("Discard Client", systemImage: "trash")
                                .font(.headline.weight(.black))
                                .frame(maxWidth: .infinity, minHeight: 56)
                                .foregroundStyle(Theme.ink)
                                .background(.white.opacity(0.70), in: Capsule())
                        }
                        .buttonStyle(.plain)

                        Button(action: onProceed) {
                            Label("Proceed", systemImage: "person.badge.plus")
                                .font(.headline.weight(.black))
                                .frame(maxWidth: .infinity, minHeight: 56)
                                .foregroundStyle(.white)
                                .background(Theme.goldGradient, in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 560, alignment: .topLeading)
        }
    }
}

private struct EmptySellingCollection: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "bag.badge.questionmark")
                .font(.system(size: 42, weight: .black))
                .foregroundStyle(Theme.gold)
                .frame(width: 78, height: 78)
                .background(Theme.selected, in: RoundedRectangle(cornerRadius: 24, style: .continuous))

            Text(title)
                .font(.title3.weight(.black))
                .foregroundStyle(Theme.ink)
            Text(subtitle)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 280)
        .background(.white.opacity(0.48), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

private struct SellingCollectionRow: View {
    let product: SalesProduct
    let quantity: Int?
    let onSelectProduct: () -> Void
    let onIncrementQuantity: (() -> Void)?
    let onDecrementQuantity: (() -> Void)?
    let onMoveToCart: (() -> Void)?

    var body: some View {
        HStack(spacing: 14) {
            Button(action: onSelectProduct) {
                HStack(spacing: 14) {
                    ProductImageView(imageName: product.imageName)
                        .frame(width: 84, height: 84)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                    VStack(alignment: .leading, spacing: 5) {
                        Text(product.name)
                            .font(.headline.weight(.black))
                            .foregroundStyle(Theme.ink)
                        Text("\(product.audience) • \(product.id)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.muted)
                    }
                }
            }
            .buttonStyle(.plain)

            Spacer()

            VStack(alignment: .trailing, spacing: 10) {
                Text(product.price)
                    .font(.headline.weight(.black))
                    .foregroundStyle(Theme.ink)

                if let quantity {
                    CartQuantityStepper(
                        quantity: quantity,
                        onDecrement: {
                            onDecrementQuantity?()
                        },
                        onIncrement: {
                            onIncrementQuantity?()
                        }
                    )
                } else if let onMoveToCart {
                    Button(action: onMoveToCart) {
                        Label("Move to Cart", systemImage: "cart.badge.plus")
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .tint(Theme.gold)
                }
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

private struct CartQuantityStepper: View {
    let quantity: Int
    let onDecrement: () -> Void
    let onIncrement: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onDecrement) {
                Image(systemName: "minus")
                    .font(.caption.weight(.black))
                    .foregroundStyle(quantity > 1 ? Theme.ink : Theme.muted.opacity(0.45))
                    .frame(width: 28, height: 28)
                    .background(.white.opacity(0.76), in: Circle())
            }
            .buttonStyle(.plain)
            .disabled(quantity <= 1)

            Text("\(quantity)")
                .font(.headline.weight(.black))
                .foregroundStyle(Theme.ink)
                .frame(minWidth: 22)

            Button(action: onIncrement) {
                Image(systemName: "plus")
                    .font(.caption.weight(.black))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 28, height: 28)
                    .background(.white.opacity(0.76), in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Theme.selected.opacity(0.88), in: Capsule())
        .overlay(Capsule().stroke(Theme.line.opacity(0.42), lineWidth: 1))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Quantity \(quantity)")
        .accessibilityHint("Use plus or minus to update cart quantity")
    }
}

private struct CreateClientProfilePanel: View {
    let guestID: String
    let onBack: () -> Void
    let onSave: (ClientProfile) -> Void

    @State private var fullName = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var birthday = ""
    @State private var preferredLanguage = "English"
    @State private var occasion = "N/A"
    @State private var preferredStyle = "N/A"
    @State private var budget = "N/A"
    @State private var size = "N/A"
    @State private var materialPreference = "N/A"
    @State private var colorPreference = "N/A"
    @State private var preferredCategory = "N/A"
    @State private var brandPreference = "N/A"
    @State private var preferredContactMethod = "Phone"
    @State private var marketingConsent = false
    @State private var notes = ""
    @State private var followUpDate = ""
    @State private var consentAccepted = false

    private let languages = ["English", "Hindi", "Marathi", "Gujarati"]
    private let occasions = ["N/A", "Wedding", "Anniversary", "Birthday", "Festive", "Corporate Gift", "Evening Event", "Travel"]
    private let styles = ["N/A", "Minimal", "Statement", "Classic", "Bridal", "Evening", "Formal", "Daily Luxury"]
    private let budgets = ["N/A", "Rs. 50K+", "Rs. 1L+", "Rs. 2L+", "Rs. 5L+", "Rs. 10L+"]
    private let sizes = ["N/A", "EU 36", "EU 38", "EU 40", "One size", "Watch 36mm", "Watch 40mm"]
    private let materials = ["N/A", "Gold", "Rose Gold", "Silver", "Diamond", "Pearl", "Leather", "Satin"]
    private let colors = ["N/A", "Champagne", "Black", "Ivory", "Gold", "Rose Gold", "Emerald", "Pearl", "Blue", "Brown"]
    private let categories = ["N/A", "Handbags", "Clutches", "Watches", "Jewellery", "Necklaces", "Footwear", "Accessories"]
    private let brands = ["N/A", "Bvlgari", "Cartier", "Dior", "Gucci", "Hermes", "Jimmy Choo", "Louis Vuitton", "Rolex", "Titan"]
    private let contactMethods = ["Phone", "WhatsApp", "Email", "SMS"]

    private var isNameValid: Bool {
        let trimmed = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return false }
        let letterAndSpaceSet = CharacterSet.letters.union(.whitespaces)
        return trimmed.unicodeScalars.allSatisfy { letterAndSpaceSet.contains($0) }
    }
    
    private var isPhoneValid: Bool {
        let trimmed = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        let digitsOnly = trimmed.filter { $0.isNumber }
        guard digitsOnly.count >= 10 else { return false }
        let allowedSet = CharacterSet(charactersIn: "+-() ").union(.decimalDigits)
        return trimmed.unicodeScalars.allSatisfy { allowedSet.contains($0) }
    }
    
    private var isEmailValid: Bool {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return true }
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPred = NSPredicate(format:"SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: trimmed)
    }
    
    private var canSave: Bool {
        isNameValid && isPhoneValid && isEmailValid
    }

    private var formColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ]
    }

    var body: some View {
        Card {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .top, spacing: 14) {
                        ClientPanelBackButton(action: onBack)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Create Client Profile")
                                .font(.title2.weight(.black))
                            Text("Convert \(guestID) into a saved client profile")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.muted)
                        }

                        Spacer()

                        Text("Required: name and phone")
                            .font(.caption.weight(.black))
                            .foregroundStyle(Theme.gold)
                            .padding(.horizontal, 13)
                            .padding(.vertical, 8)
                            .background(Theme.selected, in: Capsule())
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        ProfileFormSection(title: "Identity") {
                            LazyVGrid(columns: formColumns, spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    ProfileTextField(title: "Name *", placeholder: "Client name", text: $fullName)
                                    if !fullName.isEmpty && !isNameValid {
                                        Text("Letters and spaces only (min 2)")
                                            .font(.caption2.weight(.semibold))
                                            .foregroundStyle(.red)
                                            .padding(.horizontal, 4)
                                    }
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    ProfileTextField(title: "Phone *", placeholder: "+91 phone number", text: $phone)
                                    if !phone.isEmpty && !isPhoneValid {
                                        Text("Invalid format (min 10 digits)")
                                            .font(.caption2.weight(.semibold))
                                            .foregroundStyle(.red)
                                            .padding(.horizontal, 4)
                                    }
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    ProfileTextField(title: "Email", placeholder: "optional email", text: $email)
                                    if !email.isEmpty && !isEmailValid {
                                        Text("Invalid email format")
                                            .font(.caption2.weight(.semibold))
                                            .foregroundStyle(.red)
                                            .padding(.horizontal, 4)
                                    }
                                }
                                
                                ProfileTextField(title: "Birthday", placeholder: "DD MMM or birth date", text: $birthday)
                                ProfileDropdown(title: "Preferred Language", options: languages, selection: $preferredLanguage)
                            }
                        }

                        ProfileFormSection(title: "Membership") {
                            LazyVGrid(columns: formColumns, spacing: 12) {
                                ProfileReadOnlyRow(title: "Tier (Auto)", value: "Normal")
                                ProfileReadOnlyRow(title: "Reward Points", value: "0")
                                ProfileReadOnlyRow(title: "Lifetime Spend", value: "Rs. 0")
                            }
                        }

                        ProfileFormSection(title: "Shopping Preferences") {
                            LazyVGrid(columns: formColumns, spacing: 12) {
                                ProfileDropdown(title: "Occasion", options: occasions, selection: $occasion)
                                ProfileDropdown(title: "Budget", options: budgets, selection: $budget)
                                ProfileDropdown(title: "Style", options: styles, selection: $preferredStyle)
                                ProfileDropdown(title: "Material", options: materials, selection: $materialPreference)
                                ProfileDropdown(title: "Size", options: sizes, selection: $size)
                                ProfileDropdown(title: "Preferred Color", options: colors, selection: $colorPreference)
                                ProfileDropdown(title: "Preferred Category", options: categories, selection: $preferredCategory)
                                ProfileDropdown(title: "Brand Preference", options: brands, selection: $brandPreference)
                            }
                        }

                        ProfileFormSection(title: "Communication") {
                            LazyVGrid(columns: formColumns, spacing: 12) {
                                ProfileDropdown(title: "Preferred Contact Method", options: contactMethods, selection: $preferredContactMethod)

                                ProfileToggleRow(
                                    title: "Marketing Consent",
                                    subtitle: "Allow campaign and event communication",
                                    isOn: $marketingConsent
                                )

                                ProfileToggleRow(
                                    title: "Preference Visibility Consent",
                                    subtitle: "Show saved preferences to sales associate",
                                    isOn: $consentAccepted
                                )
                            }
                        }

                        ProfileFormSection(title: "Sales Notes") {
                            VStack(alignment: .leading, spacing: 14) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Client Notes".uppercased())
                                        .font(.caption.weight(.black))
                                        .foregroundStyle(Theme.muted)
                                    TextEditor(text: $notes)
                                        .scrollContentBackground(.hidden)
                                        .padding(10)
                                        .frame(minHeight: 118)
                                        .background(.white.opacity(0.58), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                                .stroke(Theme.line.opacity(0.45), lineWidth: 1)
                                        )
                                        .overlay(alignment: .topLeading) {
                                            if notes.isEmpty {
                                                Text("Add product interest, service note, or follow-up promise...")
                                                    .font(.subheadline.weight(.semibold))
                                                    .foregroundStyle(Theme.muted.opacity(0.66))
                                                    .padding(.horizontal, 16)
                                                    .padding(.vertical, 18)
                                            }
                                        }
                                }

                                ProfileTextField(title: "Follow-up Date", placeholder: "Tomorrow, 4 PM or date", text: $followUpDate)
                            }
                        }

                        Button {
                            onSave(makeProfile())
                        } label: {
                            Label("Save Profile", systemImage: "checkmark.seal")
                                .font(.headline.weight(.black))
                                .frame(maxWidth: .infinity, minHeight: 56)
                                .foregroundStyle(.white)
                                .background(Theme.goldGradient, in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .disabled(!canSave)
                        .opacity(canSave ? 1 : 0.55)
                    }
                    .frame(maxWidth: 820, alignment: .top)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .scrollIndicators(.hidden)
        }
    }

    private func makeProfile() -> ClientProfile {
        let name = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        let capturedPreferences = [
            occasion,
            budget,
            preferredStyle,
            materialPreference,
            size,
            colorPreference,
            preferredCategory,
            brandPreference
        ]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0 != "N/A" }
        let preferenceSummary = capturedPreferences.isEmpty ? "No preferences captured" : capturedPreferences.joined(separator: ", ")
        let resolvedNote = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let visibleAttributes = profileAttributes()

        return ClientProfile(
            id: "CL-\(Int.random(in: 2000...9999))",
            phone: phone.trimmingCharacters(in: .whitespacesAndNewlines),
            initials: initials(for: name),
            name: name,
            email: email.trimmingCharacters(in: .whitespacesAndNewlines),
            birthday: birthday.trimmingCharacters(in: .whitespacesAndNewlines),
            preferredLanguage: preferredLanguage,
            preferredContactMethod: preferredContactMethod,
            marketingConsent: marketingConsent,
            followUpDate: followUpDate.trimmingCharacters(in: .whitespacesAndNewlines),
            tier: "Normal",
            lifetimePurchaseAmount: 0,
            boutique: "Mumbai",
            status: consentAccepted ? "Preferences visible" : "Profile created - preferences hidden",
            note: resolvedNote,
            attributes: visibleAttributes,
            tasks: [
                ClientTask(
                    icon: consentAccepted ? "checkmark.shield" : "eye.slash",
                    title: consentAccepted ? "Preference consent on" : "Preference consent pending",
                    subtitle: consentAccepted ? "Preferences and history visible" : "Only identity is visible to sales associate"
                ),
                ClientTask(
                    icon: "heart",
                    title: capturedPreferences.isEmpty ? "Preferences pending" : (consentAccepted ? "Preferences saved" : "Preferences captured privately"),
                    subtitle: capturedPreferences.isEmpty ? "No optional preference data saved" : (consentAccepted ? preferenceSummary : "Other preferences require client consent")
                ),
                ClientTask(
                    icon: marketingConsent ? "megaphone.fill" : "bell.slash",
                    title: marketingConsent ? "Marketing consent on" : "Marketing consent off",
                    subtitle: marketingConsent ? "Client can receive campaigns by \(preferredContactMethod)" : "Do not send marketing campaigns"
                )
            ] + followUpTasks()
        )
    }

    private func profileAttributes() -> [ClientAttribute] {
        var attributes: [ClientAttribute] = []
        appendAttribute("Occasion", value: occasion, to: &attributes)
        appendAttribute("Budget", value: budget, to: &attributes)
        appendAttribute("Style", value: preferredStyle, to: &attributes)
        appendAttribute("Material", value: materialPreference, to: &attributes)
        appendAttribute("Size", value: size, to: &attributes)
        appendAttribute("Preferred Color", value: colorPreference, to: &attributes)
        appendAttribute("Preferred Category", value: preferredCategory, to: &attributes)
        appendAttribute("Brand Preference", value: brandPreference, to: &attributes)
        return attributes
    }

    private func followUpTasks() -> [ClientTask] {
        let followUp = followUpDate.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !followUp.isEmpty else { return [] }

        return [
            ClientTask(
                icon: "calendar.badge.clock",
                title: "Follow-up",
                subtitle: followUp
            )
        ]
    }

    private func appendAttribute(
        _ title: String,
        value: String,
        sourceValue: String? = nil,
        to attributes: inout [ClientAttribute]
    ) {
        let source = (sourceValue ?? value).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !source.isEmpty && source != "N/A" else { return }
        attributes.append(ClientAttribute(title: title, value: value))
    }

    private func initials(for name: String) -> String {
        let parts = name.split(separator: " ")
        let letters = parts.prefix(2).compactMap { $0.first }
        return letters.isEmpty ? "GC" : letters.map(String.init).joined().uppercased()
    }
}

private struct ProfileFormSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline.weight(.black))

            content
        }
        .padding(16)
        .background(.white.opacity(0.54), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Theme.line.opacity(0.45), lineWidth: 1)
        )
    }
}

private struct ProfileReadOnlyRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title.uppercased())
                .font(.caption.weight(.black))
                .foregroundStyle(Theme.muted)

            Spacer()

            Text(value)
                .font(.headline.weight(.black))
                .foregroundStyle(Theme.ink)
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 50)
        .background(Theme.selected.opacity(0.66), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct ProfileToggleRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline.weight(.black))
                    .foregroundStyle(Theme.ink)

                Text(subtitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.muted)
            }
        }
        .tint(Theme.gold)
        .padding(.horizontal, 14)
        .frame(minHeight: 58)
        .background(.white.opacity(0.66), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct ProfileTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.caption.weight(.black))
                .foregroundStyle(Theme.muted)

            TextField(placeholder, text: $text)
                .font(.headline.weight(.bold))
                .textInputAutocapitalization(.words)
                .padding(.horizontal, 14)
                .frame(minHeight: 50)
                .background(.white.opacity(0.66), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
}

struct ProfileDropdown: View {
    let title: String
    let options: [String]
    @Binding var selection: String

    var body: some View {
        Menu {
            ForEach(options, id: \.self) { option in
                Button(option) {
                    selection = option
                }
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text(title.uppercased())
                        .font(.caption.weight(.black))
                        .foregroundStyle(Theme.muted)
                    Text(selection)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(Theme.ink)
                }

                Spacer()

                Image(systemName: "chevron.down")
                    .font(.subheadline.weight(.black))
                    .foregroundStyle(Theme.gold)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 58)
            .background(.white.opacity(0.66), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct ProductOptionSection: View {
    let title: String
    let options: [String]
    @Binding var selectedValue: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.caption.weight(.black))
                .tracking(1)
                .foregroundStyle(Theme.muted)

            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(options, id: \.self) { option in
                        Button {
                            selectedValue = option
                        } label: {
                            Text(option)
                                .font(.caption.weight(.black))
                                .padding(.horizontal, 12)
                                .frame(height: 34)
                                .foregroundStyle(selectedValue == option ? .white : Theme.ink)
                                .background(
                                    selectedValue == option ? AnyShapeStyle(Theme.goldGradient) : AnyShapeStyle(.white.opacity(0.66)),
                                    in: Capsule()
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
    }
}

private struct QuantityButton: View {
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.headline.weight(.black))
                .frame(width: 38, height: 38)
                .foregroundStyle(Theme.ink)
                .background(Theme.selected, in: Circle())
        }
        .buttonStyle(.plain)
    }
}
