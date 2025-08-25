import SwiftUI

struct TabBarView: View {
    @Binding var selectedTab: Int
    @Binding var showHistorySheet: Bool
    @Binding var showSettingsSheet: Bool
    
    var body: some View {
        HStack(spacing: 0) {
            Button(action: {
                selectedTab = 0
                HapticManager.lightImpact()
            }) {
                VStack(spacing: 4) {
                    Image(systemName: selectedTab == 0 ? "car.circle.fill" : "car.circle")
                        .font(.system(size: 22))
                    Text("PARKING")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(0.5)
                }
                .foregroundColor(selectedTab == 0 ? .blue : .gray)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            
            Button(action: {
                selectedTab = 1
                showHistorySheet = true
                HapticManager.lightImpact()
            }) {
                VStack(spacing: 4) {
                    Image(systemName: selectedTab == 1 ? "clock.circle.fill" : "clock.circle")
                        .font(.system(size: 22))
                    Text("RECENT")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(0.5)
                }
                .foregroundColor(selectedTab == 1 ? .blue : .gray)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            
            Button(action: {
                selectedTab = 2
                showSettingsSheet = true
                HapticManager.lightImpact()
            }) {
                VStack(spacing: 4) {
                    Image(systemName: selectedTab == 2 ? "gearshape.circle.fill" : "gearshape.circle")
                        .font(.system(size: 22))
                    Text("SETTINGS")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(0.5)
                }
                .foregroundColor(selectedTab == 2 ? .blue : .gray)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.top, 10)
        .padding(.bottom, 20)
    }
}

#Preview {
    TabBarView(
        selectedTab: .constant(0),
        showHistorySheet: .constant(false),
        showSettingsSheet: .constant(false)
    )
}
