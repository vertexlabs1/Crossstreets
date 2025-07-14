import SwiftUI

struct SettingsRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let iconColor: Color
    var isActionable: Bool = false
    var action: () -> Void = {}
    
    var body: some View {
        Button(action: {
            if isActionable {
                action()
                HapticManager.lightImpact()
            }
        }) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(iconColor)
                    .frame(width: 24, height: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isActionable {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color(.systemGray6)))
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!isActionable)
    }
}

#Preview {
    SettingsRow(icon: "building.fill", title: "Garage Detection", subtitle: "Automatically detects parking garages and structures", iconColor: .purple)
}
