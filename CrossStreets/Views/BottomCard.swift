import SwiftUI

struct BottomCard: View {
    @ObservedObject var locationManager: LocationManager
    @Binding var showingFloorPicker: Bool
    @Binding var detectedGarageName: String?
    @State private var showingParkingDetails = false
    
    // MARK: - Gesture Configuration
    private var gestureConfiguration: GestureConfiguration {
        let screenHeight = UIScreen.main.bounds.height
        return GestureConfiguration(
            minimumDistance: 20,
            dismissThreshold: screenHeight * 0.08, // 8% of screen height
            velocityThreshold: 800, // Apple's recommended velocity threshold
            animationDuration: 0.3 // Consistent with system animations
        )
    }
    
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
                .padding(.top, 16)
                .padding(.bottom, 12)
            
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
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .background(Color(.systemBackground))
        .cornerRadius(20, corners: [UIRectCorner.topLeft, UIRectCorner.topRight])
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: -5)
        .contentShape(Rectangle()) // Make entire area tappable
        .gesture(
            DragGesture(minimumDistance: gestureConfiguration.minimumDistance)
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
        
        // Use screen-relative thresholds and Apple's recommended velocity
        let shouldOpen = translationHeight < -gestureConfiguration.dismissThreshold || 
                        velocityHeight < -gestureConfiguration.velocityThreshold
        
        if shouldOpen {
            // Strategic haptic feedback for gesture completion
            HapticManager.mediumImpact()
            
            // Animate with consistent timing
            withAnimation(.easeInOut(duration: gestureConfiguration.animationDuration)) {
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
        withAnimation(.easeInOut(duration: gestureConfiguration.animationDuration)) {
            showingParkingDetails = true
        }
    }
}

// MARK: - Gesture Configuration
private struct GestureConfiguration {
    let minimumDistance: CGFloat
    let dismissThreshold: CGFloat
    let velocityThreshold: CGFloat
    let animationDuration: Double
}

#Preview {
    BottomCard(
        locationManager: LocationManager(),
        showingFloorPicker: .constant(false),
        detectedGarageName: .constant(nil)
    )
}
