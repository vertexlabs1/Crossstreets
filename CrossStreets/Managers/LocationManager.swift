import Foundation
import CoreLocation
import MapKit
import UIKit
import UserNotifications
import SwiftUI // Added for @AppStorage
import Network // Added for NWPathMonitor

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    @Published var currentLocation: CLLocation?
    @Published var parkedLocation: ParkingLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isLocationEnabled = false
    @Published var locationPermissionError: String? = nil
    @Published var isDetectingParking = false
    
    private var detectedGarageInfo: (Bool, String?)? = nil
    
    // Local storage for garage floor corrections
    private let correctionsKey = "garageFloorCorrections"
    private let issuesKey = "userReportedIssues"
    private let altitudeDataKey = "garageAltitudeData"
    private var floorCorrections: [String: [String: Int]] = [:] // [garageName: [floor: count]]
    private var userIssues: [UserIssue] = []
    private var garageAltitudeData: [String: GarageAltitudeData] = [:] // [garageName: altitudeData]
    
    struct UserIssue: Codable {
        let id: UUID
        let timestamp: Date
        let location: CLLocationCoordinate2D
        var address: String
        let notes: String
        let issueType: String // "floor_correction", "general_issue", "feature_request", etc.
    }
    
    struct GarageAltitudeData: Codable {
        let garageName: String
        var floorElevations: [String: Double] // [floor: altitude]
        var totalCorrections: Int
        var lastUpdated: Date
        let gpsAccuracy: Double
        let barometricAvailable: Bool
    }
    
    struct FloorDetectionMetadata: Codable {
        let timestamp: Date
        let garageName: String
        let detectedFloor: String
        let actualFloor: String
        let altitude: Double
        let gpsAccuracy: Double
        let barometricPressure: Double?
        let wasCorrect: Bool
        let location: CLLocationCoordinate2D
        let address: String
    }
    
    override init() {
        super.init()
        setupLocationManager()
        loadParkedLocation()
        loadFloorCorrections()
        loadUserIssues()
        loadAltitudeData()
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        locationManager.distanceFilter = 25
    }
    
    private func formatCoordinatesNicely(_ coordinate: CLLocationCoordinate2D) -> String {
        let latDirection = coordinate.latitude >= 0 ? "N" : "S"
        let lonDirection = coordinate.longitude >= 0 ? "E" : "W"
        let lat = String(format: "%.2f°%@", abs(coordinate.latitude), latDirection)
        let lon = String(format: "%.2f°%@", abs(coordinate.longitude), lonDirection)
        return "\(lat), \(lon)"
    }
    
    private func getSmartAddress(for coordinate: CLLocationCoordinate2D, completion: @escaping (String) -> Void) {
        let niceCoordinates = formatCoordinatesNicely(coordinate)
        
        // Start with a more user-friendly initial message
        completion("Getting address...")
        
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let geocoder = CLGeocoder()
        var hasCompleted = false
        
        // Shorter timeout for better responsiveness
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            if !hasCompleted {
                hasCompleted = true
                completion(niceCoordinates)
            }
        }
        
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            guard !hasCompleted else { return }
            hasCompleted = true
            var address = niceCoordinates
            if let placemark = placemarks?.first, error == nil {
                if let name = placemark.name, !name.isEmpty {
                    address = name
                } else if let thoroughfare = placemark.thoroughfare {
                    if let subThoroughfare = placemark.subThoroughfare {
                        address = "\(subThoroughfare) \(thoroughfare)"
                    } else {
                        address = thoroughfare
                    }
                } else if let locality = placemark.locality {
                    address = locality
                }
                self?.checkForNearbyStores(at: location) { nearbyStore in
                    if let store = nearbyStore {
                        completion("Near \(store)")
                    } else {
                        completion(address)
                    }
                }
            } else {
                self?.checkForNearbyStores(at: location) { nearbyStore in
                    if let store = nearbyStore {
                        completion("Near \(store)")
                    } else {
                        completion(address)
                    }
                }
            }
        }
    }
    
    private func checkForNearbyStores(at location: CLLocation, completion: @escaping (String?) -> Void) {
        // First, search specifically for malls and shopping centers
        let mallSearchRequest = MKLocalSearch.Request()
        mallSearchRequest.naturalLanguageQuery = "mall shopping center plaza outlet"
        mallSearchRequest.region = MKCoordinateRegion(
            center: location.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.002, longitudeDelta: 0.002)
        )
        let mallSearch = MKLocalSearch(request: mallSearchRequest)
        mallSearch.start { mallResponse, mallError in
            if let mallResponse = mallResponse {
                for mallItem in mallResponse.mapItems {
                    let distance = location.distance(from: mallItem.placemark.location ?? CLLocation())
                    if distance <= 500 { // Increased range for malls
                        let name = mallItem.name?.lowercased() ?? ""
                        // Check if it's actually a mall/shopping center
                        let mallKeywords = ["mall", "shopping center", "shopping centre", "plaza", "outlet", "galleria", "marketplace", "town center", "town centre"]
                        for keyword in mallKeywords {
                            if name.contains(keyword) {
                                completion("Near \(mallItem.name ?? "Shopping Center")")
                                return
                            }
                        }
                    }
                }
            }
            
            // If no mall found, don't show individual stores
            completion(nil)
        }
    }
    
    func requestLocationPermission() {
        // Move location services check to background queue to prevent UI blocking
        DispatchQueue.global(qos: .userInitiated).async {
            let locationServicesEnabled = CLLocationManager.locationServicesEnabled()
            
            DispatchQueue.main.async {
                guard locationServicesEnabled else {
                    self.showLocationServicesAlert()
                    self.locationPermissionError = "Location Services are disabled. Please enable them in Settings."
                    return
                }
                
                // Use the current authorization status from our published property instead of calling it directly
                switch self.authorizationStatus {
                case .notDetermined:
                    // Move the authorization request to background queue to prevent UI blocking
                    DispatchQueue.global(qos: .userInitiated).async {
                        self.locationManager.requestWhenInUseAuthorization()
                    }
                case .authorizedWhenInUse, .authorizedAlways:
                    self.locationManager.startUpdatingLocation()
                    self.isLocationEnabled = true
                    self.locationPermissionError = nil
                case .denied, .restricted:
                    self.isLocationEnabled = false
                    self.showLocationPermissionAlert()
                    self.locationPermissionError = "Location permission denied. Please enable location access in Settings."
                @unknown default:
                    break
                }
            }
        }
    }
    
    private func showLocationServicesAlert() {
        let content = UNMutableNotificationContent()
        content.title = "Location Services Disabled"
        content.body = "Please enable Location Services in Settings to use CrossStreets."
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: "locationServices", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
    
    private func showLocationPermissionAlert() {
        let content = UNMutableNotificationContent()
        content.title = "Location Permission Required"
        content.body = "CrossStreets needs location access to help you find your parked car. Please enable in Settings."
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: "locationPermission", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
    
    func requestLocation() {
        // Ensure this runs on the main thread as it's a UI-triggered action
        DispatchQueue.main.async {
            self.locationManager.requestLocation()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        DispatchQueue.main.async { [weak self] in
            self?.currentLocation = location
            self?.optimizeLocationAccuracy()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager failed with error: \(error.localizedDescription)")
        
        DispatchQueue.main.async {
            if let clError = error as? CLError {
                switch clError.code {
                case .denied:
                    self.isLocationEnabled = false
                    self.showLocationPermissionAlert()
                    self.locationPermissionError = "Location permission denied. Please enable location access in Settings."
                case .locationUnknown:
                    // Temporary error, will retry
                    break
                case .network:
                    // Network error, will retry
                    break
                default:
                    self.isLocationEnabled = false
                }
            } else {
                self.isLocationEnabled = false
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        DispatchQueue.main.async {
            switch status {
            case .authorizedWhenInUse, .authorizedAlways:
                self.isLocationEnabled = true
                self.locationManager.startUpdatingLocation()
                self.cleanupOldData() // Clean up old data when location is enabled
                self.locationPermissionError = nil
            case .denied, .restricted:
                self.isLocationEnabled = false
                self.showLocationPermissionAlert()
                self.locationPermissionError = "Location permission denied. Please enable location access in Settings."
            case .notDetermined:
                self.isLocationEnabled = false
            @unknown default:
                self.isLocationEnabled = false
            }
        }
    }
    
    func detectParkingType(completion: @escaping () -> Void = {}) {
        print("🚗 Starting parking detection...")
        print("🔍 DEBUG: Button pressed - detectParkingType called")
        debugLocationStatus()
        isDetectingParking = true
        
        // Reduced global timeout for faster response
        let globalTimeout = DispatchTime.now() + 6.0 // Reduced from 10s to 6s
        
        DispatchQueue.main.asyncAfter(deadline: globalTimeout) { [weak self] in
            guard let self = self, self.isDetectingParking else { return }
            print("⚠️ Parking detection timed out globally")
            self.isDetectingParking = false
            self.saveParkedLocation(floor: nil)
            self.detectedGarageInfo = (false, nil)
            completion()
        }
        
        guard let currentLocation = currentLocation else {
            print("❌ currentLocation is nil - this is the issue!")
            isDetectingParking = false
            completion()
            return
        }
        
        // Check network connectivity first
        let isOnline = checkNetworkConnectivity()
        
        if !isOnline {
            print("❌ No network connectivity - parking directly")
            self.isDetectingParking = false
            self.saveParkedLocation(floor: nil)
            self.detectedGarageInfo = (false, nil)
            completion()
            return
        }
        
        // Reduced detection timeout for faster response
        let detectionTimeout = DispatchTime.now() + 4.0 // Reduced from 8s to 4s
        
        DispatchQueue.main.asyncAfter(deadline: detectionTimeout) { [weak self] in
            guard let self = self, self.isDetectingParking else { return }
            print("⏱️ Garage detection timed out, parking directly")
            self.isDetectingParking = false
            self.saveParkedLocation(floor: nil)
            self.detectedGarageInfo = (false, nil)
            completion()
        }
        
        // Start garage detection with faster search
        self.checkForParkingGarage(at: currentLocation) { [weak self] isInGarage, garageName in
            guard let self = self, self.isDetectingParking else { return }
            
            print("🏢 Garage detection result: \(isInGarage ? "Found" : "Not found") - \(garageName ?? "None")")
            
            self.isDetectingParking = false
            if isInGarage {
                self.detectedGarageInfo = (true, garageName)
                self.sendGarageFloorNotification(garageName: garageName)
            } else {
                // FALLBACK: Check if we're in a dense urban area that might have parking
                let isUrbanArea = self.isInUrbanArea(at: currentLocation)
                if isUrbanArea {
                    print("🏙️ Urban area detected - offering floor selection as fallback")
                    self.detectedGarageInfo = (true, "Urban Parking Area")
                    self.sendGarageFloorNotification(garageName: "Urban Parking Area")
                } else {
                    self.saveParkedLocation(floor: nil)
                    self.detectedGarageInfo = (false, nil)
                }
            }
            completion()
        }
    }
    
    private func isInUrbanArea(at location: CLLocation) -> Bool {
        // Simple heuristic: check if we're in a city with dense development
        // This is a basic implementation - could be enhanced with more sophisticated urban detection
        
        // For now, we'll use a conservative approach:
        // If we're in a location that has multiple nearby POIs, it's likely urban
        let searchRequest = MKLocalSearch.Request()
        searchRequest.naturalLanguageQuery = "business"
        searchRequest.region = MKCoordinateRegion(
            center: location.coordinate,
            latitudinalMeters: 200, // 200m radius
            longitudinalMeters: 200
        )
        
        let search = MKLocalSearch(request: searchRequest)
        var isUrban = false
        let semaphore = DispatchSemaphore(value: 0)
        
        search.start { response, error in
            if let response = response, response.mapItems.count >= 3 {
                // If there are 3+ businesses in 200m radius, likely urban
                isUrban = true
            }
            semaphore.signal()
        }
        
        // Wait for a short time, default to false if timeout
        _ = semaphore.wait(timeout: .now() + 2.0)
        
        return isUrban
    }
    
    private func checkNetworkConnectivity() -> Bool {
        // More robust network check with timeout
        let monitor = NWPathMonitor()
        var isConnected = false
        let semaphore = DispatchSemaphore(value: 0)
        
        monitor.pathUpdateHandler = { (path: NWPath) in
            isConnected = path.status == .satisfied
            semaphore.signal()
        }
        
        let queue = DispatchQueue(label: "NetworkCheck")
        monitor.start(queue: queue)
        
        // Wait for a short time to get the network status
        let result = semaphore.wait(timeout: .now() + 1.0) // Reduced timeout to 1 second
        monitor.cancel()
        
        if result == .timedOut {
            print("⚠️ Network check timed out, assuming offline")
            return false
        }
        
        print("🌐 Network check completed: \(isConnected ? "Online" : "Offline")")
        return isConnected
    }
    
    // MARK: - Performance Optimizations
    
    private func optimizeLocationAccuracy() {
        guard currentLocation != nil else { return }
        
        // Reduce location accuracy for better performance when not actively parking
        if parkedLocation == nil {
            locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        } else {
            locationManager.desiredAccuracy = kCLLocationAccuracyBest
        }
    }
    
    private func cleanupOldData() {
        // Clean up old parking history (keep last 30 days)
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        
        if let history = UserDefaults.standard.array(forKey: "parkingHistory") as? [[String: Any]] {
            let filteredHistory = history.filter { entry in
                if let timestamp = entry["timestamp"] as? Date {
                    return timestamp > thirtyDaysAgo
                }
                return true
            }
            UserDefaults.standard.set(filteredHistory, forKey: "parkingHistory")
        }
    }
    
    private func checkForParkingGarage(at location: CLLocation, completion: @escaping (Bool, String?) -> Void) {
        print("🔍 Starting garage search...")
        
        // Add a flag to ensure completion is only called once
        var garageSearchCompleted = false
        
        func completeOnce(_ found: Bool, _ name: String?) {
            if !garageSearchCompleted {
                garageSearchCompleted = true
                completion(found, name)
            }
        }
        
        // Reduced timeout for faster response
        let searchTimeout = DispatchTime.now() + 3.0 // Reduced from 6s to 3s
        
        performParkingSearch(at: location, query: "parking garage") { found, name in
            print("🔍 'parking garage' search result: \(found ? "Found" : "Not found") - \(name ?? "None")")
            if found {
                completeOnce(true, name)
            } else {
                self.performParkingSearch(at: location, query: "parking") { found2, name2 in
                    print("🔍 'parking' search result: \(found2 ? "Found" : "Not found") - \(name2 ?? "None")")
                    if found2 {
                        completeOnce(true, name2)
                    } else {
                        // Skip the third search for speed - just complete
                        print("🔍 Skipping third search for speed")
                        completeOnce(false, nil)
                    }
                }
            }
        }
        
        // Fallback timeout
        DispatchQueue.main.asyncAfter(deadline: searchTimeout) {
            print("⚠️ Garage search timed out, completing with no garage found")
            completeOnce(false, nil)
        }
    }
    
    private func performParkingSearch(at location: CLLocation, query: String, completion: @escaping (Bool, String?) -> Void) {
        print("🔍 Performing search for: '\(query)'")
        performParkingSearchWithRetry(at: location, query: query, retryCount: 0, completion: completion)
    }
    
    private func performParkingSearchWithRetry(at location: CLLocation, query: String, retryCount: Int, completion: @escaping (Bool, String?) -> Void) {
        print("🔍 Search attempt \(retryCount + 1) for '\(query)'")
        let searchRequest = MKLocalSearch.Request()
        searchRequest.naturalLanguageQuery = query
        searchRequest.region = MKCoordinateRegion(
            center: location.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
        )
        
        let search = MKLocalSearch(request: searchRequest)
        
        // Reduced timeout for faster response
        let searchTimeout = DispatchTime.now() + 2.0 // Reduced from 10s to 2s
        print("⏱️ Search timeout set to 2s")
        
        search.start { response, error in
            // Check timeout
            guard DispatchTime.now() <= searchTimeout else {
                print("⚠️ Parking search timed out for query: \(query)")
                completion(false, nil)
                return
            }
            
            guard let response = response, error == nil else {
                print("⚠️ Parking search failed for query '\(query)': \(error?.localizedDescription ?? "Unknown error")")
                completion(false, nil)
                return
            }
            
            print("🔍 Found \(response.mapItems.count) items for '\(query)'")
            
            // Debug: Log all found items for analysis
            for (index, item) in response.mapItems.enumerated() {
                let distance = location.distance(from: item.placemark.location ?? CLLocation())
                let category = item.pointOfInterestCategory?.rawValue ?? "unknown"
                print("🔍 Item \(index): '\(item.name ?? "unnamed")' at \(distance)m, category: \(category)")
            }
            
            for item in response.mapItems {
                let distance = location.distance(from: item.placemark.location ?? CLLocation())
                let name = item.name?.lowercased() ?? ""
                
                // IMPROVED: More flexible garage detection
                let isGarage = (distance <= 50) && // Increased from 30m to 50m
                    (
                        // Check for explicit garage keywords
                        name.contains("garage") || 
                        name.contains("structure") ||
                        name.contains("deck") ||
                        name.contains("lot") ||
                        name.contains("parking") ||
                        // Check if it's categorized as parking
                        item.pointOfInterestCategory == .parking ||
                        // Check for common parking facility patterns
                        name.contains("park") ||
                        name.contains("p&r") || // Park & Ride
                        name.contains("commuter") ||
                        // Check address patterns that suggest parking
                        (item.placemark.thoroughfare?.lowercased().contains("parking") == true) ||
                        (item.placemark.name?.lowercased().contains("parking") == true)
                    )
                
                if isGarage {
                    let formattedName = self.formatGarageName(for: item)
                    print("✅ Found garage: \(formattedName) at distance \(distance)m")
                    completion(true, formattedName)
                    return
                }
            }
            print("❌ No suitable garage found for '\(query)'")
            completion(false, nil)
        }
    }
    
    private func formatGarageName(for item: MKMapItem) -> String {
        var formattedName = item.name ?? ""
        
        // If the name already contains parking-related keywords, use it as-is
        if !formattedName.isEmpty &&
           (formattedName.lowercased().contains("garage") ||
            formattedName.lowercased().contains("deck") ||
            formattedName.lowercased().contains("parking") ||
            formattedName.lowercased().contains("structure") ||
            formattedName.lowercased().contains("center") ||
            formattedName.lowercased().contains("lot") ||
            formattedName.lowercased().contains("p&r") ||
            formattedName.lowercased().contains("commuter")) {
            return formattedName
        }
        
        // Try to create a meaningful name from the placemark
        let placemark = item.placemark
        if let street = placemark.thoroughfare, !street.isEmpty {
            if let number = placemark.subThoroughfare {
                formattedName = "\(number) \(street) Parking"
            } else {
                formattedName = "\(street) Parking"
            }
        } else if let name = placemark.name, !name.isEmpty {
            formattedName = name
            // Only add "Parking" if it doesn't already contain parking-related words
            if !formattedName.lowercased().contains("garage") &&
               !formattedName.lowercased().contains("deck") &&
               !formattedName.lowercased().contains("parking") &&
               !formattedName.lowercased().contains("lot") {
                formattedName = "\(formattedName) Parking"
            }
        } else {
            // Fallback: use nearby street name if available
            if let nearbyStreet = placemark.thoroughfare {
                formattedName = "\(nearbyStreet) Parking"
            } else {
                formattedName = "Parking Garage"
            }
        }
        
        return formattedName.isEmpty ? "Parking Garage" : formattedName
    }
    
    func setParkedLocation(_ location: ParkingLocation?) {
        DispatchQueue.main.async { [weak self] in
            self?.parkedLocation = location
        }
    }
    
    func saveParkedLocation(floor: String?) {
        guard let location = currentLocation else { return }
        let garageName = detectedGarageInfo?.1
        let parkingLocation = ParkingLocation(
            id: UUID(),
            coordinate: location.coordinate,
            address: "Getting address...", // Better initial state
            floor: floor,
            timestamp: Date(),
            garageName: garageName
        )
        setParkedLocation(parkingLocation)
        HapticManager.mediumImpact()
        
        // Get the smart address with better loading state
        getSmartAddress(for: location.coordinate) { [weak self] address in
            DispatchQueue.main.async {
                let updatedLocation = ParkingLocation(
                    id: parkingLocation.id,
                    coordinate: parkingLocation.coordinate,
                    address: address,
                    floor: parkingLocation.floor,
                    timestamp: parkingLocation.timestamp,
                    garageName: parkingLocation.garageName
                )
                self?.setParkedLocation(updatedLocation)
                self?.saveToUserDefaults(updatedLocation)
            }
        }
    }
    
    func updateFloor(_ floor: String) {
        guard let location = parkedLocation else { return }
        let updatedLocation = ParkingLocation(
            id: location.id,
            coordinate: location.coordinate,
            address: location.address,
            floor: floor,
            timestamp: location.timestamp,
            garageName: location.garageName
        )
        setParkedLocation(updatedLocation)
        saveToUserDefaults(updatedLocation)
    }
    
    func clearParkedLocation() {
        setParkedLocation(nil)
        UserDefaults.standard.removeObject(forKey: "parkedLocation")
        let sharedDefaults = UserDefaults(suiteName: "group.CC3YTPPQQJ.crossstreets")
        sharedDefaults?.removeObject(forKey: "parkedLocation")
        detectedGarageInfo = nil
        isDetectingParking = false
        HapticManager.lightImpact()
    }
    
    func getDirectionsToParkedCar() {
        guard let parkedLocation = parkedLocation else { return }
        let coordinate = parkedLocation.coordinate
        let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        mapItem.name = "My Car"
        let launchOptions = [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking]
        mapItem.openInMaps(launchOptions: launchOptions)
    }
    
    private func saveToUserDefaults(_ location: ParkingLocation) {
        if let encoded = try? JSONEncoder().encode(location) {
            UserDefaults.standard.set(encoded, forKey: "parkedLocation")
            let sharedDefaults = UserDefaults(suiteName: "group.CC3YTPPQQJ.crossstreets")
            sharedDefaults?.set(encoded, forKey: "parkedLocation")
        }
    }
    
    private func loadParkedLocation() {
        if let data = UserDefaults.standard.data(forKey: "parkedLocation"),
           let decoded = try? JSONDecoder().decode(ParkingLocation.self, from: data) {
            setParkedLocation(decoded)
        }
    }
    
    private func sendGarageFloorNotification(garageName: String?) {
        let content = UNMutableNotificationContent()
        content.title = "Select Your Parking Floor"
        if let name = garageName {
            content.body = "Tap to select your floor in \(name)"
        } else {
            content.body = "Tap to select your parking floor."
        }
        content.sound = .default
        let request = UNNotificationRequest(identifier: "selectFloor", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
    
    // Local storage for garage floor corrections
    private func loadFloorCorrections() {
        if let data = UserDefaults.standard.data(forKey: correctionsKey),
           let corrections = try? JSONDecoder().decode([String: [String: Int]].self, from: data) {
            floorCorrections = corrections
            print("📱 Loaded floor corrections for \(floorCorrections.count) garages")
        } else {
            print("📱 No floor corrections found in storage")
        }
    }
    
    private func saveFloorCorrections() {
        if let data = try? JSONEncoder().encode(floorCorrections) {
            UserDefaults.standard.set(data, forKey: correctionsKey)
            UserDefaults.standard.synchronize()
            print("💾 Saved floor corrections: \(floorCorrections.count) garages")
        } else {
            print("❌ Failed to encode floor corrections")
        }
    }
    
    private func loadUserIssues() {
        if let data = UserDefaults.standard.data(forKey: issuesKey),
           let issues = try? JSONDecoder().decode([UserIssue].self, from: data) {
            userIssues = issues
            print("📱 Loaded \(userIssues.count) user issues")
        } else {
            print("📱 No user issues found in storage")
        }
    }
    
    private func saveUserIssues() {
        if let data = try? JSONEncoder().encode(userIssues) {
            UserDefaults.standard.set(data, forKey: issuesKey)
            UserDefaults.standard.synchronize()
            print("💾 Saved \(userIssues.count) user issues")
        } else {
            print("❌ Failed to encode user issues")
        }
    }
    
    func recordFloorCorrection(garageName: String, floor: String) {
        if floorCorrections[garageName] == nil {
            floorCorrections[garageName] = [:]
        }
        floorCorrections[garageName]?[floor, default: 0] += 1
        saveFloorCorrections()
    }
    
    func logGarageDetectionFailure(location: CLLocation, notes: String = "") {
        let issue = UserIssue(
            id: UUID(),
            timestamp: Date(),
            location: location.coordinate,
            address: "Getting address...",
            notes: "Garage detection failed: \(notes)",
            issueType: "garage_detection_failure"
        )
        
        userIssues.append(issue)
        saveUserIssues()
        
        // Get address for context
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            let address = placemarks?.first?.name ?? "Unknown location"
            
            DispatchQueue.main.async {
                // Update the issue with the address
                if let index = self.userIssues.firstIndex(where: { $0.id == issue.id }) {
                    self.userIssues[index].address = address
                    self.saveUserIssues()
                }
            }
        }
        
        print("📊 Logged garage detection failure at \(location.coordinate)")
    }
    
    func clearAllFeedbackData() {
        // Clear floor corrections
        floorCorrections.removeAll()
        saveFloorCorrections()
        
        // Clear user issues
        userIssues.removeAll()
        saveUserIssues()
        
        // Clear altitude data
        garageAltitudeData.removeAll()
        saveAltitudeData()
        
        print("🗑️ Cleared all feedback data")
    }
    
    func logUserIssue(notes: String, issueType: String = "general_issue") {
        guard let currentLocation = currentLocation else {
            print("⚠️ Cannot log issue: No current location available")
            return
        }
        
        // Get current address for context
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(currentLocation) { placemarks, error in
            let address = placemarks?.first?.name ?? "Unknown location"
            
            let issue = UserIssue(
                id: UUID(),
                timestamp: Date(),
                location: currentLocation.coordinate,
                address: address,
                notes: notes,
                issueType: issueType
            )
            
            DispatchQueue.main.async {
                self.userIssues.append(issue)
                self.saveUserIssues()
                print("✅ Logged user issue: \(notes)")
            }
        }
    }
    
    func getFloorCorrectionCount(garageName: String, floor: String) -> Int {
        return floorCorrections[garageName, default: [:]][floor, default: 0]
    }
    
    func getGarageNames() -> [String] {
        return Array(floorCorrections.keys).sorted()
    }
    
    func getFloors(for garageName: String) -> [String] {
        return Array(floorCorrections[garageName, default: [:]].keys).sorted()
    }
    
    // Export correction data for analysis
    func exportCorrectionData() -> String {
        print("📊 Starting data export...")
        print("📊 Floor corrections: \(floorCorrections.count) garages")
        print("📊 User issues: \(userIssues.count) issues")
        print("📊 Altitude data: \(garageAltitudeData.count) garages")
        
        var export = "CrossStreets Feedback Data Export\n"
        export += "Generated: \(Date())\n"
        export += "Device: \(UIDevice.current.name)\n\n"
        
        // Floor Corrections Section
        export += "=== GARAGE FLOOR CORRECTIONS ===\n"
        if floorCorrections.isEmpty {
            export += "No floor corrections recorded yet.\n"
        } else {
            for (garageName, floors) in floorCorrections.sorted(by: { $0.key < $1.key }) {
                export += "Garage: \(garageName)\n"
                for (floor, count) in floors.sorted(by: { $0.key < $1.key }) {
                    export += "  Floor \(floor): \(count) corrections\n"
                }
                export += "\n"
            }
        }
        
        // Altitude Data Section
        export += "=== ALTITUDE-BASED FLOOR DETECTION DATA ===\n"
        if garageAltitudeData.isEmpty {
            export += "No altitude data recorded yet.\n"
        } else {
            for (garageName, altitudeData) in garageAltitudeData.sorted(by: { $0.key < $1.key }) {
                export += "Garage: \(garageName)\n"
                export += "  Total Corrections: \(altitudeData.totalCorrections)\n"
                export += "  Last Updated: \(altitudeData.lastUpdated)\n"
                export += "  GPS Accuracy: \(String(format: "%.1f", altitudeData.gpsAccuracy))m\n"
                export += "  Barometric Available: \(altitudeData.barometricAvailable ? "Yes" : "No")\n"
                export += "  Floor Elevations:\n"
                for (floor, elevation) in altitudeData.floorElevations.sorted(by: { $0.key < $1.key }) {
                    export += "    \(floor): \(String(format: "%.1f", elevation))m\n"
                }
                export += "\n"
            }
        }
        
        // User Issues Section
        export += "=== USER REPORTED ISSUES ===\n"
        if userIssues.isEmpty {
            export += "No user issues reported yet.\n"
        } else {
            for issue in userIssues.sorted(by: { $0.timestamp > $1.timestamp }) {
                export += "Issue ID: \(issue.id)\n"
                export += "Date: \(issue.timestamp)\n"
                export += "Type: \(issue.issueType)\n"
                export += "Location: \(issue.location.latitude), \(issue.location.longitude)\n"
                export += "Address: \(issue.address)\n"
                export += "Notes: \(issue.notes)\n"
                export += "---\n"
            }
        }
        
        // Summary Statistics
        let stats = getCorrectionStats()
        export += "\n=== SUMMARY STATISTICS ===\n"
        export += "Total garages with corrections: \(stats.totalGarages)\n"
        export += "Total floor corrections: \(stats.totalCorrections)\n"
        export += "Total user issues reported: \(userIssues.count)\n"
        export += "Total garages with altitude data: \(garageAltitudeData.count)\n"
        
        print("📊 Export completed: \(export.count) characters")
        return export
    }
    
    func getCorrectionStats() -> (totalGarages: Int, totalCorrections: Int) {
        let totalGarages = floorCorrections.count
        let totalCorrections = floorCorrections.values.flatMap { $0.values }.reduce(0, +)
        return (totalGarages, totalCorrections)
    }
    
    func getUserIssuesCount() -> Int {
        return userIssues.count
    }
    
    // MARK: - Altitude-Based Floor Detection
    
    func detectFloorForGarage(_ garageName: String) -> String? {
        guard let location = currentLocation else { return nil }
        
        // Get altitude with smart rounding
        let altitude = roundAltitude(location.altitude)
        
        // Check if we have existing data for this garage
        if let garageData = garageAltitudeData[garageName] {
            return predictFloorFromAltitude(altitude, garageData: garageData)
        }
        
        // No existing data, make educated guess based on common patterns
        return makeInitialFloorGuess(altitude: altitude, garageName: garageName)
    }
    
    private func roundAltitude(_ altitude: Double) -> Double {
        // Round to nearest 3 meters (typical floor height)
        return round(altitude / 3.0) * 3.0
    }
    
    private func predictFloorFromAltitude(_ altitude: Double, garageData: GarageAltitudeData) -> String? {
        var bestFloor: String?
        var smallestDifference = Double.infinity
        
        for (floor, floorAltitude) in garageData.floorElevations {
            let difference = abs(altitude - floorAltitude)
            if difference < smallestDifference {
                smallestDifference = difference
                bestFloor = floor
            }
        }
        
        // Only return prediction if difference is reasonable (within 6 meters)
        return smallestDifference <= 6.0 ? bestFloor : nil
    }
    
    private func makeInitialFloorGuess(altitude: Double, garageName: String) -> String {
        // Common garage patterns
        let lowerCaseName = garageName.lowercased()
        
        if lowerCaseName.contains("underground") || lowerCaseName.contains("basement") {
            return altitude < 0 ? "B1" : "G"
        } else if lowerCaseName.contains("ground") || lowerCaseName.contains("main") {
            return "G"
        } else if altitude < -5 {
            return "B1"
        } else if altitude < 0 {
            return "G"
        } else if altitude < 10 {
            return "F1"
        } else {
            return "F1"
        }
    }
    
    func logFloorDetectionResult(detectedFloor: String, actualFloor: String, garageName: String) {
        guard let location = currentLocation else { return }
        
        let altitude = roundAltitude(location.altitude)
        let wasCorrect = detectedFloor == actualFloor
        
        // Create metadata
        let metadata = FloorDetectionMetadata(
            timestamp: Date(),
            garageName: garageName,
            detectedFloor: detectedFloor,
            actualFloor: actualFloor,
            altitude: altitude,
            gpsAccuracy: location.verticalAccuracy,
            barometricPressure: nil, // TODO: Add barometric pressure if available
            wasCorrect: wasCorrect,
            location: location.coordinate,
            address: "Getting address..." // Will be updated later
        )
        
        // Update garage altitude data
        updateGarageAltitudeData(metadata: metadata)
        
        // Log for analysis
        print("📊 Floor Detection: \(detectedFloor) → \(actualFloor) (\(wasCorrect ? "✅" : "❌")) Altitude: \(altitude)m")
    }
    
    private func updateGarageAltitudeData(metadata: FloorDetectionMetadata) {
        if garageAltitudeData[metadata.garageName] == nil {
            garageAltitudeData[metadata.garageName] = GarageAltitudeData(
                garageName: metadata.garageName,
                floorElevations: [:],
                totalCorrections: 0,
                lastUpdated: Date(),
                gpsAccuracy: metadata.gpsAccuracy,
                barometricAvailable: metadata.barometricPressure != nil
            )
        }
        
        // Update floor elevation data
        garageAltitudeData[metadata.garageName]?.floorElevations[metadata.actualFloor] = metadata.altitude
        garageAltitudeData[metadata.garageName]?.totalCorrections += 1
        garageAltitudeData[metadata.garageName]?.lastUpdated = Date()
        
        // Save updated data
        saveAltitudeData()
    }
    
    private func loadAltitudeData() {
        if let data = UserDefaults.standard.data(forKey: altitudeDataKey),
           let altitudeData = try? JSONDecoder().decode([String: GarageAltitudeData].self, from: data) {
            garageAltitudeData = altitudeData
            print("📱 Loaded altitude data for \(garageAltitudeData.count) garages")
        } else {
            print("📱 No altitude data found in storage")
        }
    }
    
    private func saveAltitudeData() {
        if let data = try? JSONEncoder().encode(garageAltitudeData) {
            UserDefaults.standard.set(data, forKey: altitudeDataKey)
            UserDefaults.standard.synchronize()
            print("💾 Saved altitude data for \(garageAltitudeData.count) garages")
        } else {
            print("❌ Failed to encode altitude data")
        }
    }
    
    // Debug method to test location manager functionality
    func debugLocationStatus() {
        print("🔍 DEBUG: Location Manager Status")
        print("📍 Current Location: \(currentLocation?.coordinate.latitude ?? 0), \(currentLocation?.coordinate.longitude ?? 0)")
        print("📍 Location Accuracy: \(currentLocation?.horizontalAccuracy ?? 0)m")
        print("📍 Is Location Enabled: \(isLocationEnabled)")
        print("📍 Authorization Status: \(authorizationStatus.rawValue)")
        print("📍 Location Services Enabled: \(CLLocationManager.locationServicesEnabled())")
        print("📍 Is Detecting Parking: \(isDetectingParking)")
        print("📍 Parked Location: \(parkedLocation?.address ?? "None")")
    }
}
