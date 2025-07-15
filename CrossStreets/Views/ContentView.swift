import SwiftUI
import MapKit

struct ContentView: View {
    @StateObject private var locationManager = LocationManager()
    @State private var position: MapCameraPosition = .automatic
    @State private var showingFloorPicker = false
    @State private var detectedGarageName: String?
    @State private var isDetectingGarage = false
    @State private var selectedTab = 0
    // --- New state for parking search ---
    @State private var parkingResults: [MKMapItem] = []
    @State private var showParkingList = false
    @State private var isSearchingParking = false
    // ---
    // --- New state for sheets ---
    @State private var showSettingsSheet = false
    @State private var showHistorySheet = false
    // ---
    // --- Error handling ---
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @Environment(\.isOnline) private var isOnline
    // ---
    // --- Deep link handling ---
    @Binding var deepLinkDestination: String?
    // ---
    
    init(deepLinkDestination: Binding<String?> = .constant(nil)) {
        self._deepLinkDestination = deepLinkDestination
    }
    
    var body: some View {
        ZStack {
            Map(position: $position) {
                UserAnnotation()
                if let parkedLocation = locationManager.parkedLocation {
                    Annotation("Parked Car", coordinate: parkedLocation.coordinate) {
                        ParkingAnnotationView(location: parkedLocation)
                    }
                }
                // --- Show parking search results as pins ---
                ForEach(parkingResults, id: \ .self) { item in
                    if let coordinate = item.placemark.location?.coordinate {
                        Annotation(item.name ?? "Parking", coordinate: coordinate) {
                            ZStack {
                                Circle().fill(Color.green).frame(width: 24, height: 24)
                                Image(systemName: "parkingsign.circle.fill")
                                    .foregroundColor(.white)
                                    .font(.system(size: 16))
                            }
                        }
                    }
                }
                // ---
            }
            .ignoresSafeArea()
            
            VStack {
                HeaderView()
                Spacer()
            }
            
            VStack {
                Spacer()
                HStack {
                    // --- Find Parking Nearby Button ---
                    Button(action: findParkingNearby) {
                        HStack(spacing: 6) {
                            Image(systemName: isSearchingParking ? "hourglass" : "parkingsign.circle")
                                .font(.system(size: 18, weight: .medium))
                            Text(isSearchingParking ? "Searching..." : "Find Parking Nearby")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .background(Color.green)
                        .cornerRadius(22)
                        .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
                    }
                    .disabled(isSearchingParking)
                    .padding(.leading, 20)
                    Spacer()
                    Button(action: centerOnUserLocation) {
                        Image(systemName: "location")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
                            .background(
                                Circle()
                                    .fill(Color.black.opacity(0.8))
                                    .shadow(color: .black.opacity(0.4), radius: 8, y: 4)
                            )
                    }
                }
                .padding(.trailing, 20)
                .padding(.bottom, 250)
            }
            
            VStack(spacing: 0) {
                Spacer()
                
                VStack(spacing: 0) {
                    if selectedTab == 0 {
                        BottomCard(
                            locationManager: locationManager,
                            showingFloorPicker: $showingFloorPicker,
                            detectedGarageName: $detectedGarageName,
                            isDetectingGarage: $isDetectingGarage
                        )
                    }
                    Divider()
                    TabBarView(selectedTab: $selectedTab)
                }
                .background(
                    Color(.systemBackground)
                        .cornerRadius(28, corners: [.topLeft, .topRight])
                        .shadow(color: .black.opacity(0.1), radius: 25, y: -10)
                        .edgesIgnoringSafeArea(.bottom)
                )
            }
            
            if showingFloorPicker {
                FloorPickerView(
                    showingFloorPicker: $showingFloorPicker,
                    locationManager: locationManager,
                    garageName: detectedGarageName ?? "Parking Garage"
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(2)
            }
            // --- Parking Results List Sheet ---
            if showParkingList {
                VStack {
                    Spacer()
                    VStack(spacing: 0) {
                        Capsule().fill(Color.gray.opacity(0.2)).frame(width: 40, height: 5).padding(.top, 8)
                        HStack {
                            Text("Nearby Parking Lots")
                                .font(.headline)
                                .padding(.leading, 16)
                            Spacer()
                            Button(action: { showParkingList = false }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 22))
                                    .foregroundColor(.gray)
                                    .padding(.trailing, 16)
                            }
                        }
                        .padding(.vertical, 8)
                        Divider()
                        ScrollView {
                            VStack(alignment: .leading, spacing: 0) {
                                ForEach(parkingResults, id: \ .self) { item in
                                    VStack(spacing: 0) {
                                        Button(action: {
                                            if let coordinate = item.placemark.location?.coordinate {
                                                withAnimation {
                                                    position = .region(MKCoordinateRegion(
                                                        center: coordinate,
                                                        span: MKCoordinateSpan(latitudeDelta: 0.003, longitudeDelta: 0.003)
                                                    ))
                                                }
                                                showParkingList = false
                                            }
                                        }) {
                                            HStack(alignment: .top, spacing: 12) {
                                                Image(systemName: "parkingsign.circle.fill")
                                                    .font(.system(size: 24))
                                                    .foregroundColor(.green)
                                                                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(item.name ?? "Parking")
                                                    .font(.system(size: 16, weight: .semibold))
                                                if let address = item.placemark.title {
                                                    Text(address)
                                                        .font(.system(size: 13))
                                                        .foregroundColor(.secondary)
                                                }
                                                if let userLocation = locationManager.currentLocation,
                                                   let parkingCoordinate = item.placemark.location?.coordinate {
                                                    let distance = userLocation.distance(from: CLLocation(latitude: parkingCoordinate.latitude, longitude: parkingCoordinate.longitude))
                                                    Text(formatDistance(distance))
                                                        .font(.system(size: 12))
                                                        .foregroundColor(.blue)
                                                }
                                            }
                                                Spacer()
                                            }
                                            .padding(.vertical, 10)
                                            .padding(.horizontal, 16)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                        
                                        // Navigation button
                                        if let coordinate = item.placemark.location?.coordinate {
                                            HStack(spacing: 8) {
                                                Button(action: {
                                                    navigateToParking(item: item, coordinate: coordinate)
                                                }) {
                                                    HStack(spacing: 6) {
                                                        Image(systemName: "location.fill")
                                                            .font(.system(size: 14))
                                                        Text("Navigate")
                                                            .font(.system(size: 14, weight: .medium))
                                                    }
                                                    .foregroundColor(.blue)
                                                    .padding(.horizontal, 12)
                                                    .padding(.vertical, 6)
                                                    .background(Color.blue.opacity(0.1))
                                                    .cornerRadius(8)
                                                }
                                                
                                                Spacer()
                                            }
                                            .padding(.horizontal, 16)
                                            .padding(.bottom, 10)
                                        }
                                    }
                                    Divider()
                                }
                                if parkingResults.isEmpty {
                                    Text("No parking lots found nearby.")
                                        .font(.system(size: 15))
                                        .foregroundColor(.secondary)
                                        .padding(24)
                                }
                            }
                        }
                    }
                    .background(Color(.systemBackground))
                    .cornerRadius(24, corners: [.topLeft, .topRight])
                    .shadow(radius: 20)
                }
                .edgesIgnoringSafeArea(.bottom)
                .transition(.move(edge: .bottom))
                .zIndex(10)
            }
            // ---
        }
        .sheet(isPresented: $showSettingsSheet, onDismiss: { selectedTab = 0 }) {
            SettingsView(locationManager: locationManager, selectedTab: $selectedTab)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showHistorySheet, onDismiss: { selectedTab = 0 }) {
            HistoryView(locationManager: locationManager, selectedTab: $selectedTab)
                .presentationDetents([.medium, .large])
        }
        .onChange(of: selectedTab) { newValue in
            if newValue == 2 {
                showSettingsSheet = true
            } else {
                showSettingsSheet = false
            }
            if newValue == 1 {
                showHistorySheet = true
            } else {
                showHistorySheet = false
            }
        }
        .animation(.spring(dampingFraction: 0.8), value: showingFloorPicker)
        .animation(.easeInOut(duration: 0.2), value: selectedTab)
        .onAppear {
            locationManager.requestLocationPermission()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("GoBackToParking"))) { _ in
            withAnimation(.easeOut(duration: 0.3)) {
                selectedTab = 0
            }
        }
        .alert("Error", isPresented: $showErrorAlert) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .onChange(of: isOnline) { online in
            if !online {
                errorMessage = "You're offline. Some features may not work properly."
                showErrorAlert = true
            }
        }
        .onChange(of: deepLinkDestination) { destination in
            if let destination = destination {
                // Handle deep link
                switch destination {
                case "parking":
                    // Widget tapped - ensure we're on the main parking view
                    selectedTab = 0
                    // Center on parked location if available
                    if let parkedLocation = locationManager.parkedLocation {
                        withAnimation(.easeInOut(duration: 0.8)) {
                            position = .region(MKCoordinateRegion(
                                center: parkedLocation.coordinate,
                                span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
                            ))
                        }
                    }
                default:
                    break
                }
                // Clear the deep link destination
                deepLinkDestination = nil
            }
        }
        .alert("Location Error", isPresented: Binding<Bool>(
            get: { locationManager.locationPermissionError != nil },
            set: { newValue in
                if !newValue { locationManager.locationPermissionError = nil }
            })
        ) {
            Button("OK") { locationManager.locationPermissionError = nil }
        } message: {
            Text(locationManager.locationPermissionError ?? "")
        }
    }
    
    // --- Find Parking Nearby Logic ---
    private func findParkingNearby() {
        guard let userLocation = locationManager.currentLocation else { 
            errorMessage = "Unable to get your location. Please check your location settings."
            showErrorAlert = true
            return 
        }
        
        if !isOnline {
            errorMessage = "You're offline. Parking search requires an internet connection."
            showErrorAlert = true
            return
        }
        
        isSearchingParking = true
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = "parking"
        request.region = MKCoordinateRegion(center: userLocation.coordinate, span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
        let search = MKLocalSearch(request: request)
        search.start { response, error in
            isSearchingParking = false
            if let error = error {
                errorMessage = "Failed to find parking: \(error.localizedDescription)"
                showErrorAlert = true
                return
            }
            
            if let items = response?.mapItems {
                // Sort by distance from user location
                let sortedItems = items.sorted { item1, item2 in
                    guard let coord1 = item1.placemark.location?.coordinate,
                          let coord2 = item2.placemark.location?.coordinate else { return false }
                    
                    let distance1 = userLocation.distance(from: CLLocation(latitude: coord1.latitude, longitude: coord1.longitude))
                    let distance2 = userLocation.distance(from: CLLocation(latitude: coord2.latitude, longitude: coord2.longitude))
                    
                    return distance1 < distance2
                }
                parkingResults = sortedItems
                showParkingList = true
            } else {
                parkingResults = []
                showParkingList = true
            }
        }
    }
    
    // --- Distance formatting helper ---
    private func formatDistance(_ distance: CLLocationDistance) -> String {
        let miles = distance * 0.000621371 // Convert meters to miles
        if miles < 0.1 {
            return "\(Int(distance))ft away"
        } else {
            return String(format: "%.1f miles away", miles)
        }
    }
    
    // --- Navigation to Parking Logic ---
    private func navigateToParking(item: MKMapItem, coordinate: CLLocationCoordinate2D) {
        // Create a map item for the parking location
        let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        mapItem.name = item.name ?? "Parking"
        
        // Set launch options for driving directions
        let launchOptions = [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving]
        
        // Open in Apple Maps
        mapItem.openInMaps(launchOptions: launchOptions)
        
        // Close the parking list
        showParkingList = false
        
        // Provide haptic feedback
        HapticManager.lightImpact()
    }
    // ---
    
    private func centerOnUserLocation() {
        guard let location = locationManager.currentLocation else { return }
        HapticManager.lightImpact()
        withAnimation(.easeInOut(duration: 0.8)) {
            position = .region(MKCoordinateRegion(
                center: location.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
            ))
        }
    }
}

#Preview {
    ContentView()
}
