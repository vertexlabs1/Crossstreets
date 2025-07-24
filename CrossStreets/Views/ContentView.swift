import SwiftUI
import MapKit

struct ContentView: View {
    let locationManager: LocationManager
    @State private var position: MapCameraPosition = .automatic
    @State private var showingFloorPicker = false
    @State private var detectedGarageName: String?
    @State private var selectedTab = 0

    // --- New state for sheets ---
    @State private var showSettingsSheet = false
    @State private var showHistorySheet = false
    // ---
    // --- Error handling ---
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    // Network status handled at app level - removed environment dependency
    // ---
    // --- Deep link handling ---
    @Binding var deepLinkDestination: String?
    // ---
    // --- Prevent multiple logging ---
    @State private var hasLoggedInitialization = false
    // ---
    // Throttle for detectedGarageInfo updates
    @State private var lastGarageInfoUpdate: Date = Date.distantPast
    
    // Only print initialization log once per app launch
    static var hasPrintedInit = false
    
    init(locationManager: LocationManager, deepLinkDestination: Binding<String?> = .constant(nil)) {
        self.locationManager = locationManager
        self._deepLinkDestination = deepLinkDestination
        if !ContentView.hasPrintedInit {
            print("🚀 ContentView initialized at \(Date())")
            ContentView.hasPrintedInit = true
        }
    }
    
    var body: some View {
        let _ = print("🗺️ ContentView body computed")
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
                print("🗺️ Map view appeared at \(Date())")
                // Only log once per session
                if !hasLoggedInitialization {
                    hasLoggedInitialization = true
                    SupabaseManager.shared.logUserAction(
                        action: "map_appeared",
                        screen: "main",
                        success: true
                    ) { _ in }
                }
            }
            // REMOVED: This onChange was causing infinite loops
            // Garage detection is now handled directly in the location manager
            
            VStack {
                HeaderView()
                Spacer()
            }
            
            VStack {
                Spacer()
                HStack {
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
        .sheet(isPresented: $showSettingsSheet, onDismiss: { 
            selectedTab = 0
            showSettingsSheet = false
        }) {
            SettingsView(locationManager: locationManager, selectedTab: $selectedTab)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showHistorySheet, onDismiss: { 
            selectedTab = 0
            showHistorySheet = false
        }) {
            HistoryView(locationManager: locationManager, selectedTab: $selectedTab)
                .presentationDetents([.medium, .large])
        }
        // Tab changes handled directly in TabBarView - removed onChange to prevent circular dependency
        .animation(.spring(dampingFraction: 0.8), value: showingFloorPicker)
        .animation(.easeInOut(duration: 0.2), value: selectedTab)
        .onAppear {
            locationManager.requestLocationPermission()
            
            // Log view initialization only once
            if !hasLoggedInitialization {
                hasLoggedInitialization = true
                SupabaseManager.shared.logUserAction(
                    action: "view_initialized",
                    screen: "main",
                    success: true,
                    context: ["view": "ContentView"]
                ) { _ in }
            }
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
        // Network status handled at app level - removed onChange
        // REMOVE: This onChange might be causing the loop
        // .onChange(of: deepLinkDestination) { oldValue, destination in
        //     if let destination = destination {
        //         // Handle deep link
        //         switch destination {
        //         case "parking":
        //             // Widget tapped - ensure we're on the main parking view
        //             selectedTab = 0
        //             // Center on parked location if available
        //             if let parkedLocation = locationManager.parkedLocation {
        //                 withAnimation(.easeInOut(duration: 0.8)) {
        //                     position = .region(MKCoordinateRegion(
        //                         center: parkedLocation.coordinate,
        //                         span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
        //                     ))
        //                 }
        //             }
        //         default:
        //             break
        //         }
        //         // Clear the deep link destination
        //         deepLinkDestination = nil
        //     }
        // }
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
    

    
    private func centerOnUserLocation() {
        guard let location = locationManager.currentLocation else { return }
        
        // Start performance monitoring
        PerformanceMonitor.shared.startAction("center_on_user")
        
        HapticManager.lightImpact()
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
    ContentView(locationManager: LocationManager())
}
