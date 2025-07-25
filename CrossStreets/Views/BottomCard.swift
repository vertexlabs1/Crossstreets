import SwiftUI

struct BottomCard: View {
    @ObservedObject var locationManager: LocationManager
    @Binding var showingFloorPicker: Bool
    @Binding var detectedGarageName: String?
    @State private var showingParkingDetails = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Native drag indicator
            RoundedRectangle(cornerRadius: 2.5)
                .fill(Color.gray.opacity(0.3))
                .frame(width: 36, height: 5)
                .padding(.top, 8)
                .padding(.bottom, 4)
            
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
                        detectedGarageName: $detectedGarageName,
                        showingFloorPicker: $showingFloorPicker
                    )
                }
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(20, corners: [UIRectCorner.topLeft, UIRectCorner.topRight])
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: -5)
        .contentShape(Rectangle()) // Make entire area tappable
        .gesture(
            DragGesture(minimumDistance: 20) // Require minimum distance to start
                .onEnded { value in
                    handleGestureEnd(value: value)
                }
        )
        .onTapGesture {
            handleTap()
        }
        .sheet(isPresented: $showingParkingDetails) {
            ParkingDetailsSheetView(locationManager: locationManager)
        }
    }
    
    private func handleGestureEnd(value: DragGesture.Value) {
        // Only proceed if there's a parked location
        if locationManager.parkedLocation != nil {
            // Validate translation values to prevent NaN
            let translationHeight = value.translation.height.isFinite ? value.translation.height : 0
            let velocity = value.predictedEndTranslation.height - value.translation.height
            let velocityHeight = velocity.isFinite ? velocity : 0
            
            // Open if swiped up with sufficient distance or velocity
            if translationHeight < -40 || velocityHeight < -150 {
                showingParkingDetails = true
            }
        } else {
            print("❌ Cannot show parking details via gesture - no parked location")
        }
    }
    
    private func handleTap() {
        if locationManager.parkedLocation != nil {
            showingParkingDetails = true
        } else {
            print("❌ Cannot show parking details - no parked location")
        }
    }
}

struct ParkingDetailsSheetView: View {
    @ObservedObject var locationManager: LocationManager
    
    var body: some View {
        if let parking = locationManager.parkedLocation {
            print("📱 Presenting ParkingDetailsSheet with parking: \(parking)")
            ParkingDetailsSheet(locationManager: locationManager, parking: parking)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(20)
        } else {
            print("❌ ParkingDetailsSheet: No parked location available")
            EmptyView()
        }
    }
}

#Preview {
    BottomCard(
        locationManager: LocationManager(),
        showingFloorPicker: .constant(false),
        detectedGarageName: .constant(nil)
    )
}
