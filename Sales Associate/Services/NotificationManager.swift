import Foundation
import UserNotifications

class NotificationManager {
    static let shared = NotificationManager()
    
    private init() {}
    
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("Notification permission granted.")
            } else if let error = error {
                print("Notification permission error: \(error)")
            }
        }
    }
    
    func scheduleAppointmentNotifications(appointments: [DBAppointment], clientProfiles: [ClientProfile]) {
        // Clear old pending notifications to prevent duplicates
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        
        // Also schedule a test notification for 5 seconds from now for demo purposes
        scheduleTestNotification()
        
        let now = Date()
        
        for appt in appointments {
            let clientName = clientProfiles.first(where: { $0.id == appt.customerID })?.name ?? appt.customerID
            
            // Parse date
            guard let apptDate = parseDate(appt.date) else { continue }
            
            // Schedule notification 15 minutes before the appointment
            let triggerTime = apptDate.addingTimeInterval(-900) // 15 minutes before

            if triggerTime > now {
                let content = UNMutableNotificationContent()
                content.title = "Upcoming Appointment"
                content.body = "Your appointment with \(clientName) starts in 15 minutes."
                content.sound = .default
                
                let calendar = Calendar.current
                let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: triggerTime)
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                
                let request = UNNotificationRequest(identifier: "appt-\(appt.id)", content: content, trigger: trigger)
                
                UNUserNotificationCenter.current().add(request) { error in
                    if let error = error {
                        print("Failed to schedule notification: \(error)")
                    }
                }
            } else if apptDate > now {
                // If it's starting in less than 15 minutes, trigger a notification in 5 seconds
                let content = UNMutableNotificationContent()
                content.title = "Upcoming Appointment"
                content.body = "Your appointment with \(clientName) is starting soon."
                content.sound = .default
                
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
                let request = UNNotificationRequest(identifier: "appt-soon-\(appt.id)", content: content, trigger: trigger)
                
                UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
            }
        }
    }
    
    func scheduleTestNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Upcoming Appointment Alert"
        content.body = "Your appointment with Aisha Kapoor starts in 15 minutes."
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let request = UNNotificationRequest(identifier: "test-notification", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule test notification: \(error)")
            }
        }
    }
    
    private func parseDate(_ dateString: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = formatter.date(from: dateString) { return d }
        
        let altFormatter = ISO8601DateFormatter()
        altFormatter.formatOptions = [.withInternetDateTime]
        if let d = altFormatter.date(from: dateString) { return d }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
        return dateFormatter.date(from: dateString)
    }
}
