import SwiftUI

struct QuickFloorSelectionView: View {
    @Binding var selectedFloor: String?
    let mainFloors: [String]
    let basementFloors: [String]
    @Binding var showingAllFloors: Bool
    let saveAction: () -> Void
    let estimatedFloor: String?
    
    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Text("GROUND")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.black.opacity(0.6))
                    .tracking(0.5)
                
                FloorButton(floor: "G", isSelected: selectedFloor == "G", isEstimated: estimatedFloor == "G") {
                    selectedFloor = "G"
                    saveAction()
                }
            }
            
            VStack(spacing: 10) {
                Text("FLOORS")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.black.opacity(0.6))
                    .tracking(0.5)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 5), spacing: 10) {
                    ForEach(mainFloors, id: \.self) { floor in
                        FloorButton(floor: floor, isSelected: selectedFloor == floor, isEstimated: estimatedFloor == floor) {
                            selectedFloor = floor
                            saveAction()
                        }
                    }
                }
            }
            
            VStack(spacing: 10) {
                Text("BASEMENT")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.black.opacity(0.6))
                    .tracking(0.5)
                
                HStack(spacing: 10) {
                    ForEach(basementFloors, id: \.self) { floor in
                        FloorButton(floor: floor, isSelected: selectedFloor == floor, isEstimated: estimatedFloor == floor) {
                            selectedFloor = floor
                            saveAction()
                        }
                    }
                }
            }
            
            Button(action: {
                showingAllFloors = true
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 16))
                    Text("More floors")
                        .font(.system(size: 15, weight: .medium))
                }
                .foregroundColor(.blue)
                .padding(.vertical, 12)
                .padding(.horizontal, 24)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
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
