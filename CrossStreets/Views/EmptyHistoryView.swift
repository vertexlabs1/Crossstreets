import SwiftUI

struct EmptyHistoryView: View {
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "clock.circle")
                    .font(.system(size: 50))
                    .foregroundColor(.secondary)
            }
            
            Text("No recent parking")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.secondary)
            
            Text("Your parking history will appear here")
                .font(.system(size: 15))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }
}

#Preview {
    EmptyHistoryView()
}
