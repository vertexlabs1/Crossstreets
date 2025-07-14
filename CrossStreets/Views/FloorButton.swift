import SwiftUI

struct FloorButton: View {
    let floor: String
    let isSelected: Bool
    let isEstimated: Bool
    var isCompact: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(floor)
                .font(.system(size: isCompact ? 13 : 15, weight: .semibold))
                .foregroundColor(isSelected ? .white : .black)
                .frame(width: isCompact ? 48 : 64, height: isCompact ? 42 : 54)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isSelected ? Color.blue : (isEstimated ? Color.blue.opacity(0.2) : Color.white))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(isSelected ? Color.clear : Color.blue.opacity(0.3), lineWidth: 1.5)
                        )
                        .shadow(color: .black.opacity(0.08), radius: isSelected ? 8 : 4, y: isSelected ? 4 : 2)
                )
        }
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

#Preview {
    FloorButton(floor: "F1", isSelected: false, isEstimated: true, action: {})
}
