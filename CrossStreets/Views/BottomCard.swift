import SwiftUI

struct BottomCard: View {
    @ObservedObject var locationManager: LocationManager
    @Binding var showingFloorPicker: Bool
    @Binding var detectedGarageName: String?
    @State private var showingParkingDetails = false
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    
    private let swipeThreshold: CGFloat = 30 // Reduced threshold for easier triggering
    private let maxDragOffset: CGFloat = 80
    
    var body: some View {
        VStack(spacing: 0) {
            // Drag indicator with improved gesture area
            VStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 2.5)
                    .fill(Color.gray.opacity(0.15))
                    .frame(width: 32, height: 4)
                RoundedRectangle(cornerRadius: 2.5)
                    .fill(Color.gray.opacity(0.08))
                    .frame(width: 20, height: 2)
            }
            .padding(.top, 4)
            .padding(.bottom, 10)
            .padding(.horizontal, 20) // Add horizontal padding for larger touch area
            .offset(y: dragOffset)
            .contentShape(Rectangle()) // Make entire area tappable
            .gesture(
                DragGesture(minimumDistance: 5) // Require minimum distance to start
                    .onChanged { value in
                        isDragging = true
                        // Only allow upward drag
                        let newOffset = min(0, -value.translation.height)
                        dragOffset = max(-maxDragOffset, newOffset)
                        
                        // Add haptic feedback when crossing threshold
                        if abs(dragOffset) > swipeThreshold && !showingParkingDetails {
                            HapticManager.lightImpact()
                        }
                    }
                    .onEnded { value in
                        isDragging = false
                        
                        // Check if swipe threshold was met
                        if abs(dragOffset) > swipeThreshold {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                showingParkingDetails = true
                                dragOffset = 0
                            }
                            HapticManager.mediumImpact()
                        } else {
                            // Reset position if threshold not met
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                dragOffset = 0
                            }
                        }
                    }
            )
            .onTapGesture {
                // Add haptic feedback for tap
                HapticManager.lightImpact()
                showingParkingDetails = true
            }
            
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
        .sheet(isPresented: $showingParkingDetails) {
            if let parking = locationManager.parkedLocation {
                ParkingDetailsSheet(locationManager: locationManager, parking: parking)
            }
        }
    }
}

#Preview {
    BottomCard(locationManager: LocationManager(), showingFloorPicker: .constant(false), detectedGarageName: .constant(nil))
}
