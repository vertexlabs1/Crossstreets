import SwiftUI

struct CurrentParkingView: View {
    @ObservedObject var locationManager: LocationManager
    @State private var displayAddress: String = ""
    
    var body: some View {
        if let parking = locationManager.parkedLocation {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 8, height: 8)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Currently Parked")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.blue)
                        
                        if let garageName = parking.garageName {
                            // Garage parking - show garage name as main text
                            Text(garageName)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.primary)
                                .lineLimit(2)
                                .onAppear {
                                    displayAddress = parking.address
                                }
                            
                            // Show floor information below
                            if let floor = parking.floor {
                                HStack(spacing: 4) {
                                    Image(systemName: "building.fill")
                                        .font(.system(size: 11))
                                    Text("Floor \(floor)")
                                        .font(.system(size: 14))
                                        .foregroundColor(.secondary)
                                }
                            }
                        } else {
                            // Street parking - show address as main text
                            Text(displayAddress.isEmpty ? "Locating..." : displayAddress)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.primary)
                                .lineLimit(2)
                                .onAppear {
                                    displayAddress = parking.address
                                }
                        }
                        
                        HStack(spacing: 8) {
                            // Use the separate TimeAgoView component
                            TimeAgoView(timestamp: parking.timestamp)
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
            // Removed onReceive to prevent continuous view rebuilding
        } else {
            EmptyView()
        }
    }
}

#Preview {
    CurrentParkingView(locationManager: LocationManager())
}

