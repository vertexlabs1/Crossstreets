import SwiftUI
import PhotosUI

struct ParkingDetailsSheet: View {
    @ObservedObject var locationManager: LocationManager
    let parking: ParkingLocation
    @Environment(\.dismiss) private var dismiss
    @State private var notes: String = ""
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var parkingPhotos: [UIImage] = []
    @State private var showingCamera = false
    @State private var showingImagePicker = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Drag indicator at the top
                VStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 2.5)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 32, height: 4)
                    RoundedRectangle(cornerRadius: 2.5)
                        .fill(Color.gray.opacity(0.15))
                        .frame(width: 20, height: 2)
                }
                .padding(.top, 8)
                .padding(.bottom, 16)
                
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
                                HStack(spacing: 12) {
                                    Button(action: {
                                        HapticManager.lightImpact()
                                        showingCamera = true
                                    }) {
                                        HStack {
                                            Image(systemName: "camera")
                                            Text("Capture Photo")
                                        }
                                        .foregroundColor(.blue)
                                        .padding()
                                        .frame(maxWidth: .infinity)
                                        .background(Color.blue.opacity(0.1))
                                        .cornerRadius(8)
                                    }
                                    
                                    Button(action: {
                                        HapticManager.lightImpact()
                                        showingImagePicker = true
                                    }) {
                                        HStack {
                                            Image(systemName: "photo.on.rectangle")
                                            Text("Choose Photo")
                                        }
                                        .foregroundColor(.blue)
                                        .padding()
                                        .frame(maxWidth: .infinity)
                                        .background(Color.blue.opacity(0.1))
                                        .cornerRadius(8)
                                    }
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
        .sheet(isPresented: $showingCamera) {
            CameraView { image in
                if let image = image {
                    parkingPhotos.append(image)
                    HapticManager.lightImpact()
                }
            }
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(selectedImage: Binding(
                get: { nil },
                set: { image in
                    if let image = image {
                        parkingPhotos.append(image)
                        HapticManager.lightImpact()
                    }
                }
            ))
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

// Camera view for capturing photos
struct CameraView: UIViewControllerRepresentable {
    let completion: (UIImage?) -> Void
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .camera
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(completion: completion)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let completion: (UIImage?) -> Void
        
        init(completion: @escaping (UIImage?) -> Void) {
            self.completion = completion
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            let image = info[.originalImage] as? UIImage
            picker.dismiss(animated: true) {
                self.completion(image)
            }
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true) {
                self.completion(nil)
            }
        }
    }
}

// Image picker for choosing existing photos
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
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
            picker.dismiss(animated: true)
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
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