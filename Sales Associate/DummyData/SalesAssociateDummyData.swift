extension SalesAssociateDashboard {
    static let sample = SalesAssociateDashboard(
        associate: AssociateProfile(
            initials: "SA",
            name: "Gauri Sharma",
            role: "Sales Associate",
            boutique: "South Mumbai",
            email: "gauri.kashish@rsms.in",
            phone: "+91 98765 43210",
            employeeID: "SA-2048",
            shift: "Morning shift"
        ),
        monthlyGoal: SalesGoal(
            title: "Monthly Sales Goal",
            progress: 0.68,
            achieved: "Rs. 4.8L",
            target: "Rs. 7.0L"
        ),
        priorityItems: [
            PriorityItem(
                icon: "crown",
                title: "VIP appointment",
                subtitle: "Aisha Kapoor, 12:30 PM",
                badge: "Now"
            ),
            PriorityItem(
                icon: "camera",
                title: "Display photos",
                subtitle: "Upload pending for planogram",
                badge: nil
            )
        ],
        quickActions: [
            QuickAction(icon: "person.badge.plus", title: "Start Client", isPrimary: true),
            QuickAction(icon: "calendar.badge.clock", title: "Appointments", isPrimary: false),
            QuickAction(icon: "list.clipboard", title: "Issue", isPrimary: false),
            QuickAction(icon: "viewfinder", title: "Scan Item", isPrimary: false)
        ],
        metrics: [
            DashboardMetric(title: "Open Carts", value: "11"),
            DashboardMetric(title: "Follow-ups", value: "09"),
            DashboardMetric(title: "VIP Today", value: "03")
        ],
        weeklySales: WeeklySalesSummary(
            total: "Rs. 1.18L",
            change: "+12%",
            comparison: "Compared with last week",
            bestDay: "Fri",
            bestDayLabel: "Best sales day",
            days: [
                DailySales(day: "Mon", amount: "12k", progress: 0.42, isBest: false),
                DailySales(day: "Tue", amount: "16k", progress: 0.55, isBest: false),
                DailySales(day: "Wed", amount: "14k", progress: 0.48, isBest: false),
                DailySales(day: "Thu", amount: "19k", progress: 0.66, isBest: false),
                DailySales(day: "Fri", amount: "25k", progress: 0.86, isBest: true),
                DailySales(day: "Sat", amount: "21k", progress: 0.74, isBest: false),
                DailySales(day: "Sun", amount: "11k", progress: 0.39, isBest: false)
            ]
        )
    )

    static let samples: [SalesAssociateDashboard] = [
        sample,
        SalesAssociateDashboard(
            associate: AssociateProfile(
                initials: "KM",
                name: "Kabir Malhotra",
                role: "Senior Sales Associate",
                boutique: "Delhi DLF Emporio",
                email: "kabir.malhotra@rsms.in",
                phone: "+91 99887 76655",
                employeeID: "SA-3012",
                shift: "Evening shift"
            ),
            monthlyGoal: SalesGoal(
                title: "Monthly Sales Goal",
                progress: 0.82,
                achieved: "Rs. 8.2L",
                target: "Rs. 10.0L"
            ),
            priorityItems: [
                PriorityItem(
                    icon: "star",
                    title: "Special Handoff",
                    subtitle: "Riya Shah, 3:00 PM",
                    badge: "Upcoming"
                ),
                PriorityItem(
                    icon: "wrench.adjustable",
                    title: "Repair Check",
                    subtitle: "Cartier glass replacement update",
                    badge: "Urgent"
                )
            ],
            quickActions: [
                QuickAction(icon: "person.badge.plus", title: "Start Client", isPrimary: true),
                QuickAction(icon: "calendar.badge.clock", title: "Appointments", isPrimary: false),
                QuickAction(icon: "list.clipboard", title: "Issue", isPrimary: false),
                QuickAction(icon: "viewfinder", title: "Scan Item", isPrimary: false)
            ],
            metrics: [
                DashboardMetric(title: "Open Carts", value: "05"),
                DashboardMetric(title: "Follow-ups", value: "14"),
                DashboardMetric(title: "VIP Today", value: "05")
            ],
            weeklySales: WeeklySalesSummary(
                total: "Rs. 2.10L",
                change: "+18%",
                comparison: "Compared with last week",
                bestDay: "Sat",
                bestDayLabel: "Best sales day",
                days: [
                    DailySales(day: "Mon", amount: "22k", progress: 0.35, isBest: false),
                    DailySales(day: "Tue", amount: "28k", progress: 0.45, isBest: false),
                    DailySales(day: "Wed", amount: "30k", progress: 0.48, isBest: false),
                    DailySales(day: "Thu", amount: "35k", progress: 0.56, isBest: false),
                    DailySales(day: "Fri", amount: "42k", progress: 0.68, isBest: false),
                    DailySales(day: "Sat", amount: "53k", progress: 0.85, isBest: true),
                    DailySales(day: "Sun", amount: "20k", progress: 0.32, isBest: false)
                ]
            )
        ),
        SalesAssociateDashboard(
            associate: AssociateProfile(
                initials: "AS",
                name: "Ananya Sen",
                role: "Boutique Ambassador",
                boutique: "Bengaluru UB City",
                email: "ananya.sen@rsms.in",
                phone: "+91 91234 56789",
                employeeID: "SA-4105",
                shift: "General shift"
            ),
            monthlyGoal: SalesGoal(
                title: "Monthly Sales Goal",
                progress: 0.45,
                achieved: "Rs. 3.6L",
                target: "Rs. 8.0L"
            ),
            priorityItems: [
                PriorityItem(
                    icon: "crown",
                    title: "Ultra-VIP Visit",
                    subtitle: "Arjun Mehta, 5:30 PM",
                    badge: "Today"
                ),
                PriorityItem(
                    icon: "shippingbox",
                    title: "Stock Reconcile",
                    subtitle: "Verify 18 handbags in boutique",
                    badge: "Routine"
                )
            ],
            quickActions: [
                QuickAction(icon: "person.badge.plus", title: "Start Client", isPrimary: true),
                QuickAction(icon: "calendar.badge.clock", title: "Appointments", isPrimary: false),
                QuickAction(icon: "list.clipboard", title: "Issue", isPrimary: false),
                QuickAction(icon: "viewfinder", title: "Scan Item", isPrimary: false)
            ],
            metrics: [
                DashboardMetric(title: "Open Carts", value: "08"),
                DashboardMetric(title: "Follow-ups", value: "11"),
                DashboardMetric(title: "VIP Today", value: "02")
            ],
            weeklySales: WeeklySalesSummary(
                total: "Rs. 1.45L",
                change: "-3%",
                comparison: "Compared with last week",
                bestDay: "Wed",
                bestDayLabel: "Best sales day",
                days: [
                    DailySales(day: "Mon", amount: "18k", progress: 0.40, isBest: false),
                    DailySales(day: "Tue", amount: "22k", progress: 0.48, isBest: false),
                    DailySales(day: "Wed", amount: "32k", progress: 0.71, isBest: true),
                    DailySales(day: "Thu", amount: "20k", progress: 0.44, isBest: false),
                    DailySales(day: "Fri", amount: "25k", progress: 0.55, isBest: false),
                    DailySales(day: "Sat", amount: "15k", progress: 0.33, isBest: false),
                    DailySales(day: "Sun", amount: "13k", progress: 0.28, isBest: false)
                ]
            )
        )
    ]
}

extension StockDashboard {
    static let sample = StockDashboard(
        metrics: [
            StockMetric(title: "In Boutique", value: "18", detail: "sellable pieces"),
            StockMetric(title: "SM Review", value: "03", detail: "fulfillment checks"),
            StockMetric(title: "Scanned Today", value: "12", detail: "certificate checks")
        ],
        issueTypes: [
            StockIssueType(id: "missing", title: "Missing", icon: "exclamationmark.triangle", description: "Received quantity is lower than the inventory handoff count."),
            StockIssueType(id: "damage", title: "Damage", icon: "sparkle.magnifyingglass", description: "Item arrived damaged during inventory handoff or transit."),
            StockIssueType(id: "mismatch", title: "Mismatch", icon: "tag", description: "Received item does not match the expected box, tag, or name.")
        ],
        scanChecks: [
            StockScanCheck(title: "SKU matched", status: "HB-221 verified", icon: "checkmark.seal"),
            StockScanCheck(title: "Certificate", status: "Authenticity record found", icon: "doc.text.magnifyingglass"),
            StockScanCheck(title: "Store status", status: "Available for selling", icon: "shippingbox")
        ],
        reviews: [
            StoreManagerReview(
                title: "Missing quantity reviewed",
                status: "Approved follow-up",
                note: "SM confirmed short receipt and routed it to Inventory Controller.",
                time: "Today, 10:05 AM",
                icon: "checkmark.seal"
            ),
            StoreManagerReview(
                title: "Damage photo checked",
                status: "More evidence needed",
                note: "Upload a closer photo of clasp and packaging seal.",
                time: "Yesterday, 6:20 PM",
                icon: "camera.macro"
            )
        ]
    )
}

extension IssueDashboard {
    static let sample = IssueDashboard(
        issueTypes: [
            IssueRequestType(id: "missing", title: "Missing", icon: "exclamationmark.triangle", description: "Report missing item details or missing proof to Store Manager."),
            IssueRequestType(id: "exchange", title: "Exchange", icon: "arrow.left.arrow.right", description: "Request Store Manager review for exchange eligibility."),
            IssueRequestType(id: "repair", title: "Repair", icon: "wrench.adjustable", description: "Capture diagnosis, warranty, parts, labour, and charge basis."),
            IssueRequestType(id: "service", title: "Service Issue", icon: "sparkles", description: "Raise service support such as cleaning, authentication, warranty, or adjustment.")
        ],
        repairDiagnosisTypes: [
            "Battery issue",
            "Glass replacement",
            "Movement issue",
            "Strap replacement",
            "Complete servicing"
        ],
        repairServicePrices: [
            "Battery replacement - Fixed price",
            "Strap replacement - Model based",
            "Glass replacement - Watch model based",
            "Complete servicing - Category fixed"
        ],
        repairWarrantyOptions: [
            "In warranty - manufacturing defect",
            "Accidental damage - chargeable",
            "Warranty expired - chargeable"
        ],
        returnExchangeTypes: ["Return", "Exchange", "Cancellation"],
        serviceTypes: ["Cleaning", "Authentication", "Warranty", "Resize / Adjustment"],
        repairStatuses: ["Assessment pending", "Receipt generated", "Client informed", "SM review needed"],
        historyItems: [
            IssueHistoryItem(
                title: "Exchange exception",
                requestType: "Return / Exchange",
                status: .approved,
                note: "SM approved exchange after receipt and product condition check.",
                time: "Today, 9:40 AM",
                icon: "arrow.left.arrow.right"
            ),
            IssueHistoryItem(
                title: "Clasp repair estimate",
                requestType: "Repair",
                status: .pending,
                note: "Waiting for SM review on repair charge before sharing final receipt.",
                time: "Yesterday, 6:15 PM",
                icon: "wrench.adjustable"
            ),
            IssueHistoryItem(
                title: "Late return request",
                requestType: "Return / Exchange",
                status: .rejected,
                note: "Return window exceeded and exception was not approved.",
                time: "22 Jun, 4:30 PM",
                icon: "xmark.seal"
            )
        ]
    )
}

extension ProductCategory {
    static let sampleCategories: [ProductCategory] = [
        ProductCategory(id: "handbags", title: "Handbags", icon: "handbag"),
        ProductCategory(id: "clutches", title: "Clutches", icon: "bag"),
        ProductCategory(id: "watches", title: "Watches", icon: "applewatch"),
        ProductCategory(id: "jewellery", title: "Jewellery", icon: "sparkles"),
        ProductCategory(id: "necklaces", title: "Necklaces", icon: "star.circle"),
        ProductCategory(id: "footwear", title: "Footwear", icon: "shoeprints.fill"),
        ProductCategory(id: "accessories", title: "Accessories", icon: "sunglasses")
    ]
}

extension SalesProduct {
    private static func catalogueProduct(
        id: String,
        name: String,
        brand: String = "RSMS",
        categoryID: String,
        audience: String,
        price: String,
        originalPrice: String? = nil,
        imageName: String,
        badge: String? = nil,
        availability: String = "In boutique",
        stockNote: String,
        sizes: [String],
        materials: [String],
        colors: [String],
        suggestedReason: String,
        isWishlisted: Bool = false
    ) -> SalesProduct {
        SalesProduct(
            id: id,
            name: name,
            brand: brand,
            categoryID: categoryID,
            audience: audience,
            price: price,
            originalPrice: originalPrice,
            imageName: imageName,
            badge: badge,
            availability: availability,
            stockNote: stockNote,
            sizes: sizes,
            materials: materials,
            colors: colors,
            suggestedReason: suggestedReason,
            isWishlisted: isWishlisted
        )
    }

    static let sampleProducts: [SalesProduct] = [
        SalesProduct(
            id: "HB-221",
            name: "Serpenti Mini", brand: "Bvlgari",
            categoryID: "handbags",
            audience: "Women",
            price: "Rs. 1.84L",
            originalPrice: "Rs. 2.05L",
            imageName: "ProductSerpentiMini",
            badge: "Client fit",
            availability: "In boutique",
            stockNote: "1 piece available in South Mumbai boutique",
            sizes: ["Mini", "Small"],
            materials: ["Champagne satin", "Crystal handle"],
            colors: ["Champagne", "Black"],
            suggestedReason: "Matches evening event and gold hardware preference",
            isWishlisted: true
        ),
        SalesProduct(
            id: "HB-224",
            name: "Noir Clutch", brand: "Saint Laurent",
            categoryID: "clutches",
            audience: "Women",
            price: "Rs. 2.10L",
            originalPrice: nil,
            imageName: "ProductNoirClutch",
            badge: "Limited",
            availability: "Store Manager visible",
            stockNote: "Not in boutique. Store Manager can review transfer or reorder.",
            sizes: ["Mini"],
            materials: ["Black satin", "Crystal arc"],
            colors: ["Black"],
            suggestedReason: "Best for formal evening looks",
            isWishlisted: false
        ),
        SalesProduct(
            id: "HB-227",
            name: "Pearl Sling", brand: "Chanel",
            categoryID: "handbags",
            audience: "Women",
            price: "Rs. 1.26L",
            originalPrice: nil,
            imageName: "ProductPearlSling",
            badge: nil,
            availability: "In boutique",
            stockNote: "2 pieces available for immediate checkout",
            sizes: ["Small", "Medium"],
            materials: ["Pearl leather", "Gold hardware"],
            colors: ["Ivory", "Pearl"],
            suggestedReason: "Soft neutral option for guest clients",
            isWishlisted: false
        ),
        SalesProduct(
            id: "JW-311",
            name: "Diamond Set", brand: "Cartier",
            categoryID: "jewellery",
            audience: "Women",
            price: "Rs. 3.60L",
            originalPrice: nil,
            imageName: "ProductDiamondSet",
            badge: "VIP",
            availability: "In boutique",
            stockNote: "Display-ready hero set available",
            sizes: ["One size"],
            materials: ["Diamond", "White gold"],
            colors: ["Silver", "Platinum"],
            suggestedReason: "Premium showcase piece for VIP previews",
            isWishlisted: true
        ),
        SalesProduct(
            id: "JW-322",
            name: "Art Deco Necklace", brand: "Van Cleef & Arpels",
            categoryID: "necklaces",
            audience: "Women",
            price: "Rs. 2.48L",
            originalPrice: "Rs. 2.70L",
            imageName: "ProductArtDeco",
            badge: "New",
            availability: "In boutique",
            stockNote: "Available after authentication scan",
            sizes: ["One size"],
            materials: ["White gold", "Blue velvet set"],
            colors: ["Silver", "Midnight"],
            suggestedReason: "Strong match for statement jewellery requests",
            isWishlisted: false
        ),
        SalesProduct(
            id: "AC-114",
            name: "Satin Evening Clutch", brand: "Jimmy Choo",
            categoryID: "accessories",
            audience: "Women",
            price: "Rs. 1.58L",
            originalPrice: nil,
            imageName: "ProductSatinClutch",
            badge: "Gift edit",
            availability: "In boutique",
            stockNote: "Ready for packaging and gift note",
            sizes: ["Compact"],
            materials: ["Pearl satin", "Crystal clasp"],
            colors: ["Ivory", "Champagne"],
            suggestedReason: "Good fallback for guest profile styling",
            isWishlisted: false
        ),
        SalesProduct(
            id: "WT-501",
            name: "Heritage Chrono", brand: "Omega",
            categoryID: "watches",
            audience: "Men",
            price: "Rs. 4.75L",
            originalPrice: nil,
            imageName: "ProductTitanClassicWatch",
            badge: "Men",
            availability: "By transfer",
            stockNote: "Available from partner store after Store Manager review",
            sizes: ["40 mm", "42 mm"],
            materials: ["Steel", "Leather strap"],
            colors: ["Black", "Silver"],
            suggestedReason: "Men's gifting recommendation for high-value clients",
            isWishlisted: false
        ),
        catalogueProduct(
            id: "HB-301",
            name: "Pearl Floral Clutch",
            categoryID: "handbags",
            audience: "Women",
            price: "Rs. 1.42L",
            imageName: "ProductFloralPearlClutch",
            badge: "Evening",
            stockNote: "Compact evening piece available for styling trials",
            sizes: ["Mini"],
            materials: ["Pearl beading", "Floral applique"],
            colors: ["Ivory", "Champagne"],
            suggestedReason: "Soft occasion bag for bridal and dinner looks"
        ),
        catalogueProduct(
            id: "HB-302",
            name: "Noir Executive Briefcase",
            categoryID: "handbags",
            audience: "Men",
            price: "Rs. 1.95L",
            imageName: "ProductNoirExecutiveBriefcase",
            badge: "Men",
            availability: "By transfer",
            stockNote: "Store Manager can review inter-store transfer",
            sizes: ["Medium", "Large"],
            materials: ["Pebble leather", "Contrast trim"],
            colors: ["Navy", "Black"],
            suggestedReason: "Formal work bag for premium gifting"
        ),
        catalogueProduct(
            id: "HB-303",
            name: "Black Executive Case",
            categoryID: "handbags",
            audience: "Men",
            price: "Rs. 2.20L",
            imageName: "ProductBlackExecutiveCase",
            badge: "Classic",
            stockNote: "Available for executive styling and gifting",
            sizes: ["Large"],
            materials: ["Grained leather", "Silver hardware"],
            colors: ["Black"],
            suggestedReason: "Clean formal choice for client workwear needs"
        ),
        catalogueProduct(
            id: "HB-304",
            name: "Coral Capucines",
            categoryID: "handbags",
            audience: "Women",
            price: "Rs. 3.90L",
            imageName: "ProductCoralCapucines",
            badge: "Showcase",
            stockNote: "Hero display piece available after condition check",
            sizes: ["Small"],
            materials: ["Leather", "Crystal embellishment"],
            colors: ["Ivory", "Coral"],
            suggestedReason: "Statement bag for occasion-led styling"
        ),
        catalogueProduct(
            id: "HB-305",
            name: "Blush Floral Mini",
            categoryID: "handbags",
            audience: "Women",
            price: "Rs. 2.85L",
            imageName: "ProductBlushFloralMiniBag",
            badge: "New",
            stockNote: "Available for client preview and wishlist",
            sizes: ["Mini"],
            materials: ["Blush leather", "Floral embroidery"],
            colors: ["Blush", "Gold"],
            suggestedReason: "Delicate mini bag for soft festive looks"
        ),
        catalogueProduct(
            id: "HB-306",
            name: "Floral Mini Pair",
            categoryID: "handbags",
            audience: "Women",
            price: "Rs. 3.20L",
            imageName: "ProductFloralMiniPair",
            badge: "Pair edit",
            stockNote: "Two colorways visible for comparison",
            sizes: ["Mini"],
            materials: ["Textured leather", "Gold hardware"],
            colors: ["Ivory", "Pink"],
            suggestedReason: "Useful when client wants color comparison"
        ),
        catalogueProduct(
            id: "HB-307",
            name: "Taupe Wrist Pouch",
            categoryID: "handbags",
            audience: "Unisex",
            price: "Rs. 1.10L",
            imageName: "ProductTaupePouch",
            stockNote: "Compact pouch available for quick add-on styling",
            sizes: ["Compact"],
            materials: ["Taupe leather", "Metal zip"],
            colors: ["Taupe"],
            suggestedReason: "Low-profile luxury accessory for everyday use"
        ),
        catalogueProduct(
            id: "HB-308",
            name: "Pink Quilted Top Handle",
            categoryID: "handbags",
            audience: "Women",
            price: "Rs. 2.65L",
            imageName: "ProductPinkQuiltedTopHandle",
            badge: "Client fit",
            stockNote: "Available for bridal and day-event styling",
            sizes: ["Small"],
            materials: ["Quilted leather", "Gold hardware"],
            colors: ["Pink"],
            suggestedReason: "Pairs well with light festive wardrobes"
        ),
        catalogueProduct(
            id: "HB-309",
            name: "Ivory Sculptural Bag",
            categoryID: "handbags",
            audience: "Women",
            price: "Rs. 1.74L",
            imageName: "ProductIvorySculpturalBag",
            stockNote: "Available in boutique for silhouette comparison",
            sizes: ["Medium"],
            materials: ["Ivory leather", "Gold accent"],
            colors: ["Ivory"],
            suggestedReason: "Modern shape for clients avoiding logo-heavy pieces"
        ),
        catalogueProduct(
            id: "HB-310",
            name: "Noir Travel Backpack",
            categoryID: "handbags",
            audience: "Men",
            price: "Rs. 2.40L",
            imageName: "ProductNoirTravelBackpack",
            badge: "Travel",
            stockNote: "Store Manager can confirm current stock state",
            sizes: ["Large"],
            materials: ["Pebble leather", "Black hardware"],
            colors: ["Black"],
            suggestedReason: "Premium travel recommendation for frequent flyers"
        ),
        catalogueProduct(
            id: "HB-311",
            name: "Petal Hobo Bag",
            categoryID: "handbags",
            audience: "Women",
            price: "Rs. 1.68L",
            imageName: "ProductPetalHoboBag",
            stockNote: "Available for casual luxury styling",
            sizes: ["Medium"],
            materials: ["Soft leather", "Braided handle"],
            colors: ["Ivory", "Blush"],
            suggestedReason: "Relaxed silhouette for day-to-evening looks"
        ),
        catalogueProduct(
            id: "HB-312",
            name: "Ivory Flower Mini",
            categoryID: "handbags",
            audience: "Women",
            price: "Rs. 2.18L",
            imageName: "ProductIvoryFlowerMiniBag",
            badge: "Gift edit",
            stockNote: "Ready for gift packaging",
            sizes: ["Mini"],
            materials: ["White leather", "Floral charm"],
            colors: ["White", "Pink"],
            suggestedReason: "Strong gift choice for premium occasions"
        ),
        catalogueProduct(
            id: "HB-313",
            name: "Ivory Chain Tote",
            categoryID: "handbags",
            audience: "Women",
            price: "Rs. 1.96L",
            imageName: "ProductIvoryChainTote",
            stockNote: "Available for walk-in assisted selling",
            sizes: ["Medium"],
            materials: ["Quilted leather", "Chain handle"],
            colors: ["Ivory"],
            suggestedReason: "Everyday luxury tote for neutral styling"
        ),
        catalogueProduct(
            id: "HB-314",
            name: "Noir Cream Backpack",
            categoryID: "handbags",
            audience: "Unisex",
            price: "Rs. 2.30L",
            imageName: "ProductNoirCreamBackpack",
            badge: "Travel",
            availability: "By transfer",
            stockNote: "Available from another store after Store Manager review",
            sizes: ["Large"],
            materials: ["Leather", "Gold zip"],
            colors: ["Black", "Cream"],
            suggestedReason: "Sharp travel option for luxury utility needs"
        ),
        catalogueProduct(
            id: "HB-315",
            name: "Blue Saddle Bag",
            categoryID: "handbags",
            audience: "Women",
            price: "Rs. 1.76L",
            imageName: "ProductBlueSaddleBag",
            stockNote: "Available for soft color styling",
            sizes: ["Small"],
            materials: ["Blue leather", "Gold sculpted handle"],
            colors: ["Blue"],
            suggestedReason: "Fresh color option for day events"
        ),
        catalogueProduct(
            id: "HB-316",
            name: "Chestnut Mini Top Handle",
            categoryID: "handbags",
            audience: "Women",
            price: "Rs. 1.58L",
            imageName: "ProductChestnutMiniTopHandle",
            stockNote: "Available for neutral wardrobe matching",
            sizes: ["Mini"],
            materials: ["Chestnut leather", "Gold hardware"],
            colors: ["Chestnut", "Brown"],
            suggestedReason: "Warm neutral option for understated clients"
        ),
        catalogueProduct(
            id: "HB-317",
            name: "Blue Jacquard Capucines",
            categoryID: "handbags",
            audience: "Women",
            price: "Rs. 3.25L",
            imageName: "ProductBlueJacquardCapucines",
            badge: "Limited",
            stockNote: "Limited display piece, confirm before checkout",
            sizes: ["Small"],
            materials: ["Jacquard", "Gold chain"],
            colors: ["Powder blue", "Gold"],
            suggestedReason: "Statement texture for collectors"
        ),
        catalogueProduct(
            id: "WT-601",
            name: "Panther Diamond Watch",
            categoryID: "watches",
            audience: "Women",
            price: "Rs. 9.80L",
            imageName: "ProductPantherDiamondWatch",
            badge: "High value",
            stockNote: "Requires authentication scan before checkout",
            sizes: ["One size"],
            materials: ["Diamond", "White gold"],
            colors: ["Silver", "Emerald"],
            suggestedReason: "Collector watch with jewel-led styling"
        ),
        catalogueProduct(
            id: "WT-602",
            name: "Royal Pair Watch",
            categoryID: "watches",
            audience: "Unisex",
            price: "Rs. 3.45L",
            imageName: "ProductRoyalPairWatch",
            badge: "Pair edit",
            stockNote: "Pair set available for couple gifting",
            sizes: ["36 mm", "42 mm"],
            materials: ["Ceramic", "Rose gold"],
            colors: ["Black", "Rose gold"],
            suggestedReason: "Useful for anniversary gifting"
        ),
        catalogueProduct(
            id: "WT-603",
            name: "Submariner Box Set",
            categoryID: "watches",
            audience: "Men",
            price: "Rs. 8.40L",
            imageName: "ProductSubmarinerBoxSet",
            badge: "Collector",
            availability: "Store Manager visible",
            stockNote: "Stock state visible to Store Manager for confirmation",
            sizes: ["40 mm"],
            materials: ["Steel", "Ceramic bezel"],
            colors: ["Black", "Silver"],
            suggestedReason: "Premium collector watch for high intent clients"
        ),
        catalogueProduct(
            id: "WT-604",
            name: "Rose Gold Diamond Band",
            categoryID: "watches",
            audience: "Women",
            price: "Rs. 5.60L",
            imageName: "ProductRoseGoldDiamondBand",
            stockNote: "Available after certificate check",
            sizes: ["Small", "Medium"],
            materials: ["Rose gold", "Diamond"],
            colors: ["Rose gold"],
            suggestedReason: "Elegant jewellery-watch crossover"
        ),
        catalogueProduct(
            id: "WT-605",
            name: "Green Dial President",
            categoryID: "watches",
            audience: "Men",
            price: "Rs. 11.20L",
            imageName: "ProductGreenDialPresident",
            badge: "VIP",
            availability: "By transfer",
            stockNote: "Store Manager can request source store confirmation",
            sizes: ["40 mm"],
            materials: ["Gold", "Emerald dial"],
            colors: ["Green", "Gold"],
            suggestedReason: "VIP-grade watch for collector clients"
        ),
        catalogueProduct(
            id: "WT-607",
            name: "Blue Ceramic Edge",
            categoryID: "watches",
            audience: "Unisex",
            price: "Rs. 82k",
            imageName: "ProductBlueCeramicEdge",
            stockNote: "Available for daily wear recommendation",
            sizes: ["38 mm"],
            materials: ["Ceramic", "Steel"],
            colors: ["Blue"],
            suggestedReason: "Slim modern watch for lower-ticket luxury"
        ),
        catalogueProduct(
            id: "WT-608",
            name: "Diamond Day-Date",
            categoryID: "watches",
            audience: "Men",
            price: "Rs. 12.80L",
            imageName: "ProductDiamondDayDate",
            badge: "VIP",
            stockNote: "Certificate and authenticity check required",
            sizes: ["40 mm"],
            materials: ["Rose gold", "Diamond bezel"],
            colors: ["Rose gold", "Chocolate"],
            suggestedReason: "High-value recommendation for VIP watch clients"
        ),
        catalogueProduct(
            id: "WT-609",
            name: "Serpenti Tubogas Watch",
            categoryID: "watches",
            audience: "Women",
            price: "Rs. 6.90L",
            imageName: "ProductSerpentiTubogasWatch",
            badge: "Icon",
            stockNote: "Available after sizing confirmation",
            sizes: ["Small", "Medium"],
            materials: ["Steel", "Rose gold"],
            colors: ["Silver", "Rose gold"],
            suggestedReason: "Iconic flexible bracelet watch for jewellery clients"
        ),
        catalogueProduct(
            id: "WT-610",
            name: "Limited Edition Watch Set",
            categoryID: "watches",
            audience: "Women",
            price: "Rs. 2.95L",
            imageName: "ProductLimitedEditionWatchSet",
            badge: "Limited",
            stockNote: "Gift set available for special request clients",
            sizes: ["One size"],
            materials: ["Two-tone metal", "Bracelet set"],
            colors: ["Silver", "Gold"],
            suggestedReason: "Ready-to-gift limited edition set"
        ),
        catalogueProduct(
            id: "JW-401",
            name: "Panther Bangle",
            categoryID: "jewellery",
            audience: "Women",
            price: "Rs. 7.80L",
            imageName: "ProductPantherBangle",
            badge: "Hero",
            stockNote: "Showcase piece requires handling confirmation",
            sizes: ["Small", "Medium"],
            materials: ["Gold", "Diamond", "Emerald"],
            colors: ["Gold", "Emerald"],
            suggestedReason: "Statement bangle for high-jewellery styling"
        ),
        catalogueProduct(
            id: "JW-402",
            name: "Panther Link Bracelet",
            categoryID: "jewellery",
            audience: "Men",
            price: "Rs. 4.90L",
            imageName: "ProductPantherLinkBracelet",
            badge: "Men",
            stockNote: "Available after certificate verification",
            sizes: ["Medium", "Large"],
            materials: ["Gold", "Diamond"],
            colors: ["Gold"],
            suggestedReason: "Bold jewellery option for men's styling"
        ),
        catalogueProduct(
            id: "JW-403",
            name: "Ruby Bridal Set",
            categoryID: "jewellery",
            audience: "Women",
            price: "Rs. 5.25L",
            imageName: "ProductRubyBridalSet",
            badge: "Bridal",
            stockNote: "Available for bridal preview appointment",
            sizes: ["One size"],
            materials: ["Diamond", "Ruby"],
            colors: ["Ruby", "Silver"],
            suggestedReason: "Bridal set for red stone preference"
        ),
        catalogueProduct(
            id: "JW-404",
            name: "Sapphire Link Bracelet",
            categoryID: "jewellery",
            audience: "Men",
            price: "Rs. 1.85L",
            imageName: "ProductSapphireLinkBracelet",
            stockNote: "Available for accessory add-on",
            sizes: ["Medium", "Large"],
            materials: ["Silver", "Sapphire"],
            colors: ["Blue", "Silver"],
            suggestedReason: "Subtle men's bracelet for formal styling"
        ),
        catalogueProduct(
            id: "JW-405",
            name: "Emerald Drop Necklace",
            categoryID: "jewellery",
            audience: "Women",
            price: "Rs. 6.75L",
            imageName: "ProductEmeraldDropNecklace",
            badge: "Emerald",
            stockNote: "Requires authenticity record before checkout",
            sizes: ["One size"],
            materials: ["Gold", "Diamond", "Emerald"],
            colors: ["Gold", "Emerald"],
            suggestedReason: "Premium emerald option for occasion wear"
        ),
        catalogueProduct(
            id: "JW-406",
            name: "Blue Sapphire Set",
            categoryID: "jewellery",
            audience: "Women",
            price: "Rs. 3.35L",
            imageName: "ProductBlueSapphireSet",
            badge: "Gift edit",
            stockNote: "Ready for gift packaging",
            sizes: ["One size"],
            materials: ["Diamond", "Sapphire"],
            colors: ["Blue", "Silver"],
            suggestedReason: "Elegant boxed set for formal gifting"
        ),
        catalogueProduct(
            id: "JW-407",
            name: "Dior Tennis Bracelet",
            categoryID: "jewellery",
            audience: "Women",
            price: "Rs. 2.25L",
            imageName: "ProductDiorTennisBracelet",
            stockNote: "Available for stack styling",
            sizes: ["Small", "Medium"],
            materials: ["White gold", "Crystal"],
            colors: ["Silver"],
            suggestedReason: "Easy bracelet add-on for curated carts"
        ),
        catalogueProduct(
            id: "JW-408",
            name: "Pink Bvlgari Set",
            categoryID: "jewellery",
            audience: "Women",
            price: "Rs. 4.20L",
            imageName: "ProductPinkBvlgariSet",
            badge: "Set",
            stockNote: "Available for occasion styling",
            sizes: ["One size"],
            materials: ["Rose gold", "Pink stone"],
            colors: ["Rose gold", "Pink"],
            suggestedReason: "Soft color jewellery set for festive clients"
        ),
        catalogueProduct(
            id: "FW-501",
            name: "Patent Oxford",
            categoryID: "footwear",
            audience: "Men",
            price: "Rs. 92k",
            imageName: "ProductPatentOxford",
            stockNote: "Available for formal shoe styling",
            sizes: ["UK 8", "UK 9", "UK 10"],
            materials: ["Patent leather"],
            colors: ["Black"],
            suggestedReason: "Formal option for suit and event clients"
        ),
        catalogueProduct(
            id: "FW-502",
            name: "Medusa Loafer",
            categoryID: "footwear",
            audience: "Men",
            price: "Rs. 1.18L",
            imageName: "ProductMedusaLoafer",
            badge: "Men",
            stockNote: "Available in core sizes",
            sizes: ["UK 7", "UK 8", "UK 9"],
            materials: ["Leather", "Gold hardware"],
            colors: ["Black"],
            suggestedReason: "Sharp loafer for premium menswear looks"
        ),
        catalogueProduct(
            id: "FW-503",
            name: "Crystal Ankle Heel",
            categoryID: "footwear",
            audience: "Women",
            price: "Rs. 1.35L",
            imageName: "ProductCrystalAnkleHeel",
            badge: "Evening",
            stockNote: "Available for occasion styling",
            sizes: ["EU 37", "EU 38", "EU 39"],
            materials: ["Suede", "Crystal strap"],
            colors: ["Black", "Silver"],
            suggestedReason: "Evening heel for cocktail and VIP events"
        ),
        catalogueProduct(
            id: "FW-504",
            name: "Butterfly Heel",
            categoryID: "footwear",
            audience: "Women",
            price: "Rs. 1.52L",
            imageName: "ProductButterflyHeel",
            badge: "Statement",
            stockNote: "Available for try-on by appointment",
            sizes: ["EU 37", "EU 38"],
            materials: ["Crystal", "Transparent strap"],
            colors: ["Ice blue", "Gold"],
            suggestedReason: "Statement heel for bridal and party styling"
        ),
        catalogueProduct(
            id: "FW-505",
            name: "Blue Sling Heel",
            categoryID: "footwear",
            audience: "Women",
            price: "Rs. 84k",
            imageName: "ProductBlueSlingHeel",
            stockNote: "Available for daytime luxury looks",
            sizes: ["EU 36", "EU 37", "EU 38"],
            materials: ["Denim", "Leather trim"],
            colors: ["Blue"],
            suggestedReason: "Soft color option for relaxed styling"
        ),
        catalogueProduct(
            id: "FW-506",
            name: "YSL Logo Heel",
            categoryID: "footwear",
            audience: "Women",
            price: "Rs. 1.78L",
            imageName: "ProductYslLogoHeel",
            badge: "Icon",
            availability: "By transfer",
            stockNote: "Store Manager can confirm availability from source store",
            sizes: ["EU 38", "EU 39", "EU 40"],
            materials: ["Patent leather", "Gold heel"],
            colors: ["Black", "Gold"],
            suggestedReason: "Iconic heel for high-fashion clients"
        ),
        catalogueProduct(
            id: "FW-507",
            name: "Brown Logo Loafer",
            categoryID: "footwear",
            audience: "Men",
            price: "Rs. 1.24L",
            imageName: "ProductBrownLogoLoafer",
            stockNote: "Available for formal wardrobe pairing",
            sizes: ["UK 8", "UK 9"],
            materials: ["Brown leather", "Silver logo"],
            colors: ["Brown"],
            suggestedReason: "Warm formal shoe option for menswear"
        ),
        catalogueProduct(
            id: "FW-508",
            name: "Patent Gucci Loafer",
            categoryID: "footwear",
            audience: "Men",
            price: "Rs. 1.32L",
            imageName: "ProductPatentGucciLoafer",
            stockNote: "Available for event styling",
            sizes: ["UK 7", "UK 8", "UK 9"],
            materials: ["Patent leather"],
            colors: ["Black"],
            suggestedReason: "Polished loafer for black-tie styling"
        ),
        catalogueProduct(
            id: "FW-509",
            name: "Gold Slingback Flat",
            categoryID: "footwear",
            audience: "Women",
            price: "Rs. 96k",
            imageName: "ProductGoldSlingbackFlat",
            stockNote: "Available for comfort-led styling",
            sizes: ["EU 36", "EU 37", "EU 38", "EU 39"],
            materials: ["Nappa leather", "Gold accent"],
            colors: ["Cream", "Gold"],
            suggestedReason: "Elegant flat for long event days"
        ),
        catalogueProduct(
            id: "AC-201",
            name: "Tiger Brooch",
            categoryID: "accessories",
            audience: "Men",
            price: "Rs. 1.15L",
            imageName: "ProductTigerBrooch",
            badge: "Styling",
            stockNote: "Available for suit and pocket-square styling",
            sizes: ["One size"],
            materials: ["Metal", "Ruby stone"],
            colors: ["Silver", "Ruby"],
            suggestedReason: "Distinctive finishing accessory for formal looks"
        )
    ]
}
