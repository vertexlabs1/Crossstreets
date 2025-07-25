import SwiftUI
import MapKit

struct ContentView: View {
    @StateObject private var locationManager = LocationManager()
    @State private var position: MapCameraPosition = .automatic
    @State private var showingFloorPicker = false
    @State private var detectedGarageName: String?
    @State private var selectedTab = 0

    // New state for sheets
    @State private var showSettingsSheet = false
    @State private var showHistorySheet = false
    
    // Error handling
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    
    // Deep link handling
    @Binding var deepLinkDestination: String?
    
    // Prevent multiple logging
    @State private var hasLoggedInitialization = false
    
    // Throttle for detectedGarageInfo updates
    @State private var lastGarageInfoUpdate: Date = Date.distantPast
    
    // Debounce for location updates to prevent excessive recomputations
    @State private var lastLocationUpdate: Date = Date.distantPast
    
    // Only print initialization log once per app launch
    static var hasPrintedInit = false
    
    init(deepLinkDestination: Binding<String?> = .constant(nil)) {
        self._deepLinkDestination = deepLinkDestination
        if !ContentView.hasPrintedInit {
            #if DEBUG
            print("🚀 ContentView initialized at \(Date())")
            #endif
            ContentView.hasPrintedInit = true
        }
    }
    
    var body: some View {
        #if DEBUG
        let _ = print("🗺️ ContentView body computed")
        #endif
        ZStack {
            Map(position: $position) {
                UserAnnotation()
                if let parkedLocation = locationManager.parkedLocation {
                    Annotation("Parked Car", coordinate: parkedLocation.coordinate) {
                        ParkingAnnotationView(location: parkedLocation)
                    }
                }
            }
            .mapStyle(.standard)
            .mapControls { 
                MapUserLocationButton()
                MapCompass() 
            }
            .ignoresSafeArea()
            .onAppear {
                #if DEBUG
                print("🗺️ Map view appeared at \(Date())")
                #endif
                // Only log once per session
                if !hasLoggedInitialization {
                    hasLoggedInitialization = true
                    PerformanceMonitor.shared.startAction("app_launch")
                }
            }
            .onChange(of: locationManager.currentLocation) { _, newLocation in
                // Debounce location updates to prevent excessive view rebuilds
                let now = Date()
                guard now.timeIntervalSince(lastLocationUpdate) >= 1.0 else { return }
                lastLocationUpdate = now
                
                if let location = newLocation {
                    centerMapOnUser(location: location)
                }
            }
            
            VStack {
                Spacer()
                
                VStack(spacing: 0) {
                    if selectedTab == 0 {
                        BottomCard(
                            locationManager: locationManager,
                            showingFloorPicker: $showingFloorPicker,
                            detectedGarageName: $detectedGarageName
                        )
                    }
                    Divider()
                    TabBarView(
                        selectedTab: $selectedTab,
                        showHistorySheet: $showHistorySheet,
                        showSettingsSheet: $showSettingsSheet
                    )
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
        }
        .sheet(isPresented: $showHistorySheet) {
            HistoryView(locationManager: locationManager, selectedTab: $selectedTab)
        }
        .sheet(isPresented: $showSettingsSheet) {
            SettingsView(locationManager: locationManager, selectedTab: $selectedTab)
        }
        .alert("Error", isPresented: $showErrorAlert) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            // Request location permission on app launch
            locationManager.requestLocationPermission()
        }
        .onChange(of: locationManager.detectedGarageInfo) { _, newGarageInfo in
            // Throttle updates to prevent excessive view rebuilds
            let now = Date()
            if now.timeIntervalSince(lastGarageInfoUpdate) >= 1.0 {
                lastGarageInfoUpdate = now
                detectedGarageName = newGarageInfo?.garageName
                
                if newGarageInfo?.isInGarage == true {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showingFloorPicker = true
                    }
                }
            }
        }
        .onChange(of: locationManager.locationPermissionError) { _, error in
            if let error = error {
                errorMessage = error
                showErrorAlert = true
            }
        }
    }
    
    private func centerMapOnUser(location: CLLocation) {
        // Start performance monitoring
        PerformanceMonitor.shared.startAction("center_on_user")
        
        withAnimation(.easeInOut(duration: 0.8)) {
            position = .region(MKCoordinateRegion(
                center: location.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
            ))
        }
        
        // End performance monitoring after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            PerformanceMonitor.shared.endAction("center_on_user", screen: "main", success: true)
        }
    }
}

#Preview {
    ContentView()
}

