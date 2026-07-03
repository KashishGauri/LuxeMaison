import SwiftUI

struct LoginView: View {
    @Binding var loggedInDashboard: SalesAssociateDashboard?
    
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var rememberMe: Bool = true
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil
    
    // States for first-time login password reset
    @State private var isShowingResetSheet: Bool = false
    @State private var pendingDashboard: SalesAssociateDashboard? = nil
    @State private var pendingEmail: String = ""
    
    var body: some View {
        ZStack {
            // Elegant background
            Theme.background
                .ignoresSafeArea()
            
            // Decorative background elements for luxury feel
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Circle()
                        .fill(Theme.gold.opacity(0.04))
                        .frame(width: 350, height: 350)
                        .blur(radius: 40)
                        .offset(x: 100, y: 100)
                }
            }
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 32) {
                    Spacer(minLength: 40)
                    
                    // Brand / Logo Section
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .stroke(Theme.gold.opacity(0.4), lineWidth: 1)
                                .frame(width: 80, height: 80)
                            
                            Image(systemName: "crown.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(Theme.goldGradient)
                        }
                        .padding(.bottom, 8)
                        
                        Text("L'ATELIER")
                            .font(.system(size: 36, weight: .light, design: .serif))
                            .tracking(6)
                            .foregroundStyle(Theme.ink)
                        
                        Text("BOUTIQUE ASSOCIATE PORTAL")
                            .font(.system(size: 11, weight: .semibold))
                            .tracking(3)
                            .foregroundStyle(Theme.muted)
                    }
                    .padding(.top, 20)
                    
                    // Main Login Card
                    VStack(spacing: 24) {
                        Text("Boutique Sign-In")
                            .font(.system(size: 20, weight: .medium, design: .serif))
                            .foregroundStyle(Theme.ink)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        if let errorMessage = errorMessage {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.octagon.fill")
                                    .foregroundStyle(.red)
                                Text(errorMessage)
                                    .font(.footnote)
                                    .foregroundStyle(.red.opacity(0.9))
                                    .multilineTextAlignment(.leading)
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.red.opacity(0.05))
                            .cornerRadius(8)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                        
                        // Email Field
                        VStack(alignment: .leading, spacing: 6) {
                            Text("BOUTIQUE EMAIL")
                                .font(.system(size: 10, weight: .bold))
                                .tracking(1.5)
                                .foregroundStyle(Theme.muted)
                            
                            HStack {
                                Image(systemName: "envelope")
                                    .foregroundStyle(Theme.gold.opacity(0.7))
                                    .frame(width: 20)
                                
                                TextField("name@boutique.com", text: $email)
                                    .textInputAutocapitalization(.never)
                                    .keyboardType(.emailAddress)
                                    .autocorrectionDisabled()
                                    .font(.system(size: 16))
                                    .foregroundStyle(Theme.ink)
                            }
                            .padding(.vertical, 10)
                            
                            Divider()
                                .background(Theme.gold.opacity(0.3))
                        }
                        
                        // Password Field
                        VStack(alignment: .leading, spacing: 6) {
                            Text("PASSWORD")
                                .font(.system(size: 10, weight: .bold))
                                .tracking(1.5)
                                .foregroundStyle(Theme.muted)
                            
                            HStack {
                                Image(systemName: "lock")
                                    .foregroundStyle(Theme.gold.opacity(0.7))
                                    .frame(width: 20)
                                
                                SecureField("Enter boutique password", text: $password)
                                    .font(.system(size: 16))
                                    .foregroundStyle(Theme.ink)
                            }
                            .padding(.vertical, 10)
                            
                            Divider()
                                .background(Theme.gold.opacity(0.3))
                        }
                        
                        // Remember Me / Checkbox Row
                        Button(action: {
                            withAnimation(.easeIn(duration: 0.15)) {
                                rememberMe.toggle()
                            }
                        }) {
                            HStack(spacing: 10) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(Theme.gold, lineWidth: 1.5)
                                        .frame(width: 18, height: 18)
                                    
                                    if rememberMe {
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(Theme.gold)
                                            .frame(width: 11, height: 11)
                                    }
                                }
                                
                                Text("Remember me on this boutique device")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Theme.muted)
                                
                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(.vertical, 4)
                        
                        // Login Action Button
                        Button(action: handleLogin) {
                            ZStack {
                                Theme.goldGradient
                                
                                if isLoading {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text("AUTHENTICATE")
                                        .font(.system(size: 14, weight: .semibold))
                                        .tracking(2)
                                        .foregroundStyle(.white)
                                }
                            }
                            .frame(height: 50)
                            .cornerRadius(12)
                            .shadow(color: Theme.gold.opacity(0.2), radius: 8, x: 0, y: 4)
                        }
                        .disabled(isLoading)
                        .padding(.top, 8)
                    }
                    .padding(32)
                    .background(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(Color.white.opacity(0.75))
                            .background(.ultraThinMaterial)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(Theme.gold.opacity(0.15), lineWidth: 1)
                    )
                    .padding(.horizontal, 24)
                    
                    Spacer(minLength: 24)
                }
            }
        }
        .onAppear {
            errorMessage = nil
            isLoading = false
            // "Remember me" only pre-fills the saved boutique email as a convenience.
            // The associate must still enter their password and authenticate, so a
            // valid credential check (against Supabase for real accounts) always runs
            // — the app never signs in on its own.
            if email.isEmpty,
               let savedEmail = UserDefaults.standard.string(forKey: "saved_associate_email") {
                email = savedEmail
            }
            NotificationManager.shared.requestAuthorization()
        }
        // Password Reset sheet presented for first-time login
        .sheet(isPresented: $isShowingResetSheet) {
            let cleanEmail = pendingEmail.lowercased()
            let token = UserDefaults.standard.string(forKey: "supabase_access_token_\(cleanEmail)")
            PasswordResetSheet(email: pendingEmail, accessToken: token) {
                UserDefaults.standard.set(true, forKey: "password_reset_\(cleanEmail)")
                
                if let dashboard = pendingDashboard {
                    performLoginSuccess(with: dashboard)
                }
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }
    
    private func handleLogin() {
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        guard !cleanEmail.isEmpty else {
            withAnimation {
                errorMessage = "Please enter your boutique email address."
                isLoading = false
            }
            return
        }
        
        guard !password.isEmpty else {
            withAnimation {
                errorMessage = "Please enter your password."
                isLoading = false
            }
            return
        }

        let enteredPassword = password

        withAnimation {
            isLoading = true
            errorMessage = nil
        }

        // Internal helper to complete validation and check if password reset is needed
        func processLogin(with dashboard: SalesAssociateDashboard) {
            let isReset = UserDefaults.standard.bool(forKey: "password_reset_\(cleanEmail)")
            if !isReset {
                // First-time login: show password reset sheet
                pendingEmail = cleanEmail
                pendingDashboard = dashboard
                isLoading = false
                isShowingResetSheet = true
            } else {
                // Already reset, login directly
                performLoginSuccess(with: dashboard)
            }
        }

        // Verify the password against Supabase Auth. The password lives in Supabase
        // (not the User table), so this is the only valid check — a wrong/empty
        // password can never sign in.
        Task {
            do {
                let dbUser = try await SupabaseDBService.shared.signIn(email: cleanEmail, password: enteredPassword)
                await MainActor.run {
                    // Password already verified by Supabase — check for first-time password reset.
                    let dashboard = SalesAssociateDashboard.createDynamic(from: dbUser)
                    processLogin(with: dashboard)
                }
            } catch let error as AuthError {
                await MainActor.run {
                    withAnimation {
                        isLoading = false
                        errorMessage = error.errorDescription
                    }
                }
            } catch {
                await MainActor.run {
                    withAnimation {
                        isLoading = false
                        errorMessage = "Unable to connect: \(error.localizedDescription). Please retry."
                    }
                }
            }
        }
    }
    
    private func performLoginSuccess(with dashboard: SalesAssociateDashboard) {
        if rememberMe {
            // Save state to UserDefaults
            UserDefaults.standard.set(dashboard.associate.email, forKey: "saved_associate_email")
            UserDefaults.standard.set(true, forKey: "is_logged_in")
        } else {
            UserDefaults.standard.removeObject(forKey: "saved_associate_email")
            UserDefaults.standard.removeObject(forKey: "is_logged_in")
        }
        
        let userId = dashboard.associate.id
        Task {
            await SupabaseDBService.shared.updateUserActiveStatus(userId: userId, isActive: true)
        }
        
        withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) {
            self.loggedInDashboard = dashboard
            self.isLoading = false
        }
    }
}

// Beautiful sheet prompting user to reset their password on first login
struct PasswordResetSheet: View {
    let email: String
    let accessToken: String?
    let onCompletion: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var newPassword: String = ""
    @State private var confirmPassword: String = ""
    @State private var errorMessage: String? = nil
    @State private var isLoading: Bool = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background
                    .ignoresSafeArea()
                
                VStack(spacing: 28) {
                    // Header Description
                    VStack(spacing: 8) {
                        Image(systemName: "key.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(Theme.gold)
                            .padding(.bottom, 8)
                        
                        Text("Set New Password")
                            .font(.system(size: 24, weight: .light, design: .serif))
                            .foregroundStyle(Theme.ink)
                        
                        Text("For security, you must set a new boutique password on first-time sign-in.")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.muted)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                    .padding(.top, 24)
                    
                    // Card containing inputs
                    VStack(spacing: 20) {
                        if let errorMessage = errorMessage {
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundStyle(.red)
                                .padding(8)
                                .frame(maxWidth: .infinity)
                                .background(Color.red.opacity(0.05))
                                .cornerRadius(8)
                        }
                        
                        // New Password field
                        VStack(alignment: .leading, spacing: 6) {
                            Text("NEW PASSWORD")
                                .font(.system(size: 10, weight: .bold))
                                .tracking(1.5)
                                .foregroundStyle(Theme.muted)
                            
                            SecureField("Enter new password", text: $newPassword)
                                .font(.system(size: 16))
                                .foregroundStyle(Theme.ink)
                                .padding(.vertical, 8)
                            
                            Divider()
                                .background(Theme.gold.opacity(0.3))
                        }
                        
                        // Confirm Password field
                        VStack(alignment: .leading, spacing: 6) {
                            Text("CONFIRM NEW PASSWORD")
                                .font(.system(size: 10, weight: .bold))
                                .tracking(1.5)
                                .foregroundStyle(Theme.muted)
                            
                            SecureField("Confirm new password", text: $confirmPassword)
                                .font(.system(size: 16))
                                .foregroundStyle(Theme.ink)
                                .padding(.vertical, 8)
                            
                            Divider()
                                .background(Theme.gold.opacity(0.3))
                        }
                        
                        // Save & Sign In Button
                        Button(action: saveNewPassword) {
                            ZStack {
                                Theme.goldGradient
                                
                                if isLoading {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text("UPDATE PASSWORD & SIGN IN")
                                        .font(.system(size: 14, weight: .semibold))
                                        .tracking(2)
                                        .foregroundStyle(.white)
                                }
                            }
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .cornerRadius(12)
                            .shadow(color: Theme.gold.opacity(0.2), radius: 8, x: 0, y: 4)
                        }
                        .disabled(isLoading)
                        .padding(.top, 12)
                    }
                    .padding(28)
                    .background(Color.white.opacity(0.8))
                    .cornerRadius(20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Theme.gold.opacity(0.15), lineWidth: 1)
                    )
                    .padding(.horizontal, 24)
                    
                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(Theme.muted)
                    .disabled(isLoading)
                }
            }
        }
    }
    
    private func saveNewPassword() {
        guard newPassword.count >= 4 else {
            errorMessage = "New password must be at least 4 characters."
            return
        }
        
        guard newPassword == confirmPassword else {
            errorMessage = "Password confirmation does not match."
            return
        }
        
        let cleanEmail = email.lowercased()
        if let token = accessToken {
            isLoading = true
            errorMessage = nil
            Task {
                do {
                    try await SupabaseDBService.shared.updatePassword(email: cleanEmail, newPassword: newPassword, accessToken: token)
                    await MainActor.run {
                        isLoading = false
                        UserDefaults.standard.set(newPassword, forKey: "user_password_\(cleanEmail)")
                        onCompletion()
                        dismiss()
                    }
                } catch {
                    await MainActor.run {
                        isLoading = false
                        errorMessage = "Failed to update password: \(error.localizedDescription)"
                    }
                }
            }
        } else {
            UserDefaults.standard.set(newPassword, forKey: "user_password_\(cleanEmail)")
            onCompletion()
            dismiss()
        }
    }
}

// Extension to construct a SalesAssociateDashboard dynamically from a DBUser profile
extension SalesAssociateDashboard {
    static func createDynamic(from dbUser: DBUser) -> SalesAssociateDashboard {
        let firstName = dbUser.firstName ?? ""
        let lastName = dbUser.lastName ?? ""
        let fullName = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespacesAndNewlines)
        let name = fullName.isEmpty ? "Associate" : fullName
        
        // Generate initials
        let initials: String
        let parts = name.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        if parts.count >= 2 {
            initials = "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        } else if let first = parts.first {
            initials = String(first.prefix(2)).uppercased()
        } else {
            initials = "SA"
        }
        
        return SalesAssociateDashboard(
            associate: AssociateProfile(
                id: dbUser.id,
                initials: initials,
                name: name,
                role: dbUser.userRole ?? "Sales Associate",
                boutique: "South Mumbai",
                email: dbUser.email ?? "",
                phone: dbUser.phoneNumber ?? "+91 99999 99999",
                employeeID: "SA-\(dbUser.id.prefix(4).uppercased())",
                shift: "General shift"
            ),
            monthlyGoal: SalesGoal(
                title: "Monthly Sales Goal",
                progress: 0.20,
                achieved: "Rs. 1.0L",
                target: "Rs. 5.0L"
            ),
            priorityItems: [
                PriorityItem(
                    icon: "sparkles",
                    title: "Welcome aboard",
                    subtitle: "Setup your digital boutique presence",
                    badge: "New"
                )
            ],
            quickActions: [
                QuickAction(icon: "person.badge.plus", title: "Start Client", isPrimary: true),
                QuickAction(icon: "calendar.badge.clock", title: "Appointments", isPrimary: false),
                QuickAction(icon: "checklist", title: "Daily Tasks", isPrimary: false),
                QuickAction(icon: "camera.viewfinder", title: "Capture Store", isPrimary: false),
                QuickAction(icon: "viewfinder", title: "Scan Item", isPrimary: false)
            ],
            metrics: [
                DashboardMetric(title: "Open Carts", value: "00")
            ],
            weeklySales: WeeklySalesSummary(
                total: "Rs. 0L",
                change: "0%",
                comparison: "No sales yet",
                bestDay: "Mon",
                bestDayLabel: "Best sales day",
                days: [
                    DailySales(day: "Mon", amount: "0", progress: 0, isBest: false),
                    DailySales(day: "Tue", amount: "0", progress: 0, isBest: false),
                    DailySales(day: "Wed", amount: "0", progress: 0, isBest: false),
                    DailySales(day: "Thu", amount: "0", progress: 0, isBest: false),
                    DailySales(day: "Fri", amount: "0", progress: 0, isBest: false),
                    DailySales(day: "Sat", amount: "0", progress: 0, isBest: false),
                    DailySales(day: "Sun", amount: "0", progress: 0, isBest: false)
                ]
            )
        )
    }
}

#Preview {
    LoginView(loggedInDashboard: .constant(nil))
}
