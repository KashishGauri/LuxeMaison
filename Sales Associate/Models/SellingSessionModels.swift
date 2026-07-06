import Foundation

enum SellingSessionPanel: Equatable {
    case wishlist
    case cart
    case createProfile
    case fulfillment
    case payment
}

struct SellingSessionState: Equatable {
    var guestID: String?
    var wishlistProductIDs: [String] = []
    var cartProductIDs: [String] = []
    var cartQuantitiesByProductID: [String: Int] = [:]
    var createdClient: ClientProfile?
    var activePanel: SellingSessionPanel?

    var hasActiveClient: Bool {
        guestID != nil || createdClient != nil
    }

    var displayName: String {
        createdClient?.name ?? guestID ?? "Guest client"
    }

    var hasCreatedProfile: Bool {
        createdClient != nil
    }

    var wishlistItemCount: Int {
        wishlistProductIDs.count
    }

    var cartItemCount: Int {
        cartQuantitiesByProductID.values.reduce(0, +)
    }

    /// Wishlist product IDs merged with cart product IDs, de-duplicated.
    /// Order is preserved: existing wishlist first, then any cart-only items.
    var combinedWishlistProductIDs: [String] {
        var seen = Set<String>()
        var combined: [String] = []
        for productID in wishlistProductIDs + cartProductIDs where seen.insert(productID).inserted {
            combined.append(productID)
        }
        return combined
    }

    mutating func startNewGuest() {
        guestID = "GUEST-\(Int.random(in: 1000...9999))"
        wishlistProductIDs = []
        cartProductIDs = []
        cartQuantitiesByProductID = [:]
        createdClient = nil
        activePanel = nil
    }

    mutating func startForClient(_ client: ClientProfile) {
        guestID = nil
        wishlistProductIDs = client.wishlistProductIDs
        cartProductIDs = []
        cartQuantitiesByProductID = [:]
        createdClient = client
        activePanel = nil
    }

    mutating func discard() {
        guestID = nil
        wishlistProductIDs = []
        cartProductIDs = []
        cartQuantitiesByProductID = [:]
        createdClient = nil
        activePanel = nil
    }

    mutating func toggleWishlist(_ product: SalesProduct) {
        if wishlistProductIDs.contains(product.id) {
            wishlistProductIDs.removeAll { $0 == product.id }
        } else {
            wishlistProductIDs.append(product.id)
        }
    }

    mutating func addToCart(_ product: SalesProduct, quantity: Int = 1) {
        let maxAvailable = product.stockQuantity
        let currentInCart = cartQuantitiesByProductID[product.id] ?? 0
        let allowedToAdd = min(quantity, maxAvailable - currentInCart)
        guard allowedToAdd > 0 else { return }
        
        if !cartProductIDs.contains(product.id) {
            cartProductIDs.append(product.id)
        }
        cartQuantitiesByProductID[product.id, default: 0] += allowedToAdd
    }

    mutating func setCartQuantity(_ quantity: Int, for product: SalesProduct) {
        let resolvedQuantity = min(max(1, quantity), product.stockQuantity)
        if !cartProductIDs.contains(product.id) {
            cartProductIDs.append(product.id)
        }
        cartQuantitiesByProductID[product.id] = resolvedQuantity
    }

    mutating func incrementCartQuantity(for product: SalesProduct) {
        setCartQuantity(quantity(for: product) + 1, for: product)
    }

    mutating func decrementCartQuantity(for product: SalesProduct) {
        setCartQuantity(max(1, quantity(for: product) - 1), for: product)
    }

    mutating func moveWishlistToCart() {
        for productID in wishlistProductIDs {
            if !cartProductIDs.contains(productID) {
                cartProductIDs.append(productID)
            }
            cartQuantitiesByProductID[productID, default: 0] += 1
        }
        wishlistProductIDs = []
        activePanel = .cart
    }

    /// Transfers a single wishlist item into the cart, removing it from the wishlist.
    mutating func moveToCart(_ product: SalesProduct) {
        addToCart(product, quantity: 1)
        wishlistProductIDs.removeAll { $0 == product.id }
    }

    /// Removes a product from the cart entirely (local only — the cart is not
    /// persisted to Supabase; only the wishlist is).
    mutating func removeFromCart(_ product: SalesProduct) {
        cartProductIDs.removeAll { $0 == product.id }
        cartQuantitiesByProductID[product.id] = nil
    }

    /// Removes a product from the wishlist (used by the wishlist item's remove button).
    mutating func removeFromWishlist(_ product: SalesProduct) {
        wishlistProductIDs.removeAll { $0 == product.id }
    }

    func isWishlisted(_ product: SalesProduct) -> Bool {
        wishlistProductIDs.contains(product.id)
    }

    func isInCart(_ product: SalesProduct) -> Bool {
        cartProductIDs.contains(product.id)
    }

    func quantity(for product: SalesProduct) -> Int {
        cartQuantitiesByProductID[product.id] ?? 0
    }
}
