import SwiftUI

struct FloorPickerView: View {
    @Binding var showingFloorPicker: Bool
    @ObservedObject var locationManager: LocationManager
    let garageName: String
    @State private var selectedFloor: String?
    @State private var detectedFloor: String?
    @State private var showingAllFloors = false
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    showingFloorPicker = false
                }
            
            VStack {
                Spacer()
                
                VStack(spacing: 16) { // Reduced spacing from 20 to 16
                    // Header
                    VStack(spacing: 6) { // Reduced spacing from 8 to 6
                        // Simple car icon
                        Image(systemName: "car.fill")
                            .font(.system(size: 36))
                            .foregroundColor(.blue)
                            .padding(.bottom, 2) // Reduced padding
                        
                        // Garage name for context
                        Text(garageName)
                            .font(.title) // Increased from headline to title for more prominence
                            .fontWeight(.bold) // Changed from semibold to bold
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .padding(.horizontal)
                            .padding(.bottom, 2) // Add spacing between garage name and "Select Your Floor"
                        
                        Text("Select Your Floor")
                            .font(.title) // Increased from title2 to title for maximum visibility
                            .fontWeight(.black) // Changed from bold to black for maximum prominence
                            .foregroundColor(.primary) // Primary color for maximum contrast
                            .padding(.vertical, 8) // Add vertical padding to make it more prominent
                            .padding(.horizontal, 16) // Add horizontal padding
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.blue.opacity(0.1)) // Light blue background to make it stand out
                            )
                            .padding(.bottom, 8) // Add bottom padding to separate from description
                        
                        if let detectedFloor = detectedFloor, garageName != "Custom Location" {
                            Text("We detected you're on **\(detectedFloor)**. Please correct if this is wrong so we can learn!")
                                .font(.body)
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        } else {
                            Text("Select the floor where you parked")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                    }
                    
                    // Floor Selection
                    if showingAllFloors {
                        AllFloorsView(
                            selectedFloor: $selectedFloor,
                            allFloors: getAllFloors(),
                            showingAllFloors: $showingAllFloors,
                            saveAction: saveAndClose,
                            estimatedFloor: detectedFloor
                        )
                    } else {
                        QuickFloorSelectionView(
                            selectedFloor: $selectedFloor,
                            mainFloors: getMainFloors(),
                            basementFloors: getBasementFloors(),
                            showingAllFloors: $showingAllFloors,
                            saveAction: saveAndClose,
                            estimatedFloor: detectedFloor
                        )
                    }
                    
                    // Save Button
                    if selectedFloor != nil {
                        Button(action: saveAndClose) {
                            Text("Save")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(Color.blue)
                                        .shadow(color: .blue.opacity(0.3), radius: 8, y: 4)
                                )
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(28)
                .padding(.horizontal, 8)
                .background(
                    RoundedRectangle(cornerRadius: 28)
                        .fill(Color.white)
                        .shadow(color: .black.opacity(0.25), radius: 40, y: -15)
                )
            }
        }
        .onAppear {
            // Prevent multiple detections if view is re-appeared rapidly
            guard detectedFloor == nil else { return }
            // Detect floor when view appears
            detectedFloor = locationManager.detectFloorForGarage(garageName)
        }
    }
    
    private func saveAndClose() {
        guard let floor = selectedFloor else { return }
        
        // Start performance monitoring
        PerformanceMonitor.shared.startAction("floor_save")
        
        HapticManager.lightImpact()
        
        // Log the floor detection result
        if let detectedFloor = detectedFloor {
            locationManager.logFloorDetectionResult(
                detectedFloor: detectedFloor,
                actualFloor: floor,
                garageName: garageName
            )
        }
        
        locationManager.saveParkedLocation(floor: floor)
        showingFloorPicker = false
        
        // End performance monitoring
        PerformanceMonitor.shared.endAction("floor_save", screen: "floor_picker", success: true, context: ["floor": floor, "garage": garageName])
    }
    
    private func selectFloor(_ floor: String) {
        // Start performance monitoring
        PerformanceMonitor.shared.startAction("floor_selection")
        
        selectedFloor = floor
        showingFloorPicker = false
        
        // Log the floor detection result
        if let detectedFloor = detectedFloor {
            locationManager.logFloorDetectionResult(
                detectedFloor: detectedFloor,
                actualFloor: floor,
                garageName: garageName
            )
        }
        
        // Removed: recordFloorCorrection() - now handled by Supabase
        
        // Update the parked location with the selected floor
        if var updatedLocation = locationManager.parkedLocation {
            updatedLocation.floor = floor
            locationManager.parkedLocation = updatedLocation
            locationManager.saveParkedLocation(floor: floor)
        }
        
        HapticManager.mediumImpact()
        
        // End performance monitoring
        PerformanceMonitor.shared.endAction("floor_selection", screen: "floor_picker", success: true, context: ["floor": floor, "garage": garageName])
    }
    
    private func getMainFloors() -> [String] {
        return ["G", "F1", "F2", "F3", "F4", "F5", "F6", "F7", "F8", "F9", "F10"]
    }
    
    private func getBasementFloors() -> [String] {
        return ["B1", "B2", "B3", "B4"]
    }
    
    private func getAllFloors() -> [String] {
        return getBasementFloors() + getMainFloors()
    }
}

#Preview {
    FloorPickerView(showingFloorPicker: .constant(true), locationManager: LocationManager(), garageName: "Test Garage")
}
