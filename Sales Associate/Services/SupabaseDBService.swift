import Foundation
import UIKit

class SupabaseDBService {
    static let shared = SupabaseDBService()
    
    private let baseURL = "https://zfengirsvsjikrhxrfit.supabase.co/rest/v1"
    private let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpmZW5naXJzdnNqaWtyaHhyZml0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODI0MTg5NTIsImV4cCI6MjA5Nzk5NDk1Mn0.rk57GzYVJDkHtEH649eXekzqox0s3O3nH3u8f5KHY5M"

    /// The boutique this app sells for. `Sales`/`SalesItem` rows are written against
    /// it, so it must be a real row in the `Store` table (verified) — it is the same
    /// store the `StoreInventory` rows belong to. The `Sales.storeID` column default
    /// points at a stale id, so this must always be sent explicitly.
    private let defaultStoreID = "11111111-1111-1111-1111-111111111111"
    
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

    /// Submits a new exception record to Supabase ExceptionRecord table.
    func submitExceptionRecord(
        productID: String,
        storeID: String,
        exceptionType: String,
        reportedBy: String,
        description: String?,
        varianceInQuantity: Int? = nil,
        damagedImageURL: String
    ) async throws {
        guard let url = URL(string: "\(baseURL)/ExceptionRecord") else {
            throw URLError(.badURL)
        }
        
        let record = DBExceptionRecordInsert(
            productID: productID,
            storeID: storeID,
            exceptionType: exceptionType,
            reportedBy: reportedBy,
            description: description,
            status: "pending",
            varianceInQuantity: varianceInQuantity,
            damagedImageURL: damagedImageURL
        )
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(record)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        if !(200...299).contains(httpResponse.statusCode) {
            let bodyString = String(data: data, encoding: .utf8) ?? ""
            print("Submit Exception Error response (\(httpResponse.statusCode)): \(bodyString)")
            throw URLError(.badServerResponse)
        }
    }

    /// Uploads an image to Supabase Storage bucket and returns the file path.
    func uploadImage(_ image: UIImage, toBucket bucket: String, fileName: String) async throws -> String {
        guard let url = URL(string: "https://zfengirsvsjikrhxrfit.supabase.co/storage/v1/object/\(bucket)/\(fileName)") else {
            throw URLError(.badURL)
        }
        
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw NSError(domain: "ImageConversionError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to JPEG data"])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        request.httpBody = imageData
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        if !(200...299).contains(httpResponse.statusCode) {
            let bodyString = String(data: data, encoding: .utf8) ?? ""
            print("Upload Image Error response (\(httpResponse.statusCode)): \(bodyString)")
            throw URLError(.badServerResponse)
        }
        
        return "\(bucket)/\(fileName)"
    }

    /// Submits a stock request to the SalesAssociateStockRequest table.
    func submitStockRequest(
        productID: String,
        storeID: String,
        reportedBy: String,
        quantity: Int,
        urgency: String
    ) async throws {
        guard let url = URL(string: "\(baseURL)/SalesAssociateStockRequest") else {
            throw URLError(.badURL)
        }
        
        let record = DBSalesAssociateStockRequestInsert(
            productID: productID,
            storeID: storeID,
            requestedBy: reportedBy,
            quantityRequested: quantity,
            urgency: urgency,
            status: "pending"
        )
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(record)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        if !(200...299).contains(httpResponse.statusCode) {
            let bodyString = String(data: data, encoding: .utf8) ?? ""
            print("Submit Stock Request Error response (\(httpResponse.statusCode)): \(bodyString)")
            throw URLError(.badServerResponse)
        }
    }

    /// Fetches exception records for a specific sales associate.
    func fetchExceptionRecords(for reportedBy: String) async throws -> [DBExceptionRecord] {
        guard let url = URL(string: "\(baseURL)/ExceptionRecord?reportedBy=eq.\(reportedBy)&select=*") else {
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
        
        return try JSONDecoder().decode([DBExceptionRecord].self, from: data)
    }

    /// Fetches stock requests for a specific sales associate.
    func fetchStockRequests(for reportedBy: String) async throws -> [DBSalesAssociateStockRequest] {
        guard let url = URL(string: "\(baseURL)/SalesAssociateStockRequest?requestedby=eq.\(reportedBy)&select=*") else {
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
        
        return try JSONDecoder().decode([DBSalesAssociateStockRequest].self, from: data)
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
    
    /// Calculates the weekly sales summary from associate sales: this week's daily
    /// bars + total, plus a REAL "vs last week" change computed by comparing this
    /// week's total against last week's total (Monday-anchored weeks).
    func calculateWeeklySalesSummary(sales: [DBSale]) -> WeeklySalesSummary {
        let daysOfWeek = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let calendar = Calendar.current

        // Monday-anchored week boundaries around today.
        let today = Date()
        let weekday = calendar.component(.weekday, from: today)     // 1=Sun … 7=Sat
        let daysFromMonday = (weekday + 5) % 7                       // Mon=0 … Sun=6
        let startOfThisWeek = calendar.startOfDay(
            for: calendar.date(byAdding: .day, value: -daysFromMonday, to: today) ?? today
        )
        let startOfLastWeek = calendar.date(byAdding: .day, value: -7, to: startOfThisWeek) ?? startOfThisWeek
        let startOfNextWeek = calendar.date(byAdding: .day, value: 7, to: startOfThisWeek) ?? startOfThisWeek

        func saleDate(_ sale: DBSale) -> Date? { formatter.date(from: sale.salesDate) }

        let thisWeekSales = sales.filter { sale in
            guard let d = saleDate(sale) else { return false }
            return d >= startOfThisWeek && d < startOfNextWeek
        }
        let lastWeekSales = sales.filter { sale in
            guard let d = saleDate(sale) else { return false }
            return d >= startOfLastWeek && d < startOfThisWeek
        }

        // This week's daily totals (Mon..Sun).
        var dailyTotals: [String: Double] = Dictionary(uniqueKeysWithValues: daysOfWeek.map { ($0, 0.0) })
        for sale in thisWeekSales {
            guard let date = saleDate(sale) else { continue }
            let dayName: String
            switch calendar.component(.weekday, from: date) {
            case 1: dayName = "Sun"
            case 2: dayName = "Mon"
            case 3: dayName = "Tue"
            case 4: dayName = "Wed"
            case 5: dayName = "Thu"
            case 6: dayName = "Fri"
            default: dayName = "Sat"
            }
            dailyTotals[dayName, default: 0.0] += sale.totalAmount
        }

        let thisWeekTotal = thisWeekSales.reduce(0.0) { $0 + $1.totalAmount }
        let lastWeekTotal = lastWeekSales.reduce(0.0) { $0 + $1.totalAmount }
        let totalStr = thisWeekTotal >= 100000.0
            ? String(format: "Rs. %.1fL", thisWeekTotal / 100000.0)
            : String(format: "Rs. %.0f", thisWeekTotal)

        // Real week-over-week change.
        let changeStr: String
        if lastWeekTotal > 0 {
            let pct = (thisWeekTotal - lastWeekTotal) / lastWeekTotal * 100
            changeStr = "\(pct >= 0 ? "+" : "")\(Int(pct.rounded()))%"
        } else {
            changeStr = thisWeekTotal > 0 ? "New" : "0%"
        }

        var bestDayName = "Mon"
        var maxAmount = 0.0
        for d in daysOfWeek {
            if let amt = dailyTotals[d], amt > maxAmount {
                maxAmount = amt
                bestDayName = d
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
            change: changeStr,
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

    /// Fetches on-hand stock rows from the `StoreInventory` table. Stock is
    /// sourced from here (`currentquantity`), keyed by `productid` (= Product.id),
    /// rather than the stale `Product.current_stock` column.
    func fetchStoreInventory() async throws -> [DBStoreInventory] {
        guard let url = URL(string: "\(baseURL)/StoreInventory?select=*") else {
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

        return try JSONDecoder().decode([DBStoreInventory].self, from: data)
    }

    /// Decrements on-hand stock in `StoreInventory` for a purchased product.
    /// Reads the current quantity for `productID` (= Product.id), then writes back
    /// `max(0, current - quantity)`. Called after a sale is finalized so database
    /// stock reflects what the client just bought.
    func decrementStoreInventory(productID: String, by quantity: Int) async {
        guard quantity > 0 else { return }
        // Use the anon key (RLS is disabled; anon has table grants — verified) so the
        // write never depends on a valid/unexpired user session token.
        let token = anonKey

        // 1) Read the current inventory row for this product.
        guard let getURL = URL(string: "\(baseURL)/StoreInventory?productid=eq.\(productID)&select=id,currentquantity") else {
            return
        }
        var getRequest = URLRequest(url: getURL)
        getRequest.httpMethod = "GET"
        getRequest.setValue(anonKey, forHTTPHeaderField: "apikey")
        getRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: getRequest)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
                  let rows = try JSONSerialization.jsonObject(with: data) as? [[String: Any]],
                  let row = rows.first,
                  let rowID = row["id"] as? String,
                  let current = row["currentquantity"] as? Int else {
                print("StoreInventory decrement skipped — no inventory row for \(productID)")
                return
            }

            let newQuantity = max(0, current - quantity)

            // 2) Write back the reduced quantity by row id.
            guard let patchURL = URL(string: "\(baseURL)/StoreInventory?id=eq.\(rowID)") else { return }
            var patchRequest = URLRequest(url: patchURL)
            patchRequest.httpMethod = "PATCH"
            patchRequest.setValue(anonKey, forHTTPHeaderField: "apikey")
            patchRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            patchRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            patchRequest.setValue("return=minimal", forHTTPHeaderField: "Prefer")
            patchRequest.httpBody = try JSONSerialization.data(withJSONObject: ["currentquantity": newQuantity])

            let (_, patchResponse) = try await URLSession.shared.data(for: patchRequest)
            if let patchHTTP = patchResponse as? HTTPURLResponse {
                print("StoreInventory decrement for \(productID): \(current) -> \(newQuantity) (HTTP \(patchHTTP.statusCode))")
            }
        } catch {
            print("Failed to decrement StoreInventory for \(productID): \(error)")
        }
    }

    /// One purchased product within a sale (amounts in rupees).
    struct SaleItemInput {
        let productID: String      // Product.id (uuid)
        let quantity: Int
        let unitPriceRupees: Double
        let subTotalRupees: Double
    }

    /// Records a finalized sale in Supabase: one `Sales` row (the payment totals)
    /// plus one `SalesItem` row per purchased product — a single sale may contain
    /// several products and quantities. Amounts are in rupees. Best-effort: logs and
    /// returns on failure, since stock is already decremented and the receipt shown.
    @discardableResult
    func recordSale(
        salesAssociateID: String,
        salesDate: String,
        saleTime: String,
        preTaxAmount: Double,
        taxAmount: Double,
        totalAmount: Double,
        items: [SaleItemInput]
    ) async -> String? {
        // Use the anon key (RLS is disabled; anon has table grants — verified) so the
        // write never depends on a valid/unexpired user session token.
        let token = anonKey

        // 1) Insert the Sales row and read back its generated id.
        guard let salesURL = URL(string: "\(baseURL)/Sales") else { return nil }
        var salesRequest = URLRequest(url: salesURL)
        salesRequest.httpMethod = "POST"
        salesRequest.setValue(anonKey, forHTTPHeaderField: "apikey")
        salesRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        salesRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        salesRequest.setValue("return=representation", forHTTPHeaderField: "Prefer")

        // customerID is omitted on purpose — the app's local client ids (e.g. "CL-3557")
        // are not the DB customer uuids, so the column default is used instead.
        let salesBody: [String: Any] = [
            "salesAssociateID": salesAssociateID,
            "storeID": defaultStoreID,
            "salesDate": salesDate,
            "Currency": "INR",
            "preTaxAmount": preTaxAmount,
            "taxAmount": taxAmount,
            "totalAmount": totalAmount
        ]

        do {
            salesRequest.httpBody = try JSONSerialization.data(withJSONObject: salesBody)
            let (data, response) = try await URLSession.shared.data(for: salesRequest)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 || httpResponse.statusCode == 201,
                  let rows = try JSONSerialization.jsonObject(with: data) as? [[String: Any]],
                  let saleID = rows.first?["id"] as? String else {
                print("Sales insert failed: \(String(data: data, encoding: .utf8) ?? "<no body>")")
                return nil
            }
            print("Sales recorded: \(saleID), total Rs.\(totalAmount)")

            // 2) Insert one SalesItem row per purchased product (batch). Each row
            //    carries the transaction time-of-day (HH:mm:ss) in the `time` column.
            let validItems = items.filter { !$0.productID.isEmpty && $0.quantity > 0 }
            guard !validItems.isEmpty, let itemsURL = URL(string: "\(baseURL)/SalesItem") else { return saleID }
            let itemBodies: [[String: Any]] = validItems.map { item in
                [
                    "saleID": saleID,
                    "productID": item.productID,
                    "quantity": item.quantity,
                    "unitPrice": item.unitPriceRupees,
                    "subTotal": item.subTotalRupees,
                    "time": saleTime
                ]
            }
            var itemsRequest = URLRequest(url: itemsURL)
            itemsRequest.httpMethod = "POST"
            itemsRequest.setValue(anonKey, forHTTPHeaderField: "apikey")
            itemsRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            itemsRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            itemsRequest.setValue("return=minimal", forHTTPHeaderField: "Prefer")
            itemsRequest.httpBody = try JSONSerialization.data(withJSONObject: itemBodies)

            let (itemsData, itemsResponse) = try await URLSession.shared.data(for: itemsRequest)
            if let itemsHTTP = itemsResponse as? HTTPURLResponse {
                print("SalesItem insert (\(validItems.count) items): HTTP \(itemsHTTP.statusCode)")
                if !(itemsHTTP.statusCode == 200 || itemsHTTP.statusCode == 201) {
                    print("SalesItem body: \(String(data: itemsData, encoding: .utf8) ?? "")")
                }
            }
            return saleID
        } catch {
            print("Failed to record sale: \(error)")
            return nil
        }
    }

    // MARK: - Receipt

    /// Records a receipt row (post-payment tax-invoice snapshot) linked to a `Sales`
    /// row via `saleID`. Amounts are in rupees; `time` is the transaction time-of-day
    /// (HH:mm:ss), matching `SalesItem.time`. Best-effort — logs and returns on
    /// failure since the on-screen receipt was already shown to the customer.
    func recordReceipt(
        saleID: String?,
        invoiceNumber: String?,
        salesAssociateID: String,
        paymentMethod: String,
        paymentReference: String?,
        preTaxAmount: Double,
        taxAmount: Double,
        totalAmount: Double,
        amountPaid: Double,
        itemCount: Int,
        receiptDate: String,
        time: String
    ) async {
        guard let url = URL(string: "\(baseURL)/receipt") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")

        // The receipt belongs to the same boutique the Sales row is written against.
        var body: [String: Any] = [
            "salesAssociateID": salesAssociateID,
            "storeID": defaultStoreID,
            "paymentMethod": paymentMethod,
            "preTaxAmount": preTaxAmount,
            "taxAmount": taxAmount,
            "totalAmount": totalAmount,
            "amountPaid": amountPaid,
            "Currency": "INR",
            "itemCount": itemCount,
            "receiptDate": receiptDate,
            "time": time
        ]
        if let saleID { body["saleID"] = saleID }
        if let invoiceNumber { body["invoiceNumber"] = invoiceNumber }
        if let paymentReference { body["paymentReference"] = paymentReference }

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse {
                print("Receipt insert: HTTP \(http.statusCode)")
                if !(200...299).contains(http.statusCode) {
                    print("Receipt body: \(String(data: data, encoding: .utf8) ?? "")")
                }
            }
        } catch {
            print("Failed to record receipt: \(error)")
        }
    }

    // MARK: - Planogram (store capture reports)

    /// The Storage bucket the store-capture PDFs are uploaded to. The anon key can
    /// write to the existing public "Product Images" bucket (verified) but cannot
    /// create new buckets, so planogram PDFs live under its "Planograms/" folder.
    /// Point these at a dedicated bucket once one is created in the Supabase dashboard.
    private var planogramBucket: String { "Product Images" }
    private var planogramFolder: String { "Planograms" }
    private var storageBaseURL: String { "https://zfengirsvsjikrhxrfit.supabase.co/storage/v1" }

    /// Uploads a generated store-capture PDF to Supabase Storage and records a row
    /// in the `planogram` table. The row stores the public PDF URL in `document_url`,
    /// the associate's id in `created_by`, and `status = pending` (awaiting review).
    /// Returns the public PDF URL. Throws on upload or insert failure.
    @discardableResult
    func submitPlanogramReport(pdfData: Data, title: String, createdBy: String) async throws -> String {
        let fileName = "planogram_\(Int(Date().timeIntervalSince1970))_\(UUID().uuidString.prefix(8)).pdf"
        let objectPath = "\(planogramFolder)/\(fileName)"
        let documentURL = try await uploadPlanogramPDF(pdfData, toObjectPath: objectPath)
        try await insertPlanogramRow(title: title, documentURL: documentURL, createdBy: createdBy)
        return documentURL
    }

    /// Uploads PDF bytes to `planogramBucket` at `objectPath` and returns the public URL.
    private func uploadPlanogramPDF(_ data: Data, toObjectPath objectPath: String) async throws -> String {
        // The bucket name contains a space ("Product Images"), so it must be percent
        // encoded; the object path keeps its "/" separator (urlPathAllowed retains it).
        let encodedBucket = planogramBucket.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? planogramBucket
        let encodedPath = objectPath.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? objectPath
        guard let url = URL(string: "\(storageBaseURL)/object/\(encodedBucket)/\(encodedPath)") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/pdf", forHTTPHeaderField: "Content-Type")
        // A plain INSERT (no x-upsert) is required: the anon role has an INSERT
        // policy on storage.objects but not the UPDATE one that upsert also needs.
        // The object path is unique (timestamp + uuid), so upsert is unnecessary.
        request.httpBody = data

        let (responseData, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let body = String(data: responseData, encoding: .utf8) ?? "<no body>"
            print("Planogram PDF upload failed: \(body)")
            throw URLError(.badServerResponse)
        }

        // Public URL for the object (the bucket serves objects publicly, like Product Images).
        return "\(storageBaseURL)/object/public/\(encodedBucket)/\(encodedPath)"
    }

    /// Inserts a row into the `planogram` table. `status` is the `RequestStatus`
    /// enum — new submissions are always "pending". `planogram_id` is generated by
    /// the database default, so it is not sent.
    private func insertPlanogramRow(title: String, documentURL: String, createdBy: String) async throws {
        guard let url = URL(string: "\(baseURL)/planogram") else { throw URLError(.badURL) }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")

        let body: [String: Any] = [
            "title": title,
            "document_url": documentURL,
            "created_by": createdBy,
            "status": "pending"
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (responseData, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let body = String(data: responseData, encoding: .utf8) ?? "<no body>"
            print("Planogram insert failed: \(body)")
            throw URLError(.badServerResponse)
        }
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

struct DBStoreInventory: Codable {
    let id: String
    let storeid: String
    let productid: String
    var currentquantity: Int
    let thresholdquantity: Int?
}

struct DBExceptionRecordInsert: Codable {
    let productID: String
    let storeID: String
    let exceptionType: String
    let reportedBy: String
    let description: String?
    let status: String
    let varianceInQuantity: Int?
    let damagedImageURL: String
    
    enum CodingKeys: String, CodingKey {
        case productID, storeID, exceptionType, reportedBy, description, status, varianceInQuantity
        case damagedImageURL = "damaged_image_url"
    }
}

struct DBExceptionRecord: Codable, Identifiable {
    let id: String
    let productID: String
    let storeID: String
    let exceptionType: String
    let reportedBy: String
    let description: String?
    let status: String
    let varianceInQuantity: Int?
    let damagedImageURL: String?
    let createdAt: String
    
    enum CodingKeys: String, CodingKey {
        case id, productID, storeID, exceptionType, reportedBy, description, status, varianceInQuantity
        case damagedImageURL = "damaged_image_url"
        case createdAt = "createdAt"
    }
}

struct DBSalesAssociateStockRequestInsert: Codable {
    let productID: String
    let storeID: String
    let requestedBy: String
    let quantityRequested: Int
    let urgency: String
    let status: String
    
    enum CodingKeys: String, CodingKey {
        case productID = "productid"
        case storeID = "storeid"
        case requestedBy = "requestedby"
        case quantityRequested = "quantityrequested"
        case urgency
        case status
    }
}

struct DBSalesAssociateStockRequest: Codable, Identifiable {
    let id: String
    let productID: String
    let storeID: String
    let requestedBy: String
    let quantityRequested: Int
    let urgency: String
    let status: String
    let createdAt: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case productID = "productid"
        case storeID = "storeid"
        case requestedBy = "requestedby"
        case quantityRequested = "quantityrequested"
        case urgency
        case status
        case createdAt = "createdat"
    }
}



