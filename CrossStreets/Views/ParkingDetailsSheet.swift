import SwiftUI
import PhotosUI

struct ParkingDetailsSheet: View {
    @ObservedObject var locationManager: LocationManager
    let parking: ParkingLocation
    @Environment(\.dismiss) private var dismiss
    @State private var notes: String = ""
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var parkingPhotos: [UIImage] = []
    @State private var showingImagePicker = false
    @State private var showingShareSheet = false
    @FocusState private var isNotesFieldFocused: Bool
    
    private var shareContent: String {
        print("📤 Computing share content for parking: \(parking)")
        print("📤 Parking details:")
        print("   - Address: '\(parking.address)'")
        print("   - Garage: \(parking.garageName ?? "nil")")
        print("   - Floor: \(parking.floor ?? "nil")")
        print("   - Coordinates: \(parking.coordinate.latitude), \(parking.coordinate.longitude)")
        print("   - Timestamp: \(parking.timestamp)")
        
        // Validate parking data
        guard !parking.address.isEmpty else {
            print("❌ Share failed: Empty address")
            return "Unable to share location - address not available"
        }
        
        let locationText: String
        if let garageName = parking.garageName {
            if let floor = parking.floor {
                locationText = "Hey, I'm parked at \(garageName) on floor \(floor)"
            } else {
                locationText = "Hey, I'm parked at \(garageName)"
            }
        } else {
            locationText = "Hey, I'm parked at \(parking.address)"
        }
        
        let directionsLink = "\n\nGet directions: maps://?q=\(parking.coordinate.latitude),\(parking.coordinate.longitude)"
        
        let content = locationText + directionsLink
        print("📤 Share content computed: '\(content)'")
        return content
    }
    
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
                            .focused($isNotesFieldFocused)
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
                            Button("Capture Photo") {
                                showingImagePicker = true
                            }
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.blue)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                        }
                        
                        if parkingPhotos.isEmpty {
                            Text("Tap 'Capture Photo' to take a photo of your parking spot")
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
                        print("📤 Share button pressed")
                        showingShareSheet = true
                    }
                    .disabled(parking.address.isEmpty)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        isNotesFieldFocused = false
                    }
                }
            }
        }
        .onAppear {
            print("📱 ParkingDetailsSheet appeared with parking: \(parking)")
            print("📱 Parking data on appear:")
            print("   - Address: '\(parking.address)'")
            print("   - Garage: \(parking.garageName ?? "nil")")
            print("   - Floor: \(parking.floor ?? "nil")")
            print("   - Notes: \(parking.notes ?? "nil")")
            
            notes = parking.notes ?? ""
            // Load photos asynchronously to prevent blocking
            DispatchQueue.global(qos: .userInitiated).async {
                let photos = locationManager.loadParkingPhotos()
                DispatchQueue.main.async {
                    parkingPhotos = photos
                }
            }
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(selectedImage: Binding(
                get: { nil },
                set: { image in
                    if let image = image {
                        parkingPhotos.append(image)
                    }
                }
            ))
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(activityItems: [shareContent])
        }
    }
    
    private func saveChanges() {
        locationManager.updateParkingNotes(notes)
        locationManager.updateParkingPhotos(parkingPhotos)
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .camera
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        print("📤 ShareSheet: Creating UIActivityViewController with \(activityItems.count) items")
        for (index, item) in activityItems.enumerated() {
            print("📤 ShareSheet: Item \(index): '\(item)'")
        }
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
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