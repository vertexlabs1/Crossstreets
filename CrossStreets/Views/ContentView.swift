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
    
    // Performance optimization: Cache map position to prevent unnecessary updates
    @State private var lastMapPosition: MapCameraPosition = .automatic
    
    // Only print initialization log once per app launch
    static var hasPrintedInit = false
    
    // Performance optimization: Throttle debug prints
    @State private var lastDebugPrint: Date = Date.distantPast
    
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
                MapScaleView()
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
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                print("🔄 App will enter foreground - refreshing location permissions")
                // Refresh location permissions when app comes back from background
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    locationManager.refreshLocationPermissions()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                print("🔄 App did become active - ensuring location services are running")
                // Ensure location services are properly running
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    locationManager.ensureLocationServicesRunning()
                }
            }
            
            VStack {
                Spacer()
                
                // Custom location button positioned above bottom card
                HStack {
                    Spacer()
                    Button(action: {
                        if let location = locationManager.currentLocation {
                            centerMapOnUser(location: location)
                        }
                    }) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.blue)
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 20)
                }
                
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
                    .background(Color(.systemBackground))
                    .ignoresSafeArea(.container, edges: .bottom)
                }
                .padding(.horizontal, 16)
                .background(
                    Color(.systemBackground)
                        .clipShape(
                            RoundedRectangle(cornerRadius: 28)
                                .offset(y: 50) // Extend background below visible area
                        )
                        .shadow(color: .black.opacity(0.1), radius: 25, y: -10)
                )
                .clipped()
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
        .onAppear {
            // Request location permission on app launch
            locationManager.requestLocationPermission()
            
            #if DEBUG
            // Throttle debug prints to reduce log spam
            let now = Date()
            if now.timeIntervalSince(lastDebugPrint) >= 5.0 {
                print("🗺️ ContentView body computed")
                lastDebugPrint = now
            }
            #endif
        }
        .sheet(isPresented: $showHistorySheet) {
            HistoryView(locationManager: locationManager, selectedTab: $selectedTab)
        }
        .onChange(of: showHistorySheet) { _, isShowing in
            if !isShowing {
                selectedTab = 0 // Return to Parking tab when sheet is dismissed
            }
        }
        .sheet(isPresented: $showSettingsSheet) {
            SettingsView(locationManager: locationManager, selectedTab: $selectedTab)
        }
        .onChange(of: showSettingsSheet) { _, isShowing in
            if !isShowing {
                selectedTab = 0 // Return to Parking tab when sheet is dismissed
            }
        }
        .alert("Error", isPresented: $showErrorAlert) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
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

