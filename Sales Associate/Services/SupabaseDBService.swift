import Foundation

class SupabaseDBService {
    static let shared = SupabaseDBService()
    
    private let baseURL = "https://zfengirsvsjikrhxrfit.supabase.co/rest/v1"
    private let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpmZW5naXJzdnNqaWtyaHhyZml0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODI0MTg5NTIsImV4cCI6MjA5Nzk5NDk1Mn0.rk57GzYVJDkHtEH649eXekzqox0s3O3nH3u8f5KHY5M"
    
    private init() {}
    
    /// Fetches all client profiles from the Supabase database.
    func fetchProfiles() async throws -> [ClientProfile] {
        guard let url = URL(string: "\(baseURL)/client_profiles?select=*") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        guard httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        return try JSONDecoder().decode([ClientProfile].self, from: data)
    }
    
    /// Inserts or updates a single client profile in Supabase.
    func upsertProfile(_ profile: ClientProfile) async throws {
        guard let url = URL(string: "\(baseURL)/client_profiles") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
        
        let encoder = JSONEncoder()
        var dictionary = try JSONSerialization.jsonObject(with: try encoder.encode(profile)) as? [String: Any] ?? [:]
        dictionary.removeValue(forKey: "tasks")
        let jsonData = try JSONSerialization.data(withJSONObject: dictionary)
        request.httpBody = jsonData
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (httpResponse.statusCode == 200 || httpResponse.statusCode == 201) else {
            throw URLError(.badServerResponse)
        }
    }
    
    /// Uploads an array of client profiles in a single batch (used for initial migration).
    func uploadBatchProfiles(_ profiles: [ClientProfile]) async throws {
        guard let url = URL(string: "\(baseURL)/client_profiles") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
        
        let encoder = JSONEncoder()
        let dictionaries = try profiles.map { profile -> [String: Any] in
            var dict = try JSONSerialization.jsonObject(with: try encoder.encode(profile)) as? [String: Any] ?? [:]
            dict.removeValue(forKey: "tasks")
            return dict
        }
        let jsonData = try JSONSerialization.data(withJSONObject: dictionaries)
        request.httpBody = jsonData
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (httpResponse.statusCode == 200 || httpResponse.statusCode == 201) else {
            throw URLError(.badServerResponse)
        }
    }
    
    /// Checks if a sales associate email is registered in the database User table.
    func isUserRegistered(email: String) async -> Bool {
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard let url = URL(string: "\(baseURL)/User?Email=eq.\(cleanEmail)") else {
            return false
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return false
            }
            
            if let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                return !jsonArray.isEmpty
            }
            return false
        } catch {
            return false
        }
    }
    
    /// Fetches the user profile from the database User table by email.
    func fetchUserProfile(email: String) async throws -> DBUser? {
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard let url = URL(string: "\(baseURL)/User?Email=eq.\(cleanEmail)") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        let users = try JSONDecoder().decode([DBUser].self, from: data)
        return users.first
    }
    
    /// Validates the associate's credentials against Supabase Auth (GoTrue) and,
    /// on success, returns their profile row from the `User` table.
    ///
    /// The password lives in Supabase Auth (not the `User` table), so this is the
    /// only correct way to verify it — the app must never accept a local/default
    /// password. Throws `AuthError` on invalid credentials or missing profile.
    func signIn(email: String, password: String) async throws -> DBUser {
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard let url = URL(string: "https://zfengirsvsjikrhxrfit.supabase.co/auth/v1/token?grant_type=password") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["email": cleanEmail, "password": password])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        switch httpResponse.statusCode {
        case 200:
            // Credentials verified by Supabase — extract access token and load the associate's profile row.
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let accessToken = json["access_token"] as? String {
                UserDefaults.standard.set(accessToken, forKey: "supabase_access_token_\(cleanEmail)")
                UserDefaults.standard.set(accessToken, forKey: "active_session_access_token")
            }
            guard let dbUser = try await fetchUserProfile(email: cleanEmail) else {
                throw AuthError.notInRecords
            }
            return dbUser
        case 400, 401:
            throw AuthError.invalidCredentials
        default:
            let message = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error_description"] as? String
            throw AuthError.server(message ?? "Sign-in failed (\(httpResponse.statusCode)). Please retry.")
        }
    }

    /// Fetches appointments for a specific sales associate ID from the Supabase database.
    func fetchAppointments(for salesAssociateID: String) async throws -> [DBAppointment] {
        guard let url = URL(string: "\(baseURL)/Appointment?salesAssociateID=eq.\(salesAssociateID)&select=*") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        guard httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        return try JSONDecoder().decode([DBAppointment].self, from: data)
    }

    /// Fetches shifts for a specific user ID from the Supabase database.
    func fetchShifts(for userID: String) async throws -> [DBShift] {
        guard let url = URL(string: "\(baseURL)/Shift?userID=eq.\(userID)&select=*") else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode([DBShift].self, from: data)
    }

    /// Fetches daily tasks for a specific user ID from the Supabase database.
    func fetchDailyTasks(for userID: String) async throws -> [DBDailyTask] {
        guard let url = URL(string: "\(baseURL)/DailyTask?userID=eq.\(userID)&select=*") else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode([DBDailyTask].self, from: data)
    }

    /// Updates the user's isActive status in the User table in Supabase.
    func updateUserActiveStatus(userId: String, isActive: Bool) async {
        let token = UserDefaults.standard.string(forKey: "active_session_access_token") ?? anonKey
        
        // 1. Try calling the RPC function first
        if let rpcURL = URL(string: "\(baseURL)/rpc/update_user_active_status") {
            var request = URLRequest(url: rpcURL)
            request.httpMethod = "POST"
            request.setValue(anonKey, forHTTPHeaderField: "apikey")
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let body: [String: Any] = [
                "user_id": userId,
                "is_active": isActive
            ]
            
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
                let (_, response) = try await URLSession.shared.data(for: request)
                if let httpResponse = response as? HTTPURLResponse {
                    print("isActive status update via RPC response: \(httpResponse.statusCode)")
                    if httpResponse.statusCode == 200 || httpResponse.statusCode == 204 {
                        return // Success!
                    }
                }
            } catch {
                print("Failed to update user active status via RPC: \(error)")
            }
        }
        
        // 2. Fallback to direct PATCH if the RPC fails or doesn't exist
        guard let url = URL(string: "\(baseURL)/User?id=eq.\(userId)") else {
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["isActive": isActive]
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: body)
            request.httpBody = jsonData
            
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                print("isActive status update via PATCH response: \(httpResponse.statusCode)")
            }
        } catch {
            print("Failed to update user isActive status in DB: \(error)")
        }
    }

    /// Updates a daily task's completion status in Supabase.
    func updateDailyTaskStatus(taskId: String, isCompleted: Bool) async {
        guard let url = URL(string: "\(baseURL)/DailyTask?id=eq.\(taskId)") else {
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        
        let token = UserDefaults.standard.string(forKey: "active_session_access_token") ?? anonKey
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["isCompleted": isCompleted]
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: body)
            request.httpBody = jsonData
            
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                print("DailyTask status update response status: \(httpResponse.statusCode)")
            }
        } catch {
            print("Failed to update daily task status in DB: \(error)")
        }
    }

    /// Updates an appointment's status in Supabase.
    func updateAppointmentStatus(appointmentId: String, status: String) async {
        let token = UserDefaults.standard.string(forKey: "active_session_access_token") ?? anonKey
        
        // 1. Try calling the RPC function first
        if let rpcURL = URL(string: "\(baseURL)/rpc/update_appointment_status") {
            var request = URLRequest(url: rpcURL)
            request.httpMethod = "POST"
            request.setValue(anonKey, forHTTPHeaderField: "apikey")
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let body: [String: Any] = [
                "appointment_id": appointmentId,
                "new_status": status
            ]
            
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
                let (_, response) = try await URLSession.shared.data(for: request)
                if let httpResponse = response as? HTTPURLResponse {
                    print("Appointment status update via RPC response: \(httpResponse.statusCode)")
                    if httpResponse.statusCode == 200 || httpResponse.statusCode == 204 {
                        return // Success!
                    }
                }
            } catch {
                print("Failed to update appointment status via RPC: \(error)")
            }
        }
        
        // 2. Fallback to direct PATCH
        guard let url = URL(string: "\(baseURL)/Appointment?id=eq.\(appointmentId)") else {
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["status": status]
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: body)
            request.httpBody = jsonData
            
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                print("Appointment status update via PATCH response: \(httpResponse.statusCode)")
            }
        } catch {
            print("Failed to update appointment status via PATCH: \(error)")
        }
    }

    /// Fetches all sales for a particular associate.
    func fetchSales(for associateID: String) async throws -> [DBSale] {
        guard let url = URL(string: "\(baseURL)/Sales?salesAssociateID=eq.\(associateID)&select=*") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        return try JSONDecoder().decode([DBSale].self, from: data)
    }
    
    /// Fetches the sales target for a particular associate.
    func fetchAssociateSalesTarget(for associateID: String) async throws -> DBAssociateSalesTarget? {
        guard let url = URL(string: "\(baseURL)/AssociateSalesTarget?assignedToID=eq.\(associateID)&select=*") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        let targets = try JSONDecoder().decode([DBAssociateSalesTarget].self, from: data)
        return targets.first
    }
    
    /// Calculates the weekly sales summary and weekday bars from associate sales.
    func calculateWeeklySalesSummary(sales: [DBSale]) -> WeeklySalesSummary {
        let daysOfWeek = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        var dailyTotals: [String: Double] = [:]
        for d in daysOfWeek {
            dailyTotals[d] = 0.0
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        let calendar = Calendar.current
        
        for sale in sales {
            if let date = formatter.date(from: sale.salesDate) {
                let weekday = calendar.component(.weekday, from: date)
                let dayName: String
                switch weekday {
                case 1: dayName = "Sun"
                case 2: dayName = "Mon"
                case 3: dayName = "Tue"
                case 4: dayName = "Wed"
                case 5: dayName = "Thu"
                case 6: dayName = "Fri"
                case 7: dayName = "Sat"
                default: dayName = "Mon"
                }
                dailyTotals[dayName, default: 0.0] += sale.totalAmount
            }
        }
        
        let totalSum = sales.reduce(0.0) { $0 + $1.totalAmount }
        let totalStr = totalSum >= 100000.0 ? String(format: "Rs. %.1fL", totalSum / 100000.0) : String(format: "Rs. %.0f", totalSum)
        
        var bestDayName = "Mon"
        var maxAmount = 0.0
        for (day, amt) in dailyTotals {
            if amt > maxAmount {
                maxAmount = amt
                bestDayName = day
            }
        }
        
        var dailySalesList: [DailySales] = []
        for d in daysOfWeek {
            let amt = dailyTotals[d] ?? 0.0
            let amtStr: String
            if amt >= 100000.0 {
                amtStr = String(format: "%.1fL", amt / 100000.0)
            } else if amt >= 1000.0 {
                amtStr = String(format: "%.0fk", amt / 1000.0)
            } else {
                amtStr = String(format: "%.0f", amt)
            }
            
            let progress = maxAmount > 0 ? (amt / maxAmount) : 0.0
            dailySalesList.append(DailySales(
                day: d,
                amount: amtStr,
                progress: progress,
                isBest: d == bestDayName && maxAmount > 0
            ))
        }
        
        return WeeklySalesSummary(
            total: totalStr,
            change: "+15%",
            comparison: "vs last week",
            bestDay: bestDayName,
            bestDayLabel: "Best sales day",
            days: dailySalesList
        )
    }

    /// Resets the user's password in Supabase Auth using the access token.
    func updatePassword(email: String, newPassword: String, accessToken: String) async throws {
        guard let url = URL(string: "https://zfengirsvsjikrhxrfit.supabase.co/auth/v1/user") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["password": newPassword]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        guard httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
    }

    /// Fetches all products from the Supabase Product table.
    func fetchDBProducts() async throws -> [DBProduct] {
        guard let url = URL(string: "\(baseURL)/Product?select=*") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        return try JSONDecoder().decode([DBProduct].self, from: data)
    }
}

struct DBAppointment: Codable, Identifiable {
    let id: String
    let storeID: String
    let customerID: String
    let salesAssociateID: String?
    let date: String
    let type: String
    var status: String
    let preferences: String?
    let createdAt: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case storeID
        case customerID
        case salesAssociateID
        case date
        case type
        case status
        case preferences
        case createdAt = "created_at"
    }

    var displayType: String {
        let lower = type.lowercased()
        // Needles must be lowercase — `lower` is already lowercased, so
        // "videoConsultation" (capital C) never matched and the video call
        // affordance stayed hidden.
        if lower.contains("video") || lower.contains("virtual") || lower.contains("online") {
            return "videoConsultation"
        } else if lower.contains("walk") || lower.contains("personal") || lower.contains("viewing") || lower.contains("alteration") {
            return "walk in"
        }
        return type
    }

    var isVideo: Bool {
        let lower = type.lowercased()
        return lower.contains("video") || lower.contains("virtual") || lower.contains("online")
    }

    /// The appointment start time parsed from the stored ISO date string.
    var startDate: Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = formatter.date(from: date) { return d }

        let altFormatter = ISO8601DateFormatter()
        altFormatter.formatOptions = [.withInternetDateTime]
        if let d = altFormatter.date(from: date) { return d }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
        return dateFormatter.date(from: date)
    }

    /// Minutes from now until the appointment starts (negative once it has begun).
    var minutesUntilStart: Double? {
        guard let startDate else { return nil }
        return startDate.timeIntervalSinceNow / 60
    }

    /// True when the appointment is within the 15-minute reminder window.
    var isWithinReminderWindow: Bool {
        guard let mins = minutesUntilStart else { return false }
        return mins >= -1 && mins <= 15
    }

    var parsedDateTime: (date: String, time: String) {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        var dateObj = formatter.date(from: date)
        if dateObj == nil {
            let altFormatter = ISO8601DateFormatter()
            altFormatter.formatOptions = [.withInternetDateTime]
            dateObj = altFormatter.date(from: date)
        }
        
        if dateObj == nil {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
            dateObj = dateFormatter.date(from: date)
        }
        
        guard let dateObj = dateObj else {
            return (date, "")
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateStyle = .none
        timeFormatter.timeStyle = .short
        
        return (dateFormatter.string(from: dateObj), timeFormatter.string(from: dateObj))
    }
}


enum AuthError: LocalizedError {
    case invalidCredentials
    case notInRecords
    case server(String)

    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Invalid email or password. Please try again."
        case .notInRecords:
            return "Signed in, but no associate profile was found in boutique records."
        case .server(let message):
            return message
        }
    }
}

struct DBUser: Codable {
    let id: String
    let firstName: String?
    let lastName: String?
    let email: String?
    let phoneNumber: String?
    let userRole: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case firstName = "First Name"
        case lastName = "Last Name"
        case email = "Email"
        case phoneNumber = "Phone Number"
        case userRole = "User Role"
    }
}

struct DBShift: Codable, Identifiable {
    let id: String
    let userID: String
    let storeID: String
    let shiftType: String
}

struct DBDailyTask: Codable, Identifiable {
    let id: String
    let userID: String
    let date: String
    let title: String
    var isCompleted: Bool
}

struct DBAssociateSalesTarget: Codable {
    let id: String
    let storeID: String
    let assignedToID: String
    let periodStartDate: String
    let periodEndDate: String
    let targetAmount: Double
}

struct DBSale: Codable {
    let id: String
    let customerID: String
    let salesAssociateID: String?
    let storeID: String
    let salesDate: String
    let currency: String
    let preTaxAmount: Double
    let taxAmount: Double
    let totalAmount: Double
    
    enum CodingKeys: String, CodingKey {
        case id
        case customerID
        case salesAssociateID
        case storeID
        case salesDate
        case currency = "Currency"
        case preTaxAmount
        case taxAmount
        case totalAmount
    }
}

struct DBProduct: Codable {
    let id: String
    let sku: String?
    let name: String
    let brand: String?
    let category: String?
    let barcode: String?
    let basePrice: Double?
    let isActive: Bool?
    let imageUrl: String?
    let updatedat: String?
    let createdat: String?
    let currentStock: Int?
    let reorderThreshold: Int?
    
    enum CodingKeys: String, CodingKey {
        case id
        case sku
        case name
        case brand
        case category
        case barcode
        case basePrice
        case isActive
        case imageUrl = "image_url"
        case updatedat
        case createdat
        case currentStock = "current_stock"
        case reorderThreshold = "reorder_threshold"
    }
}

