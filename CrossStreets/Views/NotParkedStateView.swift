import SwiftUI

struct NotParkedStateView: View {
    @ObservedObject var locationManager: LocationManager
    @Binding var detectedGarageName: String?
    @Binding var showingFloorPicker: Bool
    @State private var isButtonPressed = false
    @State private var showReportIssue = false
    @State private var hasCompletedDetection = false
    
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
                print("🔍 DEBUG: Park Here button pressed!")
                isButtonPressed = true
                hasCompletedDetection = false
                HapticManager.lightImpact()
                
                // Reset button state after a short delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isButtonPressed = false
                }
                
                detectedGarageName = nil
                print("🔍 DEBUG: About to call locationManager.detectParkingType()")
                locationManager.detectParkingType()
                
                // Check if detection completed without finding a garage
                DispatchQueue.main.asyncAfter(deadline: .now() + 7.0) {
                    if !locationManager.isDetectingParking && detectedGarageName == nil {
                        hasCompletedDetection = true
                    }
                }
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
            
            // Report Issue Button (only show when detection completed without garage)
            if hasCompletedDetection && !locationManager.isDetectingParking && detectedGarageName == nil {
                Button(action: {
                    showReportIssue = true
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 12))
                        Text("Report Detection Issue")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.orange)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.bottom, 10)
        .alert("Report Detection Issue", isPresented: $showReportIssue) {
            Button("Cancel", role: .cancel) { }
            Button("Report") {
                if let location = locationManager.currentLocation {
                    locationManager.logGarageDetectionFailure(
                        location: location,
                        notes: "User reported garage detection failed"
                    )
                }
            }
        } message: {
            Text("Help us improve garage detection by reporting this issue. Your location data will be used to enhance the detection algorithm.")
        }
    }
}

#Preview {
    NotParkedStateView(locationManager: LocationManager(), detectedGarageName: .constant(nil), showingFloorPicker: .constant(false))
}
