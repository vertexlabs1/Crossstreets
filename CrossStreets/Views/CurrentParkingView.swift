import SwiftUI
import PhotosUI

struct CurrentParkingView: View {
    @ObservedObject var locationManager: LocationManager
    @State private var displayAddress: String = ""
    @State private var showingParkingDetails = false
    
    var body: some View {
        if let parking = locationManager.parkedLocation {
            Button(action: { showingParkingDetails = true }) {
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
                                Text(garageName)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.primary)
                                    .lineLimit(2)
                                    .onAppear {
                                        displayAddress = parking.address
                                    }
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
                                Text(displayAddress.isEmpty ? "Locating..." : displayAddress)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.primary)
                                    .lineLimit(2)
                                    .onAppear {
                                        displayAddress = parking.address
                                    }
                            }
                            HStack(spacing: 8) {
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
            }
            .buttonStyle(PlainButtonStyle())
            .sheet(isPresented: $showingParkingDetails) {
                ParkingDetailsSheet(locationManager: locationManager, parking: parking)
            }
        } else {
            EmptyView()
        }
    }
}

struct ParkingDetailsSheet: View {
    @ObservedObject var locationManager: LocationManager
    let parking: ParkingLocation
    @Environment(\.dismiss) private var dismiss
    @State private var notes: String = ""
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var parkingPhotos: [UIImage] = []
    @State private var showingPhotoPicker = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header with location info
                    VStack(alignment: .leading, spacing: 8) {
                        if let garageName = parking.garageName {
                            Text(garageName)
                                .font(.title2)
                                .fontWeight(.semibold)
                            if let floor = parking.floor {
                                Text("Floor \(floor)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            Text(parking.address)
                                .font(.title2)
                                .fontWeight(.semibold)
                        }
                        Text("Parked \(DateHelper.timeAgo(from: parking.timestamp))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    
                    Divider()
                    
                    // Notes section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "note.text")
                                .foregroundColor(.blue)
                            Text("Notes")
                                .font(.headline)
                            Spacer()
                        }
                        TextField("Add a note about your parking spot...", text: $notes, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(3...6)
                    }
                    .padding(.horizontal)
                    
                    // Photos section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "photo")
                                .foregroundColor(.blue)
                            Text("Photos")
                                .font(.headline)
                            Spacer()
                            PhotosPicker(selection: $selectedPhotos, matching: .images) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.blue)
                            }
                        }
                        
                        if parkingPhotos.isEmpty {
                            Button(action: { showingPhotoPicker = true }) {
                                HStack {
                                    Image(systemName: "camera")
                                    Text("Add Photo")
                                }
                                .foregroundColor(.blue)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(8)
                            }
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(Array(parkingPhotos.enumerated()), id: \.offset) { index, photo in
                                        VStack {
                                            Image(uiImage: photo)
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(width: 100, height: 100)
                                                .clipped()
                                                .cornerRadius(8)
                                            Button("Delete") {
                                                parkingPhotos.remove(at: index)
                                            }
                                            .font(.caption)
                                            .foregroundColor(.red)
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    Divider()
                    
                    // Location details
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "location")
                                .foregroundColor(.blue)
                            Text("Location Details")
                                .font(.headline)
                            Spacer()
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            DetailRow(title: "Address", value: parking.address)
                            DetailRow(title: "Coordinates", value: "\(String(format: "%.6f", parking.coordinate.latitude)), \(String(format: "%.6f", parking.coordinate.longitude))")
                            if let garageName = parking.garageName {
                                DetailRow(title: "Garage", value: garageName)
                            }
                            if let floor = parking.floor {
                                DetailRow(title: "Floor", value: floor)
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    Spacer(minLength: 100)
                }
            }
            .navigationTitle("Parking Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        saveChanges()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Share") {
                        shareParkingLocation()
                    }
                }
            }
        }
        .onAppear {
            notes = parking.notes ?? ""
            parkingPhotos = locationManager.loadParkingPhotos()
        }
        .onChange(of: selectedPhotos) { _, newPhotos in
            Task {
                for photo in newPhotos {
                    if let data = try? await photo.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        parkingPhotos.append(image)
                    }
                }
            }
        }
    }
    
    private func saveChanges() {
        // Save notes to the parking location
        locationManager.updateParkingNotes(notes)
        
        // Save photos to file system and update parking location
        locationManager.updateParkingPhotos(parkingPhotos)
    }
    
    private func shareParkingLocation() {
        let locationText: String
        if let garageName = parking.garageName {
            locationText = "Parked at \(garageName)"
        } else {
            locationText = "Parked at \(parking.address)"
        }
        
        let shareText = """
        \(locationText)
        Floor: \(parking.floor ?? "Unknown")
        Time: \(parking.timestamp.formatted())
        
        Get directions: maps://?q=\(parking.coordinate.latitude),\(parking.coordinate.longitude)
        """
        
        let activityVC = UIActivityViewController(
            activityItems: [shareText],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityVC, animated: true)
        }
    }
}

struct DetailRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .multilineTextAlignment(.trailing)
        }
    }
}

#Preview {
    CurrentParkingView(locationManager: LocationManager())
}

