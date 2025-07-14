import SwiftUI

struct BottomCard: View {
    @ObservedObject var locationManager: LocationManager
    @Binding var showingFloorPicker: Bool
    @Binding var detectedGarageName: String?
    @Binding var isDetectingGarage: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 2.5)
                    .fill(Color.gray.opacity(0.15))
                    .frame(width: 32, height: 4)
                RoundedRectangle(cornerRadius: 2.5)
                    .fill(Color.gray.opacity(0.08))
                    .frame(width: 20, height: 2)
            }
            .padding(.top, 6)
            .padding(.bottom, 14)
            
            Group {
                if locationManager.parkedLocation != nil {
                    ParkedStateView(
                        locationManager: locationManager,
                        showingFloorPicker: $showingFloorPicker,
                        detectedGarageName: $detectedGarageName
                    )
                } else {
                    NotParkedStateView(
                        locationManager: locationManager,
                        isDetectingGarage: $isDetectingGarage,
                        detectedGarageName: $detectedGarageName,
                        showingFloorPicker: $showingFloorPicker
                    )
                }
            }
        }
    }
}

#Preview {
    BottomCard(locationManager: LocationManager(), showingFloorPicker: .constant(false), detectedGarageName: .constant(nil), isDetectingGarage: .constant(false))
}
