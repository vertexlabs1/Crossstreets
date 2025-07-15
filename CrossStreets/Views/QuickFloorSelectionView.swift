import SwiftUI

struct QuickFloorSelectionView: View {
    @Binding var selectedFloor: String?
    let mainFloors: [String]
    let basementFloors: [String]
    @Binding var showingAllFloors: Bool
    let saveAction: () -> Void
    let estimatedFloor: String?
    
    // Common floors that users select most often
    let commonFloors = ["G", "F1", "F2", "F3", "B1", "B2", "RF"]
    
    var body: some View {
        VStack(spacing: 20) {
            // Common floors section
            VStack(spacing: 10) {
                Text("COMMON FLOORS")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.black.opacity(0.6))
                    .tracking(0.5)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                    ForEach(commonFloors, id: \.self) { floor in
                        FloorButton(floor: floor, isSelected: selectedFloor == floor, isEstimated: estimatedFloor == floor) {
                            selectedFloor = floor
                            saveAction()
                        }
                    }
                }
            }
            
            // Other floors section
            VStack(spacing: 10) {
                Text("OTHER FLOORS")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.black.opacity(0.6))
                    .tracking(0.5)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 5), spacing: 10) {
                    ForEach(mainFloors.filter { !commonFloors.contains($0) }, id: \.self) { floor in
                        FloorButton(floor: floor, isSelected: selectedFloor == floor, isEstimated: estimatedFloor == floor) {
                            selectedFloor = floor
                            saveAction()
                        }
                    }
                }
            }
            
            // Basement section
            if !basementFloors.filter({ !commonFloors.contains($0) }).isEmpty {
                VStack(spacing: 10) {
                    Text("BASEMENT")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.black.opacity(0.6))
                        .tracking(0.5)
                    
                    HStack(spacing: 10) {
                        ForEach(basementFloors.filter { !commonFloors.contains($0) }, id: \.self) { floor in
                            FloorButton(floor: floor, isSelected: selectedFloor == floor, isEstimated: estimatedFloor == floor) {
                                selectedFloor = floor
                                saveAction()
                            }
                        }
                    }
                }
            }
            
            Button(action: {
                HapticManager.lightImpact()
                showingAllFloors = true
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "ellipsis.circle.fill")
                        .font(.system(size: 16))
                    Text("Show All Floors")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(.blue)
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(Color.blue.opacity(0.3), lineWidth: 1.5)
                        )
                        .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
                )
            }
        }
    }
}

#Preview {
    QuickFloorSelectionView(selectedFloor: .constant(nil), mainFloors: ["F1"], basementFloors: ["B1"], showingAllFloors: .constant(false), saveAction: {}, estimatedFloor: "F1")
}
