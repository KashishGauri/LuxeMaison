import SwiftUI
import PhotosUI

enum AfterSaleWorkspaceMode: String, CaseIterable, Identifiable, Equatable {
    case request = "Request Support"
    case pastRequests = "Past Requests"

    var id: String { rawValue }
}

struct IssueContent: View {
    let dashboard: IssueDashboard
    let products: [SalesProduct]
    let clientProfiles: [ClientProfile]
    let associateID: String
    let storeID: String

    @State private var selectedMode: AfterSaleWorkspaceMode = .request
    @State private var searchText = ""
    @State private var searchSubmitted = false
    @State private var isSearching = false
    
    // Search Results
    @State private var searchResultsClients: [ClientProfile] = []
    @State private var searchedReceipt: DBReceipt? = nil
    @State private var receiptItems: [DBSalesItem] = []
    @State private var receiptProducts: [SalesProduct] = []
    
    // Selected Targets for Request
    @State private var selectedClient: ClientProfile? = nil
    @State private var selectedReceipt: DBReceipt? = nil
    @State private var selectedProductID: String = ""
    @State private var selectedRequestType = "repair" // 'repair', 'service', 'exchange'
    
    // Request Inputs
    @State private var notes = ""
    @State private var selectedPhoto: UIImage? = nil
    @State private var photoFileName: String? = nil
    @State private var isSubmitting = false
    
    // Sheet toggles
    @State private var showingPhotoSource = false
    @State private var showingPhotoCamera = false
    @State private var showingPhotoLibrary = false
    
    // Past Requests
    @State private var pastRequests: [DBAfterSaleRequest] = []
    @State private var isLoadingPastRequests = false
    
    // Alerts
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var showingAlert = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                // Header Title
                VStack(alignment: .leading, spacing: 6) {
                    Text("After-Sale Support")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.ink)
                    Text("Register repairs, maintenance services, or product exchanges against purchase receipts.")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.muted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Workspace Segmented Control
                SegmentedPicker(selected: $selectedMode)
                    .onChange(of: selectedMode) { mode in
                        if mode == .pastRequests {
                            loadPastRequests()
                        }
                    }
                
                if selectedMode == .request {
                    requestPane
                } else {
                    pastRequestsPane
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 22)
        }
        .scrollIndicators(.hidden)
        .alert(alertTitle, isPresented: $showingAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
        .sheet(isPresented: $showingPhotoCamera) {
            CameraPicker(selectedImage: $selectedPhoto, fileName: $photoFileName)
        }
        .sheet(isPresented: $showingPhotoLibrary) {
            PhotoPicker(selectedImage: $selectedPhoto, fileName: $photoFileName)
        }
        .confirmationDialog("Add Photo", isPresented: $showingPhotoSource, titleVisibility: .visible) {
            Button("Take Photo") { showingPhotoCamera = true }
            Button("Choose from Gallery") { showingPhotoLibrary = true }
            Button("Cancel", role: .cancel) {}
        }
    }
    
    private var requestPane: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Search Box Card
            CardView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Search Client or Receipt")
                        .font(.headline.weight(.black))
                        .foregroundStyle(Theme.ink)
                    
                    HStack(spacing: 12) {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(Theme.gold)
                            
                            TextField("Enter Client ID, phone, or Receipt Invoice #", text: $searchText, onCommit: executeSearch)
                                .font(.subheadline.weight(.semibold))
                                .keyboardType(.default)
                        }
                        .padding(.horizontal, 14)
                        .frame(height: 52)
                        .background(Color.white.opacity(0.6), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Theme.line.opacity(0.5), lineWidth: 1)
                        )
                        
                        Button(action: executeSearch) {
                            Text("Search")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 20)
                                .frame(height: 52)
                                .background(Theme.gold, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            if isSearching {
                HStack {
                    Spacer()
                    ProgressView()
                        .tint(Theme.gold)
                    Spacer()
                }
                .padding(.vertical, 20)
            } else if searchSubmitted {
                if searchResultsClients.isEmpty && searchedReceipt == nil {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "questionmark.folder")
                                .font(.largeTitle)
                                .foregroundStyle(Theme.gold)
                            Text("No matching profiles or receipts found.")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(Theme.muted)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 30)
                    .background(Color.white.opacity(0.4), in: RoundedRectangle(cornerRadius: 16))
                } else {
                    // Client Search Results
                    if !searchResultsClients.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Matching Clients")
                                .font(.headline.weight(.black))
                                .foregroundStyle(Theme.ink)
                            
                            ForEach(searchResultsClients) { client in
                                Button {
                                    selectedClient = client
                                    selectedReceipt = nil
                                    receiptItems = []
                                    receiptProducts = []
                                    selectedProductID = ""
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(client.name)
                                                .font(.subheadline.weight(.bold))
                                                .foregroundStyle(Theme.ink)
                                            Text("ID: \(client.id) | Phone: \(client.phone)")
                                                .font(.caption.weight(.semibold))
                                                .foregroundStyle(Theme.muted)
                                        }
                                        Spacer()
                                        
                                        // Tier Badge
                                        Text(client.tier)
                                            .font(.caption2.weight(.black))
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Theme.selected, in: RoundedRectangle(cornerRadius: 8))
                                            .foregroundStyle(Theme.gold)
                                    }
                                    .padding()
                                    .background(selectedClient?.id == client.id ? Theme.selected.opacity(0.7) : Color.white.opacity(0.6))
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(selectedClient?.id == client.id ? Theme.gold : Theme.line.opacity(0.4), lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            
            // Client Details & Purchase History Panel
            if let client = selectedClient {
                CardView {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(client.name)
                                    .font(.title3.weight(.bold))
                                    .foregroundStyle(Theme.ink)
                                Text("Client Tier: \(client.tier) | Spend: Rs. \(client.lifetimePurchaseAmount)")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Theme.muted)
                            }
                            Spacer()
                        }
                        
                        Divider()
                            .background(Theme.line.opacity(0.5))
                        
                        Text("Purchase History")
                            .font(.headline.weight(.black))
                            .foregroundStyle(Theme.ink)
                        
                        if client.purchaseHistory.isEmpty {
                            Text("No past purchases recorded for this client.")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Theme.muted)
                                .padding(.vertical, 10)
                        } else {
                            VStack(spacing: 10) {
                                ForEach(client.purchaseHistory) { purchase in
                                    Button {
                                        if let invNum = purchase.invoiceNumber {
                                            searchText = invNum
                                            executeSearch()
                                        } else {
                                            alertTitle = "No Invoice Linked"
                                            alertMessage = "This purchase does not have a registered invoice number."
                                            showingAlert = true
                                        }
                                    } label: {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(purchase.productName)
                                                    .font(.subheadline.weight(.bold))
                                                    .foregroundStyle(Theme.ink)
                                                Text("Purchased: \(purchase.purchasedOn) | Invoice: \(purchase.invoiceNumber ?? "N/A")")
                                                    .font(.caption.weight(.semibold))
                                                    .foregroundStyle(Theme.muted)
                                            }
                                            Spacer()
                                            
                                            Text(purchase.price)
                                                .font(.subheadline.weight(.bold))
                                                .foregroundStyle(Theme.gold)
                                        }
                                        .padding(12)
                                        .background(Color.white.opacity(0.5))
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(Theme.line.opacity(0.3), lineWidth: 1)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
            }
            
            // Receipt Details Card
            if let receipt = selectedReceipt {
                CardView {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Receipt Invoice Details")
                                    .font(.headline.weight(.black))
                                    .foregroundStyle(Theme.ink)
                                Text("Invoice #: \(receipt.invoiceNumber ?? "N/A") | Date: \(receipt.receiptDate ?? "N/A")")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Theme.muted)
                            }
                            Spacer()
                            Text("Rs. \(Int(receipt.totalAmount ?? 0))")
                                .font(.title3.weight(.black))
                                .foregroundStyle(Theme.gold)
                        }
                        
                        Divider()
                            .background(Theme.line.opacity(0.5))
                        
                        Text("Select Product with Issue*")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Theme.ink)
                        
                        if receiptProducts.isEmpty {
                            HStack {
                                Spacer()
                                ProgressView()
                                Spacer()
                            }
                            .padding(.vertical, 10)
                        } else {
                            VStack(spacing: 10) {
                                ForEach(receiptProducts) { prod in
                                    Button {
                                        selectedProductID = prod.dbID
                                    } label: {
                                        HStack(spacing: 12) {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.title3)
                                                .foregroundStyle(selectedProductID == prod.dbID ? Theme.gold : Theme.line)
                                            
                                            // Product Image Mock/Placeholder
                                            Image(systemName: "tag")
                                                .font(.title2)
                                                .foregroundStyle(Theme.gold)
                                                .frame(width: 44, height: 44)
                                                .background(Theme.selected, in: RoundedRectangle(cornerRadius: 10))
                                            
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(prod.name)
                                                    .font(.subheadline.weight(.bold))
                                                    .foregroundStyle(Theme.ink)
                                                Text("Brand: \(prod.brand) | SKU: \(prod.id)")
                                                    .font(.caption.weight(.semibold))
                                                    .foregroundStyle(Theme.muted)
                                            }
                                            Spacer()
                                        }
                                        .padding(12)
                                        .background(selectedProductID == prod.dbID ? Theme.selected.opacity(0.5) : Color.white.opacity(0.4))
                                        .clipShape(RoundedRectangle(cornerRadius: 14))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14)
                                                .stroke(selectedProductID == prod.dbID ? Theme.gold : Theme.line.opacity(0.2), lineWidth: 1)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
            }
            
            // Support Request Form Section (Only visible when receipt and product are chosen)
            if selectedReceipt != nil && !selectedProductID.isEmpty {
                let selectedProdObj = products.first(where: { $0.dbID == selectedProductID })
                
                CardView {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("After-Sale Support Details")
                            .font(.headline.weight(.black))
                            .foregroundStyle(Theme.ink)
                        
                        if let prod = selectedProdObj {
                            Text("Selected: \(prod.name) (\(prod.brand))")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(Theme.gold)
                        }
                        
                        // Request Type Selector
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Request Type*")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(Theme.ink)
                            
                            HStack(spacing: 12) {
                                RequestTypeTabButton(title: "Repair", icon: "wrench.and.screwdriver", typeID: "repair", activeType: $selectedRequestType)
                                RequestTypeTabButton(title: "Service", icon: "scissors", typeID: "service", activeType: $selectedRequestType)
                                RequestTypeTabButton(title: "Exchange", icon: "arrow.triangle.2.circlepath", typeID: "exchange", activeType: $selectedRequestType)
                            }
                        }
                        
                        // Photo Evidence Section
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Photo Evidence")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(Theme.ink)
                            
                            if let photo = selectedPhoto {
                                HStack {
                                    Image(uiImage: photo)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(height: 100)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
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
                                .background(Color.white.opacity(0.5), in: RoundedRectangle(cornerRadius: 14))
                            } else {
                                Button {
                                    showingPhotoSource = true
                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: "camera")
                                            .foregroundStyle(Theme.gold)
                                        Text("Add Product Photo")
                                            .font(.subheadline.weight(.bold))
                                            .foregroundStyle(Theme.ink)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 52)
                                    .background(Color.white.opacity(0.6), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .stroke(Theme.line.opacity(0.4), lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        
                        // Problem Description Notes
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Description & Notes")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(Theme.ink)
                            
                            TextEditor(text: $notes)
                                .scrollContentBackground(.hidden)
                                .padding(10)
                                .frame(minHeight: 100)
                                .background(Color.white.opacity(0.6), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(Theme.line.opacity(0.4), lineWidth: 1)
                                )
                                .overlay(alignment: .topLeading) {
                                    if notes.isEmpty {
                                        Text("Describe the service required or the reason for exchange...")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(Theme.muted.opacity(0.7))
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 16)
                                    }
                                }
                        }
                        
                        // Submit Button
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
                                Label("Submit Request to Store Manager", systemImage: "paperplane.fill")
                                    .font(.headline.weight(.bold))
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 56)
                                    .background(Theme.gold, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }
    
    private var pastRequestsPane: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Past Requests Log")
                .font(.headline.weight(.black))
                .foregroundStyle(Theme.ink)
            
            if isLoadingPastRequests {
                HStack {
                    Spacer()
                    ProgressView()
                        .tint(Theme.gold)
                    Spacer()
                }
                .padding(.vertical, 30)
            } else if pastRequests.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "list.bullet.clipboard")
                            .font(.largeTitle)
                            .foregroundStyle(Theme.gold)
                        Text("No past requests submitted yet.")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Theme.muted)
                    }
                    Spacer()
                }
                .padding(.vertical, 40)
                .background(Color.white.opacity(0.4), in: RoundedRectangle(cornerRadius: 16))
            } else {
                VStack(spacing: 12) {
                    ForEach(pastRequests) { req in
                        let prod = products.first(where: { $0.dbID == req.productID })
                        let productName = prod?.name ?? "Product ID: \(req.productID.prefix(8))..."
                        let productBrand = prod?.brand ?? "LuxeMaison"
                        
                        HStack(alignment: .top, spacing: 14) {
                            // Thumbnail or icon
                            if let imgUrl = req.imageUrl, !imgUrl.isEmpty {
                                AsyncImage(url: URL(string: "https://zfengirsvsjikrhxrfit.supabase.co/storage/v1/object/public/aftersaleproduct/\(imgUrl)")) { image in
                                    image
                                        .resizable()
                                        .scaledToFill()
                                } placeholder: {
                                    ProgressView()
                                }
                                .frame(width: 60, height: 60)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            } else {
                                Image(systemName: req.requestType == "repair" ? "wrench.and.screwdriver" : (req.requestType == "service" ? "scissors" : "arrow.triangle.2.circlepath"))
                                    .font(.title2)
                                    .foregroundStyle(Theme.gold)
                                    .frame(width: 60, height: 60)
                                    .background(Theme.selected, in: RoundedRectangle(cornerRadius: 10))
                            }
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text(productName)
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(Theme.ink)
                                
                                Text("Boutique: \(productBrand) | Notes: \(req.notes ?? "No additional notes")")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Theme.muted)
                                    .lineLimit(2)
                                
                                HStack(spacing: 10) {
                                    // Request Type Badge
                                    Text(req.requestType.capitalized)
                                        .font(.caption2.weight(.bold))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Theme.ink.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
                                        .foregroundStyle(Theme.ink)
                                    
                                    // Status Badge
                                    Text(req.status.capitalized)
                                        .font(.caption2.weight(.black))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(statusColor(req.status).opacity(0.15), in: RoundedRectangle(cornerRadius: 6))
                                        .foregroundStyle(statusColor(req.status))
                                }
                            }
                            Spacer()
                        }
                        .padding()
                        .background(Color.white.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Theme.line.opacity(0.2), lineWidth: 1)
                        )
                    }
                }
            }
        }
    }
    
    private func statusColor(_ status: String) -> Color {
        switch status.lowercased() {
        case "pending": return Theme.gold
        case "approved", "completed": return .green
        case "rejected", "failed": return .red
        default: return Theme.ink
        }
    }
    
    private func executeSearch() {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        isSearching = true
        searchSubmitted = true
        selectedClient = nil
        selectedReceipt = nil
        receiptItems = []
        receiptProducts = []
        selectedProductID = ""
        
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        Task {
            do {
                // 1. Search client profiles locally
                let matchedClients = clientProfiles.filter { client in
                    client.id.localizedCaseInsensitiveContains(query) ||
                    client.phone.localizedCaseInsensitiveContains(query) ||
                    client.name.localizedCaseInsensitiveContains(query)
                }
                
                // 2. Search receipt by invoice number from Supabase
                let matchedReceipt = try await SupabaseDBService.shared.fetchReceipt(byInvoiceNumber: query)
                
                await MainActor.run {
                    self.searchResultsClients = matchedClients
                    self.searchedReceipt = matchedReceipt
                    self.isSearching = false
                    
                    // If directly found a receipt, select it
                    if let receipt = matchedReceipt {
                        selectReceipt(receipt)
                    }
                }
            } catch {
                print("Search error: \(error)")
                await MainActor.run {
                    self.isSearching = false
                }
            }
        }
    }
    
    private func selectReceipt(_ receipt: DBReceipt) {
        self.selectedReceipt = receipt
        self.receiptItems = []
        self.receiptProducts = []
        self.selectedProductID = ""
        
        guard let saleID = receipt.saleID else { return }
        
        Task {
            do {
                let items = try await SupabaseDBService.shared.fetchSalesItems(forSaleID: saleID)
                await MainActor.run {
                    self.receiptItems = items
                    // Map back to SalesProduct catalog
                    self.receiptProducts = items.compactMap { item in
                        products.first(where: { $0.dbID == item.productID })
                    }
                    if let firstProd = self.receiptProducts.first {
                        self.selectedProductID = firstProd.dbID
                    }
                }
            } catch {
                print("Failed to fetch receipt items: \(error)")
            }
        }
    }
    
    private func loadPastRequests() {
        isLoadingPastRequests = true
        Task {
            do {
                let requests = try await SupabaseDBService.shared.fetchAfterSaleRequests(for: associateID)
                await MainActor.run {
                    self.pastRequests = requests
                    self.isLoadingPastRequests = false
                }
            } catch {
                print("Failed to load past requests: \(error)")
                await MainActor.run {
                    self.isLoadingPastRequests = false
                }
            }
        }
    }
    
    private func submitRequest() {
        guard let receipt = selectedReceipt else {
            alertTitle = "Receipt Required"
            alertMessage = "Please search and select a receipt first."
            showingAlert = true
            return
        }
        
        guard !selectedProductID.isEmpty else {
            alertTitle = "Product Required"
            alertMessage = "Please select a product from the receipt."
            showingAlert = true
            return
        }
        
        isSubmitting = true
        
        Task {
            do {
                var photoPath: String? = nil
                
                // Upload photo if selected
                if let photo = selectedPhoto {
                    let uniqueName = "img_after_sale_\(Int(Date().timeIntervalSince1970))_\(UUID().uuidString.prefix(6)).jpg"
                    photoPath = try await SupabaseDBService.shared.uploadImage(
                        photo,
                        toBucket: "aftersaleproduct",
                        fileName: uniqueName
                    )
                }
                
                try await SupabaseDBService.shared.submitAfterSaleRequest(
                    receiptID: receipt.receiptID,
                    productID: selectedProductID,
                    requestType: selectedRequestType,
                    reportedBy: associateID,
                    storeID: storeID,
                    notes: notes.isEmpty ? nil : notes,
                    imageUrl: photoPath
                )
                
                await MainActor.run {
                    isSubmitting = false
                    alertTitle = "Success"
                    alertMessage = "After-Sale support request has been submitted to the Store Manager."
                    showingAlert = true
                    
                    // Reset form fields
                    selectedClient = nil
                    selectedReceipt = nil
                    receiptItems = []
                    receiptProducts = []
                    selectedProductID = ""
                    notes = ""
                    selectedPhoto = nil
                    photoFileName = nil
                    searchText = ""
                    searchSubmitted = false
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
}

private struct SegmentedPicker: View {
    @Binding var selected: AfterSaleWorkspaceMode
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(AfterSaleWorkspaceMode.allCases) { mode in
                Button {
                    selected = mode
                } label: {
                    Text(mode.rawValue)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(selected == mode ? .white : Theme.ink.opacity(0.8))
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .background(selected == mode ? Theme.ink : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Theme.line.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

private struct CardView<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .padding(20)
        .background(Color.white.opacity(0.45))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Theme.line.opacity(0.4), lineWidth: 1)
        )
    }
}

private struct RequestTypeTabButton: View {
    let title: String
    let icon: String
    let typeID: String
    @Binding var activeType: String
    
    var body: some View {
        Button {
            activeType = typeID
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.headline)
                Text(title)
                    .font(.subheadline.weight(.bold))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(activeType == typeID ? Theme.ink : Color.white.opacity(0.6))
            .foregroundStyle(activeType == typeID ? .white : Theme.ink)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(activeType == typeID ? Theme.gold : Theme.line.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct PhotoPicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Binding var fileName: String?

    @Environment(\.dismiss) private var dismiss

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PhotoPicker

        init(_ parent: PhotoPicker) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.dismiss()
            
            guard let provider = results.first?.itemProvider, provider.canLoadObject(ofClass: UIImage.self) else {
                return
            }
            
            provider.loadObject(ofClass: UIImage.self) { [weak self] image, error in
                if let image = image as? UIImage {
                    DispatchQueue.main.async {
                        self?.parent.selectedImage = image
                        self?.parent.fileName = "image_\(Int(Date().timeIntervalSince1970)).jpg"
                    }
                }
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
}

struct CameraPicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Binding var fileName: String?

    @Environment(\.dismiss) private var dismiss

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: CameraPicker

        init(_ parent: CameraPicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
                parent.fileName = "image_\(Int(Date().timeIntervalSince1970)).jpg"
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            picker.sourceType = .camera
        } else {
            picker.sourceType = .photoLibrary
        }
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
}
