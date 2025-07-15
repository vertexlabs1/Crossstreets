import SwiftUI

struct NotParkedStateView: View {
    @ObservedObject var locationManager: LocationManager
    @Binding var detectedGarageName: String?
    @Binding var showingFloorPicker: Bool
    @State private var isButtonPressed = false
    
    var body: some View {
        VStack(spacing: 14) {
            VStack(spacing: 4) {
                Text("Where's your car?")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.primary)
                Text("Save your parking location")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
            }
            
            Button(action: {
                // Add immediate visual feedback
                isButtonPressed = true
                HapticManager.lightImpact()
                
                // Reset button state after a short delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isButtonPressed = false
                }
                
                detectedGarageName = nil
                locationManager.detectParkingType()
            }) {
                HStack(spacing: 10) {
                    if locationManager.isDetectingParking {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.9)
                    } else {
                        Image(systemName: "car.fill")
                            .font(.system(size: 18))
                    }
                    Text("Park Here")
                        .font(.system(size: 17, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.blue)
                        .scaleEffect(isButtonPressed ? 0.95 : 1.0)
                        .animation(.easeInOut(duration: 0.1), value: isButtonPressed)
                )
            }
            .disabled(locationManager.isDetectingParking)
            .padding(.horizontal, 20)
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.bottom, 10)
    }
}

#Preview {
    NotParkedStateView(locationManager: LocationManager(), detectedGarageName: .constant(nil), showingFloorPicker: .constant(false))
}
