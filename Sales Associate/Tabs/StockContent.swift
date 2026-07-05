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
    let associateID: String
    let storeID: String

    @State private var selectedMode: StockWorkspaceMode = .stock
    @State private var stockQuery = ""

    init(dashboard: StockDashboard, products: [SalesProduct], associateID: String, storeID: String) {
        self.dashboard = dashboard
        self.products = products
        self.associateID = associateID
        self.storeID = storeID
    }

    private var filteredProducts: [SalesProduct] {
        let searchTerm = stockQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !searchTerm.isEmpty else { return products }
        return products.filter { $0.matches(searchTerm) }
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
                                products: products,
                                associateID: associateID,
                                storeID: storeID
                            )
                        case .scanStock:
                            StockScanPane(
                                product: products.first,
                                checks: dashboard.scanChecks
                            )
                        case .smReview:
                            StoreManagerReviewPane(
                                associateID: associateID,
                                products: products
                            )
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
    let products: [SalesProduct]
    let associateID: String
    let storeID: String

    // Available tabs matching user requirements
    @State private var selectedTab: String = "missing" // missing, damaged, customer_request
    
    // Product selection state
    @State private var selectedProductID: String = ""
    @State private var productQuery: String = ""
    
    // Form fields
    @State private var expectedQuantityText: String = ""
    @State private var receivedQuantityText: String = ""
    
    // Variant
    @State private var variantText: String = ""
    @State private var selectedVariantOption: String = "Normal" // For customer request tab (Normal vs Emergency)
    
    // Photo selection state
    @State private var selectedPhoto: UIImage? = nil
    @State private var photoFileName: String? = nil
    @State private var showingPhotoSource = false
    @State private var showingPhotoCamera = false
    @State private var showingPhotoLibrary = false
    
    // Notes
    @State private var notes: String = ""
    
    // Status / Feedback
    @State private var isSubmitting: Bool = false
    @State private var alertTitle: String = ""
    @State private var alertMessage: String = ""
    @State private var showingAlert: Bool = false

    private let tabs = [
        ("missing", "Missing", "Report missing items", "exclamationmark.triangle"),
        ("damaged", "Damaged", "Report damaged items", "wineglass"),
        ("customer_request", "Customer Request", "Request unavailable product", "person")
    ]

    private var headerTitle: String {
        switch selectedTab {
        case "missing": return "Missing Item Details"
        case "damaged": return "Damaged Item Details"
        case "customer_request": return "Customer Request Details"
        default: return "Issue Details"
        }
    }
    
    private var headerDescription: String {
        switch selectedTab {
        case "missing": return "Received quantity is lower than the inventory handoff count."
        case "damaged": return "Report damaged items received during handoff."
        case "customer_request": return "Request unavailable product."
        default: return "Provide details about the issue."
        }
    }

    private func submitRequest() {
        guard !selectedProductID.isEmpty else {
            alertTitle = "Product Required"
            alertMessage = "Please select a product first."
            showingAlert = true
            return
        }
        
        let prod = products.first(where: { $0.id == selectedProductID })
        let dbProductID = (prod?.dbID.isEmpty == false) ? prod!.dbID : selectedProductID
        
        let expectedQty = Int(expectedQuantityText)
        if expectedQty == nil {
            alertTitle = "Invalid Expected Quantity"
            alertMessage = "Please enter a valid quantity."
            showingAlert = true
            return
        }
        
        var receivedQty: Int? = nil
        var varianceInQty: Int? = nil
        
        if selectedTab == "missing" {
            guard let rQty = Int(receivedQuantityText) else {
                alertTitle = "Invalid Received Quantity"
                alertMessage = "Received quantity is required and must be a valid number for missing items."
                showingAlert = true
                return
            }
            receivedQty = rQty
            varianceInQty = expectedQty! - rQty
        } else if selectedTab == "damaged" {
            varianceInQty = expectedQty!
        }
        
        if selectedTab == "damaged" && selectedPhoto == nil {
            alertTitle = "Photo Required"
            alertMessage = "Please upload at least one photo of the damaged product."
            showingAlert = true
            return
        }
        
        isSubmitting = true
        
        Task {
            do {
                if selectedTab == "customer_request" {
                    // Submit to SalesAssociateStockRequest table
                    try await SupabaseDBService.shared.submitStockRequest(
                        productID: dbProductID,
                        storeID: storeID,
                        reportedBy: associateID,
                        quantity: expectedQty!,
                        urgency: selectedVariantOption == "Emergency" ? "urgent" : "normal"
                    )
                } else {
                    // Submit to ExceptionRecord table
                    var imageUrl = ""
                    
                    if selectedTab == "damaged", let photo = selectedPhoto {
                        let uniqueName = "img_\(Int(Date().timeIntervalSince1970))_\(UUID().uuidString.prefix(6)).jpg"
                        let photoPath = try await SupabaseDBService.shared.uploadImage(
                            photo,
                            toBucket: "Damaged Product",
                            fileName: uniqueName
                        )
                        imageUrl = photoPath
                    }
                    
                    try await SupabaseDBService.shared.submitExceptionRecord(
                        productID: dbProductID,
                        storeID: storeID,
                        exceptionType: selectedTab,
                        reportedBy: associateID,
                        description: nil,
                        varianceInQuantity: varianceInQty,
                        damagedImageURL: imageUrl
                    )
                }
                
                await MainActor.run {
                    isSubmitting = false
                    alertTitle = "Success"
                    alertMessage = "Your request has been submitted to the Store Manager."
                    showingAlert = true
                    
                    // Reset fields
                    selectedProductID = ""
                    productQuery = ""
                    expectedQuantityText = ""
                    receivedQuantityText = ""
                    variantText = ""
                    selectedVariantOption = "Normal"
                    selectedPhoto = nil
                    photoFileName = nil
                    notes = ""
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    alertTitle = "Submission Failed"
                    alertMessage = error.localizedDescription
                    showingAlert = true
                }
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Horizontal tabs spreading across full width
            HStack(spacing: 8) {
                ForEach(tabs, id: \.0) { tabId, tabTitle, tabSub, tabIcon in
                    Button {
                        selectedTab = tabId
                        // Clean up ALL selections when switching tabs
                        selectedProductID = ""
                        productQuery = ""
                        expectedQuantityText = ""
                        receivedQuantityText = ""
                        variantText = ""
                        selectedVariantOption = "Normal"
                        selectedPhoto = nil
                        photoFileName = nil
                        notes = ""
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: tabIcon)
                                .font(.system(size: 14, weight: .black))
                                .foregroundStyle(selectedTab == tabId ? Theme.gold : Theme.muted)
                                .frame(width: 32, height: 32)
                                .background(
                                    selectedTab == tabId ? Theme.selected : Color.white.opacity(0.6),
                                    in: Circle()
                                )
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(tabTitle)
                                    .font(.system(size: 12, weight: .black))
                                    .foregroundStyle(selectedTab == tabId ? Theme.ink : Theme.muted)
                                Text(tabSub)
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(Theme.muted)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            selectedTab == tabId ? Theme.selected.opacity(0.7) : Color.white.opacity(0.5),
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(selectedTab == tabId ? Theme.gold.opacity(0.8) : Theme.line.opacity(0.4), lineWidth: 1.5)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // Header Info
            VStack(alignment: .leading, spacing: 4) {
                Text(headerTitle)
                    .font(.title2.weight(.black))
                    .foregroundStyle(Theme.ink)
                Text(headerDescription)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.muted)
            }
            .padding(.top, 4)
            
            Divider()
                .foregroundStyle(Theme.line)
            
            // Product Selection Form Field
            VStack(alignment: .leading, spacing: 6) {
                Text("Item / Product*")
                    .font(.headline.weight(.black))
                    .foregroundStyle(Theme.ink)
                
                if let selectedProduct = products.first(where: { $0.id == selectedProductID }) {
                    // Selected product display card
                    HStack(spacing: 12) {
                        ProductImageView(imageName: selectedProduct.imageName)
                            .frame(width: 50, height: 50)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        
                        VStack(alignment: .leading, spacing: 3) {
                            Text(selectedProduct.name)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(Theme.ink)
                            Text("\(selectedProduct.brand) • \(selectedProduct.id)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Theme.muted)
                        }
                        
                        Spacer()
                        
                        Button {
                            selectedProductID = ""
                            productQuery = ""
                        } label: {
                            Text("Change")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Theme.gold)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Theme.selected, in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(10)
                    .background(Color.white.opacity(0.6), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Theme.line.opacity(0.5), lineWidth: 1)
                    )
                } else {
                    // Autocomplete search field
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(Theme.muted)
                        
                        TextField("Search or scan item", text: $productQuery)
                            .font(.subheadline.weight(.semibold))
                            .textInputAutocapitalization(.never)
                        
                        Image(systemName: "barcode.viewfinder")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(Theme.gold)
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 52)
                    .background(Color.white.opacity(0.6), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Theme.line.opacity(0.5), lineWidth: 1)
                    )
                    
                    // Search query results dropdown overlay
                    if !productQuery.isEmpty {
                        let filtered = products.filter {
                            ($0.name.localizedCaseInsensitiveContains(productQuery) ||
                             $0.brand.localizedCaseInsensitiveContains(productQuery) ||
                             $0.id.localizedCaseInsensitiveContains(productQuery)) &&
                            !$0.isInStock
                        }
                        
                        if !filtered.isEmpty {
                            VStack(alignment: .leading, spacing: 0) {
                                ForEach(filtered.prefix(5)) { prod in
                                    Button {
                                        selectedProductID = prod.id
                                        productQuery = ""
                                    } label: {
                                        HStack(spacing: 10) {
                                            ProductImageView(imageName: prod.imageName)
                                                .frame(width: 36, height: 36)
                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(prod.name)
                                                    .font(.system(size: 13, weight: .bold))
                                                    .foregroundStyle(Theme.ink)
                                                Text("\(prod.brand) • \(prod.id)")
                                                    .font(.system(size: 11, weight: .semibold))
                                                    .foregroundStyle(Theme.muted)
                                            }
                                            Spacer()
                                        }
                                        .padding(.vertical, 8)
                                        .padding(.horizontal, 12)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Color.white.opacity(0.9))
                                    }
                                    .buttonStyle(.plain)
                                    Divider()
                                }
                            }
                            .background(Color.white, in: RoundedRectangle(cornerRadius: 14))
                            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 3)
                            .padding(.top, 4)
                        }
                    }
                }
            }
            
            // Form Fields based on tab
            tabSpecificFormFields
            
            // Photos (hidden on missing and customer_request; required on damaged)
            if selectedTab != "missing" && selectedTab != "customer_request" {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Photos" + (selectedTab == "damaged" ? " (Add at least one)*" : " (Optional)"))
                        .font(.headline.weight(.black))
                        .foregroundStyle(Theme.ink)
                    
                    Text("Add photos of the issue for better clarity")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.muted)
                    
                    HStack(spacing: 12) {
                        Button {
                            showingPhotoSource = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "camera")
                                    .font(.headline.weight(.black))
                                    .foregroundStyle(Theme.gold)
                                Text("Take Photo")
                                    .font(.subheadline.weight(.black))
                                    .foregroundStyle(Theme.ink)
                            }
                            .frame(maxWidth: .infinity, minHeight: 64)
                            .background(Color.white.opacity(0.6), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(Theme.line.opacity(0.5), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        
                        Button {
                            showingPhotoLibrary = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "photo.on.rectangle")
                                    .font(.headline.weight(.black))
                                    .foregroundStyle(Theme.gold)
                                Text("Choose from Gallery")
                                    .font(.subheadline.weight(.black))
                                    .foregroundStyle(Theme.ink)
                            }
                            .frame(maxWidth: .infinity, minHeight: 64)
                            .background(Color.white.opacity(0.6), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(Theme.line.opacity(0.5), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    
                    if let photo = selectedPhoto {
                        HStack {
                            Image(uiImage: photo)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 120)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            
                            Spacer()
                            
                            Button {
                                selectedPhoto = nil
                                photoFileName = nil
                            } label: {
                                Image(systemName: "trash.circle.fill")
                                    .font(.title)
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(10)
                        .background(Color.white.opacity(0.5), in: RoundedRectangle(cornerRadius: 16))
                    }
                }
            }
            
            // Submission button / loading indicator
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    Image(systemName: "info.circle")
                        .font(.title3.weight(.black))
                        .foregroundStyle(Theme.gold)
                        .frame(width: 44, height: 44)
                        .background(Theme.selected, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("This request will be sent to the Store Manager for review.")
                            .font(.subheadline.weight(.bold))
                        Text("You will be notified once the request is reviewed.")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.muted)
                    }
                }
                .padding(12)
                .background(Theme.selected.opacity(0.5), in: RoundedRectangle(cornerRadius: 16))
                
                if isSubmitting {
                    HStack {
                        Spacer()
                        ProgressView()
                            .tint(Theme.gold)
                        Spacer()
                    }
                    .frame(height: 56)
                } else {
                    Button(action: submitRequest) {
                        Label("Submit Request to Store Manager", systemImage: "paperplane")
                            .font(.headline.weight(.black))
                            .frame(maxWidth: .infinity, minHeight: 56)
                            .foregroundStyle(.white)
                            .background(Theme.goldGradient, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .confirmationDialog("Choose Photo Source", isPresented: $showingPhotoSource, titleVisibility: .visible) {
            Button("Take Photo") {
                showingPhotoCamera = true
            }
            Button("Choose from Library") {
                showingPhotoLibrary = true
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showingPhotoCamera) {
            CameraPicker(selectedImage: $selectedPhoto, fileName: $photoFileName)
        }
        .sheet(isPresented: $showingPhotoLibrary) {
            PhotoPicker(selectedImage: $selectedPhoto, fileName: $photoFileName)
        }
        .alert(alertTitle, isPresented: $showingAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }
    
    @ViewBuilder
    private var tabSpecificFormFields: some View {
        if selectedTab == "customer_request" {
            customerRequestFields
        } else if selectedTab == "missing" {
            missingFields
        } else if selectedTab == "damaged" {
            damagedFields
        }
    }
    
    @ViewBuilder
    private var customerRequestFields: some View {
        HStack(spacing: 16) {
            // Urgency
            VStack(alignment: .leading, spacing: 6) {
                Text("Urgency*")
                    .font(.headline.weight(.black))
                    .foregroundStyle(Theme.ink)
                
                Menu {
                    Button("Normal") { selectedVariantOption = "Normal" }
                    Button("Emergency") { selectedVariantOption = "Emergency" }
                } label: {
                    HStack {
                        Text(selectedVariantOption)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.ink)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Theme.gold)
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 52)
                    .background(Color.white.opacity(0.6), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Theme.line.opacity(0.5), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity)
            
            // Quantity
            VStack(alignment: .leading, spacing: 6) {
                Text("Quantity*")
                    .font(.headline.weight(.black))
                    .foregroundStyle(Theme.ink)
                
                TextField("Enter quantity", text: $expectedQuantityText)
                    .font(.subheadline.weight(.semibold))
                    .keyboardType(.numberPad)
                    .padding(.horizontal, 14)
                    .frame(height: 52)
                    .background(Color.white.opacity(0.6), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Theme.line.opacity(0.5), lineWidth: 1)
                    )
            }
            .frame(maxWidth: .infinity)
        }
    }
    
    @ViewBuilder
    private var missingFields: some View {
        HStack(spacing: 16) {
            // Expected Quantity
            VStack(alignment: .leading, spacing: 6) {
                Text("Expected Quantity*")
                    .font(.headline.weight(.black))
                    .foregroundStyle(Theme.ink)
                
                TextField("Enter expected quantity", text: $expectedQuantityText)
                    .font(.subheadline.weight(.semibold))
                    .keyboardType(.numberPad)
                    .padding(.horizontal, 14)
                    .frame(height: 52)
                    .background(Color.white.opacity(0.6), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Theme.line.opacity(0.5), lineWidth: 1)
                    )
            }
            .frame(maxWidth: .infinity)
            
            // Received Quantity (Required)
            VStack(alignment: .leading, spacing: 6) {
                Text("Received Quantity*")
                    .font(.headline.weight(.black))
                    .foregroundStyle(Theme.ink)
                
                TextField("Enter received quantity", text: $receivedQuantityText)
                    .font(.subheadline.weight(.semibold))
                    .keyboardType(.numberPad)
                    .padding(.horizontal, 14)
                    .frame(height: 52)
                    .background(Color.white.opacity(0.6), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Theme.line.opacity(0.5), lineWidth: 1)
                    )
            }
            .frame(maxWidth: .infinity)
        }
    }
    
    @ViewBuilder
    private var damagedFields: some View {
        // Damaged count (Received Quantity and Variant are hidden)
        VStack(alignment: .leading, spacing: 6) {
            Text("Damaged Products*")
                .font(.headline.weight(.black))
                .foregroundStyle(Theme.ink)
            
            TextField("Enter quantity", text: $expectedQuantityText)
                .font(.subheadline.weight(.semibold))
                .keyboardType(.numberPad)
                .padding(.horizontal, 14)
                .frame(height: 52)
                .background(Color.white.opacity(0.6), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Theme.line.opacity(0.5), lineWidth: 1)
                )
        }
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
    let associateID: String
    let products: [SalesProduct]
    
    @State private var reviews: [StoreManagerReview] = []
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil
    
    func formatSupabaseDate(_ dateStr: String) -> String {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        var date = isoFormatter.date(from: dateStr)
        if date == nil {
            let altFormatter = ISO8601DateFormatter()
            altFormatter.formatOptions = [.withInternetDateTime]
            date = altFormatter.date(from: dateStr)
        }
        
        guard let date = date else { return dateStr }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    func loadReviews() async {
        isLoading = true
        errorMessage = nil
        do {
            // Fetch exceptions
            let exceptions = try await SupabaseDBService.shared.fetchExceptionRecords(for: associateID)
            // Fetch stock requests
            let stockRequests = try await SupabaseDBService.shared.fetchStockRequests(for: associateID)
            
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            
            struct RawReview {
                let title: String
                let status: String
                let note: String
                let date: Date
                let icon: String
            }
            
            var rawReviews: [RawReview] = []
            
            for exc in exceptions {
                let prodName = products.first(where: { $0.id == exc.productID })?.name ?? exc.productID
                let title = "\(exc.exceptionType.capitalized): \(prodName)"
                let statusStr = exc.status.capitalized
                let qtyText = exc.varianceInQuantity != nil ? "Quantity: \(exc.varianceInQuantity!)" : ""
                let note = qtyText.isEmpty ? (exc.description ?? "No details provided.") : qtyText
                
                var date = formatter.date(from: exc.createdAt)
                if date == nil {
                    let alt = ISO8601DateFormatter()
                    alt.formatOptions = [.withInternetDateTime]
                    date = alt.date(from: exc.createdAt)
                }
                let finalDate = date ?? Date.distantPast
                
                let iconStr: String
                switch exc.exceptionType {
                case "missing": iconStr = "exclamationmark.triangle"
                case "damaged": iconStr = "wineglass"
                default: iconStr = "exclamationmark.circle"
                }
                
                rawReviews.append(RawReview(
                    title: title,
                    status: statusStr,
                    note: note,
                    date: finalDate,
                    icon: iconStr
                ))
            }
            
            for req in stockRequests {
                let prodName = products.first(where: { $0.id == req.productID })?.name ?? req.productID
                let title = "Customer Request: \(prodName)"
                let statusStr = req.status.capitalized
                let displayUrgency = req.urgency == "urgent" ? "Emergency" : req.urgency.capitalized
                let note = "Quantity: \(req.quantityRequested) | Urgency: \(displayUrgency)"
                
                var date = formatter.date(from: req.createdAt)
                if date == nil {
                    let alt = ISO8601DateFormatter()
                    alt.formatOptions = [.withInternetDateTime]
                    date = alt.date(from: req.createdAt)
                }
                let finalDate = date ?? Date.distantPast
                
                rawReviews.append(RawReview(
                    title: title,
                    status: statusStr,
                    note: note,
                    date: finalDate,
                    icon: "person"
                ))
            }
            
            // Sort by date descending (newest first)
            rawReviews.sort { $0.date > $1.date }
            
            await MainActor.run {
                let displayFormatter = DateFormatter()
                displayFormatter.dateStyle = .medium
                displayFormatter.timeStyle = .short
                
                self.reviews = rawReviews.map { raw in
                    StoreManagerReview(
                        title: raw.title,
                        status: raw.status,
                        note: raw.note,
                        time: displayFormatter.string(from: raw.date),
                        icon: raw.icon
                    )
                }
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }

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

                if isLoading {
                    ProgressView()
                        .tint(Theme.gold)
                } else {
                    Text("\(reviews.count) updates")
                        .font(.caption.weight(.black))
                        .foregroundStyle(Theme.gold)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 8)
                        .background(Theme.selected, in: Capsule())
                }
            }
            
            if let error = errorMessage {
                Text("Error: \(error)")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.red)
                    .padding()
            } else if reviews.isEmpty && !isLoading {
                VStack(spacing: 10) {
                    Image(systemName: "checklist")
                        .font(.title.weight(.bold))
                        .foregroundStyle(Theme.gold)
                    Text("No review records found")
                        .font(.headline.weight(.bold))
                    Text("Your submitted exception reports will show up here.")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.muted)
                }
                .frame(maxWidth: .infinity, minHeight: 180)
            } else {
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
                            
                            HStack(spacing: 8) {
                                Text(review.status)
                                    .font(.system(size: 11, weight: .black))
                                    .foregroundStyle(statusColor(for: review.status))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(statusBgColor(for: review.status), in: Capsule())
                            }
                            
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
        .task {
            await loadReviews()
        }
    }
    
    private func statusColor(for status: String) -> Color {
        let lower = status.lowercased()
        if lower.contains("approved") {
            return Theme.gold
        } else if lower.contains("reject") {
            return Color(red: 0.68, green: 0.28, blue: 0.24)
        } else {
            return Theme.muted
        }
    }
    
    private func statusBgColor(for status: String) -> Color {
        let lower = status.lowercased()
        if lower.contains("approved") {
            return Theme.selected
        } else if lower.contains("reject") {
            return Color(red: 0.98, green: 0.88, blue: 0.84)
        } else {
            return .white.opacity(0.66)
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
