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
            // Credentials verified by Supabase — load the associate's profile row.
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

    /// Fetches all appointments from the Supabase database.
    func fetchAppointments() async throws -> [DBAppointment] {
        guard let url = URL(string: "\(baseURL)/Appointment?select=*") else {
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
}

struct DBAppointment: Codable, Identifiable {
    let id: String
    let storeID: String
    let customerID: String
    let salesAssociateID: String?
    let date: String
    let type: String
    let status: String
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

