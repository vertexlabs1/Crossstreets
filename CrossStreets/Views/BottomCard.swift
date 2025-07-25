import SwiftUI

struct BottomCard: View {
    @ObservedObject var locationManager: LocationManager
    @Binding var showingFloorPicker: Bool
    @Binding var detectedGarageName: String?
    @State private var showingParkingDetails = false
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    
    private let swipeThreshold: CGFloat = 50
    private let maxDragOffset: CGFloat = 100
    
    var body: some View {
        VStack(spacing: 0) {
            // Drag indicator
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
            .padding(.horizontal, 20)
            
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
        .offset(y: dragOffset)
        .gesture(
            DragGesture(minimumDistance: 5)
                .onChanged { value in
                    isDragging = true
                    
                    // Only allow upward drag with resistance
                    let translation = value.translation.height
                    let resistance: CGFloat = 0.6
                    
                    if translation < 0 {
                        // Upward drag - apply resistance
                        dragOffset = translation * resistance
                    } else {
                        // Downward drag - allow with less resistance
                        dragOffset = translation * 0.3
                    }
                    
                    // Limit the drag range
                    dragOffset = max(-maxDragOffset, min(maxDragOffset, dragOffset))
                    
                    // Haptic feedback when crossing threshold
                    if abs(dragOffset) > swipeThreshold && !showingParkingDetails {
                        HapticManager.lightImpact()
                    }
                }
                .onEnded { value in
                    isDragging = false
                    let velocity = value.predictedEndTranslation.height - value.translation.height
                    
                    // Check if swipe threshold was met or if there's sufficient velocity
                    let shouldOpen = abs(dragOffset) > swipeThreshold || 
                                   (value.translation.height < -30 && velocity < -100)
                    
                    if shouldOpen {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0)) {
                            showingParkingDetails = true
                            dragOffset = 0
                        }
                        HapticManager.mediumImpact()
                    } else {
                        // Reset position with spring animation
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0)) {
                            dragOffset = 0
                        }
                    }
                }
        )
        .onTapGesture {
            HapticManager.lightImpact()
            showingParkingDetails = true
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
