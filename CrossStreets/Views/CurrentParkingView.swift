import SwiftUI

struct CurrentParkingView: View {
    @ObservedObject var locationManager: LocationManager
    @State private var displayAddress: String = ""
    
    // Timer for timeAgo display - updates every 30 seconds instead of every second
    @State private var timeAgoString: String = ""
    @State private var timeAgoTimer: Timer?
    
    var body: some View {
        if let parking = locationManager.parkedLocation {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 8, height: 8)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Currently Parked")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.blue)
                        
                        Text(displayAddress.isEmpty ? "Locating..." : displayAddress)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                            .onAppear {
                                displayAddress = parking.address
                            }
                            // Removed onChange to prevent continuous view rebuilding
                        
                        if let garageName = parking.garageName {
                            HStack(spacing: 4) {
                                Image(systemName: "building.fill")
                                    .font(.system(size: 11))
                                Text(garageName)
                                    .font(.system(size: 14))
                                if let floor = parking.floor {
                                    Text("• \(floor)")
                                        .font(.system(size: 14, weight: .medium))
                                }
                            }
                            .foregroundColor(.secondary)
                        }
                        
                        HStack(spacing: 8) {
                            Text(timeAgoString)
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                            
                            if parking.address.contains("°") {
                                HStack(spacing: 2) {
                                    Image(systemName: "wifi.slash")
                                        .font(.system(size: 9))
                                    Text("Offline")
                                        .font(.system(size: 9))
                                }
                                .foregroundColor(.orange)
                            }
                        }
                    }
                    
                    Spacer()
                }
                .padding(16)
                .background(Color.blue.opacity(0.05))
                .cornerRadius(10)
            }
            .onAppear {
                updateTimeAgo()
                startTimeAgoTimer()
            }
            .onDisappear {
                stopTimeAgoTimer()
            }
            // Removed onReceive to prevent continuous view rebuilding
        } else {
            EmptyView()
        }
    }
    
    private func updateTimeAgo() {
        guard let parking = locationManager.parkedLocation else { return }
        timeAgoString = DateHelper.timeAgo(from: parking.timestamp)
    }
    
    private func startTimeAgoTimer() {
        // Update every 30 seconds instead of every second
        timeAgoTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
            updateTimeAgo()
        }
    }
    
    private func stopTimeAgoTimer() {
        timeAgoTimer?.invalidate()
        timeAgoTimer = nil
    }
}

#Preview {
    CurrentParkingView(locationManager: LocationManager())
}
