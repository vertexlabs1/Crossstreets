import SwiftUI

struct BottomCard: View {
    @ObservedObject var locationManager: LocationManager
    @Binding var showingFloorPicker: Bool
    @Binding var detectedGarageName: String?
    @State private var showingParkingDetails = false
    

    
    private var parkingDetailsSheet: some View {
        Group {
            if let parking = locationManager.parkedLocation {
                ParkingDetailsSheet(locationManager: locationManager, parking: parking)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(20)
            } else {
                EmptyView()
            }
        }
    }
    
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
        .contentShape(Rectangle()) // Make entire area tappable
        .gesture(
            DragGesture(minimumDistance: 20)
                .onEnded { value in
                    handleGestureEnd(value: value)
                }
        )
        .onTapGesture {
            handleTap()
        }
        .sheet(isPresented: $showingParkingDetails) {
            parkingDetailsSheet
        }
        // MARK: - Accessibility Support
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Parking details card")
        .accessibilityHint("Swipe up to view detailed parking information")
        .accessibilityAction(named: "View Details") {
            handleTap()
        }
    }
    
    private func handleGestureEnd(value: DragGesture.Value) {
        // Only proceed if there's a parked location
        guard locationManager.parkedLocation != nil else {
            print("❌ Cannot show parking details via gesture - no parked location")
            return
        }
        
        // Validate translation values to prevent NaN
        let translationHeight = value.translation.height.isFinite ? value.translation.height : 0
        let velocity = value.velocity.height
        let velocityHeight = velocity.isFinite ? velocity : 0
        
        // Use fixed thresholds that work well for swipe gestures
        let dismissThreshold: CGFloat = -50 // 50 points upward swipe
        let velocityThreshold: CGFloat = -800 // Fast upward swipe
        
        // Use screen-relative thresholds and Apple's recommended velocity
        let shouldOpen = translationHeight < dismissThreshold || velocityHeight < velocityThreshold
        
        if shouldOpen {
            // Strategic haptic feedback for gesture completion
            HapticManager.mediumImpact()
            
            // Animate with consistent timing
            withAnimation(.easeInOut(duration: 0.3)) {
                showingParkingDetails = true
            }
        }
    }
    
    private func handleTap() {
        guard locationManager.parkedLocation != nil else {
            print("❌ Cannot show parking details - no parked location")
            return
        }
        
        // Light haptic feedback for tap
        HapticManager.lightImpact()
        
        // Animate with consistent timing
        withAnimation(.easeInOut(duration: 0.3)) {
            showingParkingDetails = true
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
