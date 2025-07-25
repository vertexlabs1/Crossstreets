import SwiftUI

// Separate view component that manages its own timer
struct TimeAgoView: View {
    let timestamp: Date
    @State private var timeAgoString: String = ""
    @State private var timer: Timer?
    
    var body: some View {
        Text(timeAgoString)
            .font(.system(size: 13))
            .foregroundColor(.secondary)
            .onAppear {
                updateTimeAgo()
                startTimer()
            }
            .onDisappear {
                stopTimer()
            }
    }
    
    private func updateTimeAgo() {
        timeAgoString = DateHelper.timeAgo(from: timestamp)
    }
    
    private func startTimer() {
        // Update every 30 seconds instead of every second to reduce performance impact
        timer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
            updateTimeAgo()
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

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
            VStack(alignment: .leading, spacing: 6) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("PARKED AT")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                        .tracking(0.5)
                    
                    if let garageName = parkedLocation.garageName {
                        Text(garageName)
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                            .onAppear {
                                displayAddress = parkedLocation.address
                            }
                            .onChange(of: parkedLocation.address) { _, newAddress in
                                displayAddress = newAddress
                            }
                        if let floor = parkedLocation.floor {
                            HStack(spacing: 6) {
                                Text(floor)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.primary)
                                Button(action: {
                                    guard !showingFloorPicker else { return }
                                    Task { @MainActor in
                                        detectedGarageName = parkedLocation.garageName
                                        withAnimation {
                                            showingFloorPicker = true
                                        }
                                    }
                                }) {
                                    Image(systemName: "pencil.circle.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(.blue)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    } else {
                        Text(displayAddress.isEmpty ? "Locating..." : displayAddress)
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                            .onAppear {
                                displayAddress = parkedLocation.address
                            }
                            .onChange(of: parkedLocation.address) { _, newAddress in
                                displayAddress = newAddress
                            }
                    }
                    if let notes = parkedLocation.notes, !notes.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "note.text")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                            Text(notes)
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.leading)
                                .lineLimit(2)
                        }
                        .padding(.top, 1)
                    }
                    HStack(spacing: 4) {
                        Spacer()
                        VStack(alignment: .trailing, spacing: 1) {
                            HStack {
                                Spacer()
                                // Removed notes icon/button here
                            }
                            TimeAgoView(timestamp: parkedLocation.timestamp)
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
                .padding(.bottom, 4)
                HStack(spacing: 12) {
                    Button(action: {
                        HapticManager.lightImpact()
                        locationManager.getDirectionsToParkedCar()
                    }) {
                        HStack {
                            Image(systemName: "paperplane.fill")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Get Directions")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .cornerRadius(10)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Button(action: {
                        HapticManager.mediumImpact()
                        locationManager.clearParkedLocation()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.red)
                            .cornerRadius(10)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 10)
        )
    }
}

#Preview {
    ParkedStateView(locationManager: LocationManager(), showingFloorPicker: .constant(false), detectedGarageName: .constant(nil))
}
