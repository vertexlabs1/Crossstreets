import SwiftUI

struct HistoryView: View {
    @ObservedObject var locationManager: LocationManager
    @Binding var selectedTab: Int
    
    var body: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2.5)
                .fill(Color.gray.opacity(0.15))
                .frame(width: 32, height: 4)
                .padding(.top, 6)
                .padding(.bottom, 14)
            
            VStack(alignment: .leading, spacing: 16) {
                Text("RECENT PARKING")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                    .tracking(0.5)
                    .padding(.horizontal, 4)
                
                if locationManager.parkedLocation != nil {
                    CurrentParkingView(locationManager: locationManager)
                } else {
                    EmptyHistoryView()
                }
                
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text("Swipe down to return to parking")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary.opacity(0.7))
                        Image(systemName: "arrow.up")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary.opacity(0.5))
                    }
                }
                .padding(.top, 40)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 10)
            
            Spacer()
        }
    }
}

#Preview {
    HistoryView(locationManager: LocationManager(), selectedTab: .constant(1))
}
