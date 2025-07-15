import SwiftUI

struct NotParkedStateView: View {
    @ObservedObject var locationManager: LocationManager
    @Binding var detectedGarageName: String?
    @Binding var showingFloorPicker: Bool
    
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
                .background(Color.blue)
                .cornerRadius(12)
            }
            .disabled(locationManager.isDetectingParking)
            .padding(.horizontal, 20)
        }
        .padding(.bottom, 10)
    }
}

#Preview {
    NotParkedStateView(locationManager: LocationManager(), detectedGarageName: .constant(nil), showingFloorPicker: .constant(false))
}
