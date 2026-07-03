import Foundation

/// Local write-through cache for client profiles. Client data is loaded only from
/// Supabase (see `syncProfilesWithSupabase`); this store is never read as a source,
/// it just persists the latest Supabase-sourced profiles to disk. No dummy/sample
/// data is ever seeded.
enum ClientProfileJSONStore {
    private static let fileName = "client-profiles.json"

    static func saveProfiles(_ profiles: [ClientProfile]) {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(profiles)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            #if DEBUG
            print("Failed to save client profiles JSON: \(error)")
            #endif
        }
    }

    static var fileURL: URL {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsURL.appendingPathComponent(fileName)
    }
}
