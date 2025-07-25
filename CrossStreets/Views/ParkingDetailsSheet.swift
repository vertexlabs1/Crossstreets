import SwiftUI
import PhotosUI

struct ParkingDetailsSheet: View {
    @ObservedObject var locationManager: LocationManager
    let parking: ParkingLocation
    @Environment(\.dismiss) private var dismiss
    @State private var notes: String = ""
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var parkingPhotos: [UIImage] = []
    @State private var dragOffset: CGFloat = 0
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Native drag indicator
                VStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 2.5)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 36, height: 5)
                    RoundedRectangle(cornerRadius: 2.5)
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 24, height: 3)
                }
                .padding(.top, 8)
                .padding(.bottom, 20)
                .offset(y: dragOffset)
                .gesture(
                    DragGesture(minimumDistance: 5)
                        .onChanged { value in
                            // Only allow downward drag for dismiss
                            if value.translation.height > 0 {
                                dragOffset = value.translation.height * 0.5
                            }
                        }
                        .onEnded { value in
                            let velocity = value.predictedEndTranslation.height - value.translation.height
                            
                            // Dismiss if dragged down far enough or with sufficient velocity
                            if value.translation.height > 100 || velocity > 500 {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    dismiss()
                                }
                            } else {
                                // Reset position
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    dragOffset = 0
                                }
                            }
                        }
                )
                
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
                                .onTapGesture {
                                    HapticManager.lightImpact()
                                }
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
                                .onTapGesture {
                                    HapticManager.lightImpact()
                                }
                            }
                            
                            if parkingPhotos.isEmpty {
                                Text("Tap the + button to add photos of your parking spot")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(8)
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
                                                    HapticManager.lightImpact()
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
            }
            .navigationTitle("Parking Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        HapticManager.lightImpact()
                        saveChanges()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Share") {
                        HapticManager.lightImpact()
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
                        HapticManager.lightImpact()
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