import SwiftUI

struct AllFloorsView: View {
    @Binding var selectedFloor: String?
    let allFloors: [String]
    @Binding var showingAllFloors: Bool
    let saveAction: () -> Void
    let estimatedFloor: String?
    
    var body: some View {
        VStack(spacing: 16) {
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 6), spacing: 10) {
                    ForEach(allFloors, id: \.self) { floor in
                        FloorButton(floor: floor, isSelected: selectedFloor == floor, isEstimated: estimatedFloor == floor, isCompact: true) {
                            selectedFloor = floor
                            saveAction()
                        }
                    }
                }
                .padding(.vertical, 8)
            }
            .frame(maxHeight: 300)
            
            Button(action: {
                HapticManager.lightImpact()
                showingAllFloors = false
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left.circle.fill")
                        .font(.system(size: 20))
                    Text("Back")
                        .font(.system(size: 15, weight: .medium))
                }
                .foregroundColor(.blue)
                .padding(.vertical, 10)
                .padding(.horizontal, 20)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(Color.blue.opacity(0.3), lineWidth: 1.5)
                        )
                        .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
                )
            }
        }
    }
}

#Preview {
    AllFloorsView(selectedFloor: .constant(nil), allFloors: ["F1"], showingAllFloors: .constant(false), saveAction: {}, estimatedFloor: "F1")
}
