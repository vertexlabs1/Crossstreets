import SwiftUI
import CoreMotion

struct AutoParkingDebugView: View {
    @ObservedObject var locationManager: LocationManager
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Status Overview
                    VStack(alignment: .leading, spacing: 12) {
                        Text("AUTOMATIC PARKING DETECTION")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)
                            .tracking(0.5)
                        
                        VStack(spacing: 12) {
                            StatusCard(
                                title: "Auto Detection",
                                value: locationManager.isAutoParkingEnabled ? "Enabled" : "Disabled",
                                color: locationManager.isAutoParkingEnabled ? .green : .red,
                                icon: "car.fill"
                            )
                            
                            StatusCard(
                                title: "Detection Status",
                                value: locationManager.autoParkingStatus.description,
                                color: statusColor(for: locationManager.autoParkingStatus),
                                icon: "location.circle.fill"
                            )
                            
                            if let motionActivity = locationManager.lastMotionActivity {
                                StatusCard(
                                    title: "Motion Activity",
                                    value: motionActivityDescription(motionActivity),
                                    color: .blue,
                                    icon: "figure.walk"
                                )
                            }
                        }
                    }
                    
                    // Control Buttons
                    VStack(alignment: .leading, spacing: 12) {
                        Text("CONTROLS")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)
                            .tracking(0.5)
                        
                        VStack(spacing: 12) {
                            Button(action: {
                                locationManager.toggleAutoParkingDetection()
                            }) {
                                HStack {
                                    Image(systemName: locationManager.isAutoParkingEnabled ? "pause.circle.fill" : "play.circle.fill")
                                    Text(locationManager.isAutoParkingEnabled ? "Disable Auto Detection" : "Enable Auto Detection")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                            
                            Button(action: {
                                locationManager.detectParkingType()
                            }) {
                                HStack {
                                    Image(systemName: "car.circle.fill")
                                    Text("Manual Parking Detection")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.orange)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                        }
                    }
                    
                    // Location Info
                    VStack(alignment: .leading, spacing: 12) {
                        Text("LOCATION INFO")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)
                            .tracking(0.5)
                        
                        if let location = locationManager.currentLocation {
                            VStack(spacing: 8) {
                                InfoRow(title: "Latitude", value: String(format: "%.6f", location.coordinate.latitude))
                                InfoRow(title: "Longitude", value: String(format: "%.6f", location.coordinate.longitude))
                                InfoRow(title: "Accuracy", value: "\(Int(location.horizontalAccuracy))m")
                                InfoRow(title: "Speed", value: String(format: "%.1f m/s", location.speed))
                                InfoRow(title: "Altitude", value: String(format: "%.1f m", location.altitude))
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        } else {
                            Text("No location available")
                                .foregroundColor(.secondary)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                        }
                    }
                    
                    // Parking Status
                    VStack(alignment: .leading, spacing: 12) {
                        Text("PARKING STATUS")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)
                            .tracking(0.5)
                        
                        if let parkedLocation = locationManager.parkedLocation {
                            VStack(spacing: 8) {
                                InfoRow(title: "Address", value: parkedLocation.address)
                                InfoRow(title: "Floor", value: parkedLocation.floor ?? "Not set")
                                InfoRow(title: "Parked At", value: DateHelper.timeAgo(from: parkedLocation.timestamp))
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        } else {
                            Text("No car parked")
                                .foregroundColor(.secondary)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Auto Parking Debug")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func statusColor(for status: LocationManager.AutoParkingStatus) -> Color {
        switch status {
        case .idle: return .gray
        case .monitoring: return .blue
        case .driving: return .orange
        case .detecting: return .yellow
        case .confirmed: return .green
        case .failed: return .red
        }
    }
    
    private func motionActivityDescription(_ activity: CMMotionActivity) -> String {
        var descriptions: [String] = []
        
        if activity.automotive {
            descriptions.append("Driving")
        }
        if activity.walking {
            descriptions.append("Walking")
        }
        if activity.running {
            descriptions.append("Running")
        }
        if activity.stationary {
            descriptions.append("Stationary")
        }
        if activity.cycling {
            descriptions.append("Cycling")
        }
        
        let confidence = activity.confidence == .high ? "High" : 
                       activity.confidence == .medium ? "Medium" : "Low"
        
        return descriptions.isEmpty ? "Unknown" : "\(descriptions.joined(separator: ", ")) (\(confidence))"
    }
}

struct StatusCard: View {
    let title: String
    let value: String
    let color: Color
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                Text(value)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct InfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primary)
            Spacer()
            Text(value)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    AutoParkingDebugView(locationManager: LocationManager())
}
