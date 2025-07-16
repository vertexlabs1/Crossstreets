import SwiftUI

struct ParkedStateView: View {
    @ObservedObject var locationManager: LocationManager
    @Binding var showingFloorPicker: Bool
    @Binding var detectedGarageName: String?
    @State private var displayAddress: String = ""
    
    var body: some View {
        guard let parkedLocation = locationManager.parkedLocation else {
            return AnyView(EmptyView())
        }
        
        return AnyView(
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("PARKED AT")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                        .tracking(0.5)
                    
                    Text(displayAddress.isEmpty ? "Locating..." : displayAddress)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(nil)
                        .onAppear {
                            displayAddress = parkedLocation.address
                        }
                        .onChange(of: parkedLocation.address) { oldValue, newAddress in
                            Task { @MainActor in
                                displayAddress = newAddress
                            }
                        }
                    
                    HStack(spacing: 12) {
                        if let garageName = parkedLocation.garageName {
                            HStack(spacing: 4) {
                                Image(systemName: "building.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.blue)
                                Text(garageName)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.blue)
                            }
                        }
                        
                        if let floor = parkedLocation.floor {
                            HStack(spacing: 6) {
                                Text(floor)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.primary)
                                
                                Button(action: {
                                    Task { @MainActor in
                                        detectedGarageName = parkedLocation.garageName
                                        withAnimation {
                                            showingFloorPicker = true
                                        }
                                    }
                                }) {
                                    Image(systemName: "pencil.circle.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(.blue)
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(6)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(DateHelper.timeAgo(from: parkedLocation.timestamp))
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                            
                            // Show offline indicator if showing coordinates
                            if parkedLocation.address.contains("°") {
                                HStack(spacing: 3) {
                                    Image(systemName: "wifi.slash")
                                        .font(.system(size: 10))
                                        .foregroundColor(.orange)
                                    Text("Offline")
                                        .font(.system(size: 10))
                                        .foregroundColor(.orange)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 4)
                
                HStack(spacing: 12) {
                    Button(action: {
                        HapticManager.lightImpact()
                        locationManager.getDirectionsToParkedCar()
                    }) {
                        HStack {
                            Image(systemName: "location.fill")
                                .font(.system(size: 16))
                            Text("Get Directions")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(Color.blue)
                        .cornerRadius(12)
                    }
                    
                    Button(action: {
                        HapticManager.mediumImpact()
                        Task { @MainActor in
                            withAnimation {
                                locationManager.clearParkedLocation()
                            }
                        }
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 50, height: 50)
                            .background(Color.red.opacity(0.9))
                            .cornerRadius(12)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .contentShape(Rectangle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 10)
            .onReceive(locationManager.$parkedLocation) { location in
                if let newAddress = location?.address {
                    Task { @MainActor in
                        displayAddress = newAddress
                    }
                }
            }
        )
    }
}

#Preview {
    ParkedStateView(locationManager: LocationManager(), showingFloorPicker: .constant(false), detectedGarageName: .constant(nil))
}
