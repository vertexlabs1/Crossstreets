import SwiftUI

struct FloorPickerView: View {
    @Binding var showingFloorPicker: Bool
    @ObservedObject var locationManager: LocationManager
    let garageName: String
    
    @State private var selectedFloor: String?
    @State private var showingAllFloors = false
    @State private var estimatedFloor: String? = nil
    @AppStorage("averageFloorHeight") private var averageFloorHeight: Double = 3.5
    @State private var showSetBaselineAlert = false
    
    let mainFloors = ["F1", "F2", "F3", "F4", "F5", "F6", "F7", "F8", "F9", "F10", "RF"]
    let basementFloors = ["B3", "B2", "B1"]
    let allFloors: [String] = {
        var floors: [String] = []
        for i in (4...10).reversed() {
            floors.append("B\(i)")
        }
        floors.append(contentsOf: ["B3", "B2", "B1", "G"])
        for i in 1...50 {
            floors.append("F\(i)")
        }
        floors.append("RF") // Add Roof Floor
        return floors
    }()
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    showingFloorPicker = false
                }
            
            VStack {
                Spacer()
                
                VStack(spacing: 16) {
                    VStack(spacing: 8) {
                        Text("SELECT FLOOR")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.black.opacity(0.6))
                            .tracking(1)
                        
                        Text(garageName)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.black)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 10)
                        
                        if let estimate = estimatedFloor {
                            Text("You’re likely on \(estimate)")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.blue)
                        } else {
                            Text("Estimating floor...")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                        }
                        // --- Controls for baseline and floor height ---
                        HStack(spacing: 12) {
                            Button(action: { showSetBaselineAlert = true }) {
                                Label("Set Ground Floor", systemImage: "arrow.down.to.line")
                                    .font(.system(size: 13, weight: .medium))
                            }
                            .alert(isPresented: $showSetBaselineAlert) {
                                Alert(
                                    title: Text("Set Ground Floor Baseline?"),
                                    message: Text("This will use your current altitude as the ground floor for this garage."),
                                    primaryButton: .default(Text("Set")) {
                                        locationManager.setGroundFloorBaseline()
                                        locationManager.estimateFloor { floor in
                                            estimatedFloor = floor
                                        }
                                    },
                                    secondaryButton: .cancel()
                                )
                            }
                            HStack(spacing: 4) {
                                Text("Floor Height:")
                                    .font(.system(size: 13))
                                Stepper(value: $averageFloorHeight, in: 2.0...6.0, step: 0.1) {
                                    Text("\(averageFloorHeight, specifier: "%.1f")m")
                                        .font(.system(size: 13, weight: .medium))
                                }
                                .frame(width: 120)
                            }
                        }
                        .padding(.top, 2)
                        // ---
                    }
                    .padding(.top, 8)
                    
                    if !showingAllFloors {
                        QuickFloorSelectionView(
                            selectedFloor: $selectedFloor,
                            mainFloors: mainFloors,
                            basementFloors: basementFloors,
                            showingAllFloors: $showingAllFloors,
                            saveAction: saveAndClose,
                            estimatedFloor: estimatedFloor
                        )
                    } else {
                        AllFloorsView(
                            selectedFloor: $selectedFloor,
                            allFloors: allFloors,
                            showingAllFloors: $showingAllFloors,
                            saveAction: saveAndClose,
                            estimatedFloor: estimatedFloor
                        )
                    }
                    
                    HStack(spacing: 12) {
                        Button(action: {
                            locationManager.saveParkedLocation(floor: nil)
                            showingFloorPicker = false
                        }) {
                            Text("Skip")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.black.opacity(0.7))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(Color.white)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14)
                                                .strokeBorder(Color.gray.opacity(0.3), lineWidth: 1.5)
                                        )
                                        .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
                                )
                        }
                        
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
                }
                .padding(28)
                .padding(.horizontal, 8)
                .background(
                    RoundedRectangle(cornerRadius: 28)
                        .fill(Color.white)
                        .shadow(color: .black.opacity(0.25), radius: 40, y: -15)
                )
                .onAppear {
                    locationManager.estimateFloor { floor in
                        estimatedFloor = floor
                    }
                }
            }
        }
    }
    
    private func saveAndClose() {
        guard let floor = selectedFloor else { return }
        
        HapticManager.lightImpact()
        locationManager.saveParkedLocation(floor: floor)
        locationManager.saveUserFloorCorrection(selected: floor, estimated: estimatedFloor)
        showingFloorPicker = false
    }
}

#Preview {
    FloorPickerView(showingFloorPicker: .constant(true), locationManager: LocationManager(), garageName: "Test Garage")
}
