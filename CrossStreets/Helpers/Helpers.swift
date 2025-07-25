import UIKit

class HapticManager {
    static func lightImpact() {
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
    }
    
    static func mediumImpact() {
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
    }
    
    static func heavyImpact() {
        let impact = UIImpactFeedbackGenerator(style: .heavy)
        impact.impactOccurred()
    }
}

class DateHelper {
    static func timeAgo(from date: Date) -> String {
        let now = Date()
        let timeInterval = now.timeIntervalSince(date)
        
        let minutes = Int(timeInterval / 60)
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        
        if hours > 0 {
            if remainingMinutes > 0 {
                return "\(hours) hour\(hours == 1 ? "" : "s"), \(remainingMinutes) minute\(remainingMinutes == 1 ? "" : "s") ago"
            } else {
                return "\(hours) hour\(hours == 1 ? "" : "s") ago"
            }
        } else {
            return "\(minutes) minute\(minutes == 1 ? "" : "s") ago"
        }
    }
}
