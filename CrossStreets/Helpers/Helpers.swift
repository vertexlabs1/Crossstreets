import UIKit

class HapticManager {
    private static let lightGenerator = UIImpactFeedbackGenerator(style: .light)
    private static let mediumGenerator = UIImpactFeedbackGenerator(style: .medium)
    private static let heavyGenerator = UIImpactFeedbackGenerator(style: .heavy)
    
    static func lightImpact() {
        lightGenerator.impactOccurred()
    }
    
    static func mediumImpact() {
        mediumGenerator.impactOccurred()
    }
    
    static func heavyImpact() {
        heavyGenerator.impactOccurred()
    }
}

class DateHelper {
    static func timeAgo(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
