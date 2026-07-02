//
//  Sales_AssociateApp.swift
//  Sales Associate
//
//  Created by Gauri on 24/06/26.
//

import SwiftUI

@main
struct Sales_AssociateApp: App {
    @State private var loggedInDashboard: SalesAssociateDashboard? = nil
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                if let dashboard = loggedInDashboard {
                    SalesAssociateRootView(
                        onBack: {},
                        loggedInDashboard: dashboard,
                        onLogout: {
                            let userId = dashboard.associate.id
                            Task {
                                await SupabaseDBService.shared.updateUserActiveStatus(userId: userId, isActive: false)
                                UserDefaults.standard.removeObject(forKey: "active_session_access_token")
                            }
                            
                            // Clear login persistence state on logout
                            UserDefaults.standard.removeObject(forKey: "saved_associate_email")
                            UserDefaults.standard.set(false, forKey: "is_logged_in")
                            
                            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                                loggedInDashboard = nil
                            }
                        }
                    )
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.98)),
                        removal: .opacity
                    ))
                } else {
                    LoginView(loggedInDashboard: $loggedInDashboard)
                        .transition(.opacity)
                }
            }
        }
    }
}
