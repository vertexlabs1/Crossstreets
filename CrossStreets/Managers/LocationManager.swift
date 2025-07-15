import Foundation
import CoreLocation
import MapKit
import UIKit
import UserNotifications
import SwiftUI // Added for @AppStorage

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    @Published var currentLocation: CLLocation?
    @Published var parkedLocation: ParkingLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isLocationEnabled = false
    @Published var locationPermissionError: String? = nil
    
    private var detectedGarageInfo: (Bool, String?)? = nil
    
    // Local storage for garage floor corrections
    private let correctionsKey = "garageFloorCorrections"
    private let issuesKey = "userReportedIssues"
    private var floorCorrections: [String: [String: Int]] = [:] // [garageName: [floor: count]]
    private var userIssues: [UserIssue] = []
    
    struct UserIssue: Codable {
        let id: UUID
        let timestamp: Date
        let location: CLLocationCoordinate2D
        let address: String
        let notes: String
        let issueType: String // "floor_correction", "general_issue", "feature_request", etc.
    }
    
    override init() {
        super.init()
        setupLocationManager()
        loadParkedLocation()
        loadFloorCorrections()
        loadUserIssues()
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
        completion(niceCoordinates)
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let geocoder = CLGeocoder()
        var hasCompleted = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            if !hasCompleted {
                hasCompleted = true
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
        let searchRequest = MKLocalSearch.Request()
        searchRequest.naturalLanguageQuery = "store restaurant shop"
        searchRequest.region = MKCoordinateRegion(
            center: location.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.002, longitudeDelta: 0.002)
        )
        let search = MKLocalSearch(request: searchRequest)
        search.start { response, error in
            guard let response = response, error == nil else {
                completion(nil)
                return
            }
            let nearbyItems = response.mapItems.filter { item in
                let distance = location.distance(from: item.placemark.location ?? CLLocation())
                return distance <= 200
            }.sorted { item1, item2 in
                let distance1 = location.distance(from: item1.placemark.location ?? CLLocation())
                let distance2 = location.distance(from: item2.placemark.location ?? CLLocation())
                return distance1 < distance2
            }
            let preferredKeywords = [
                "apple", "starbucks", "mcdonalds", "burger king", "wendys", "subway",
                "target", "walmart", "costco", "best buy", "home depot", "lowes",
                "cheesecake factory", "olive garden", "red lobster", "outback",
                "chili's", "tgi fridays", "buffalo wild wings", "chipotle",
                "panera", "dunkin", "dominos", "pizza hut", "kfc", "popeyes"
            ]
            for item in nearbyItems {
                let name = item.name?.lowercased() ?? ""
                for keyword in preferredKeywords {
                    if name.contains(keyword) {
                        completion(item.name)
                        return
                    }
                }
            }
            for item in nearbyItems {
                let category = item.pointOfInterestCategory
                if category == .store || category == .restaurant || category == .foodMarket {
                    completion(item.name)
                    return
                }
            }
            let mallSearchRequest = MKLocalSearch.Request()
            mallSearchRequest.naturalLanguageQuery = "mall shopping center"
            mallSearchRequest.region = MKCoordinateRegion(
                center: location.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.001, longitudeDelta: 0.001)
            )
            let mallSearch = MKLocalSearch(request: mallSearchRequest)
            mallSearch.start { mallResponse, mallError in
                if let mallResponse = mallResponse {
                    for mallItem in mallResponse.mapItems {
                        let distance = location.distance(from: mallItem.placemark.location ?? CLLocation())
                        if distance <= 300 {
                            completion(mallItem.name)
                            return
                        }
                    }
                }
                completion(nil)
            }
        }
    }
    
    func requestLocationPermission() {
        guard CLLocationManager.locationServicesEnabled() else {
            DispatchQueue.main.async {
                self.showLocationServicesAlert()
                self.locationPermissionError = "Location Services are disabled. Please enable them in Settings."
            }
            return
        }
        
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.startUpdatingLocation()
            DispatchQueue.main.async {
                self.isLocationEnabled = true
                self.locationPermissionError = nil
            }
        case .denied, .restricted:
            DispatchQueue.main.async {
                self.isLocationEnabled = false
                self.showLocationPermissionAlert()
                self.locationPermissionError = "Location permission denied. Please enable location access in Settings."
            }
        @unknown default:
            break
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
        locationManager.requestLocation()
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
    
    func detectParkingType() {
        guard let location = currentLocation else { 
            print("⚠️ Cannot detect parking: No current location available")
            return 
        }
        
        // Validate location accuracy
        guard location.horizontalAccuracy <= 100 else {
            print("⚠️ Location accuracy too low: \(location.horizontalAccuracy)m")
            return
        }
        
        // Check if we're online for map searches
        let isOnline = checkNetworkConnectivity()
        if !isOnline {
            print("⚠️ Offline mode: Using basic parking detection")
            // Fall back to basic parking detection without map search
            self.saveParkedLocation(floor: nil)
            self.detectedGarageInfo = (false, nil)
            return
        }
        
        // Add timeout for parking detection
        let detectionTimeout = DispatchTime.now() + 10.0 // 10 second timeout
        
        checkForParkingGarage(at: location) { [weak self] isInGarage, garageName in
            DispatchQueue.main.async {
                // Check if we're still within timeout
                guard DispatchTime.now() <= detectionTimeout else {
                    print("⚠️ Parking detection timed out")
                    return
                }
                
                if isInGarage {
                    self?.detectedGarageInfo = (true, garageName)
                    self?.sendGarageFloorNotification(garageName: garageName)
                } else {
                    self?.saveParkedLocation(floor: nil)
                    self?.detectedGarageInfo = (false, nil)
                }
            }
        }
    }
    
    private func checkNetworkConnectivity() -> Bool {
        // Simple network check - in a real app you'd use NWPathMonitor
        // For now, we'll assume online and let the search fail gracefully
        return true
    }
    
    // MARK: - Performance Optimizations
    
    private func optimizeLocationAccuracy() {
        guard let location = currentLocation else { return }
        
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
        performParkingSearch(at: location, query: "parking garage") { found, name in
            if found {
                completion(true, name)
            } else {
                self.performParkingSearch(at: location, query: "parking") { found2, name2 in
                    completion(found2, name2)
                }
            }
        }
    }
    
    private func performParkingSearch(at location: CLLocation, query: String, completion: @escaping (Bool, String?) -> Void) {
        performParkingSearchWithRetry(at: location, query: query, retryCount: 0, completion: completion)
    }
    
    private func performParkingSearchWithRetry(at location: CLLocation, query: String, retryCount: Int, completion: @escaping (Bool, String?) -> Void) {
        let searchRequest = MKLocalSearch.Request()
        searchRequest.naturalLanguageQuery = query
        searchRequest.region = MKCoordinateRegion(
            center: location.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.002, longitudeDelta: 0.002)
        )
        
        let search = MKLocalSearch(request: searchRequest)
        
        // Add timeout for search
        let searchTimeout = DispatchTime.now() + 8.0 // 8 second timeout
        
        search.start { response, error in
            // Check timeout
            guard DispatchTime.now() <= searchTimeout else {
                print("⚠️ Parking search timed out for query: \(query)")
                completion(false, nil)
                return
            }
            
            guard let response = response, error == nil else {
                print("⚠️ Parking search failed for query '\(query)': \(error?.localizedDescription ?? "Unknown error")")
                
                // Retry logic for network errors
                if retryCount < 2 {
                    print("🔄 Retrying parking search (attempt \(retryCount + 1))")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        self.performParkingSearchWithRetry(at: location, query: query, retryCount: retryCount + 1, completion: completion)
                    }
                    return
                }
                
                completion(false, nil)
                return
            }
            
            for item in response.mapItems {
                let distance = location.distance(from: item.placemark.location ?? CLLocation())
                if distance <= 75 {
                    let name = item.name ?? ""
                    let keywords = ["garage", "parking", "structure", "deck", "ramp", "lot", "park"]
                    let isGarage = keywords.contains { name.lowercased().contains($0) } ||
                                   item.pointOfInterestCategory == .parking
                    if isGarage {
                        let formattedName = self.formatGarageName(for: item)
                        completion(true, formattedName)
                        return
                    }
                }
            }
            completion(false, nil)
        }
    }
    
    private func formatGarageName(for item: MKMapItem) -> String {
        var formattedName = item.name ?? ""
        if !formattedName.isEmpty &&
           (formattedName.lowercased().contains("garage") ||
            formattedName.lowercased().contains("deck") ||
            formattedName.lowercased().contains("parking") ||
            formattedName.lowercased().contains("structure") ||
            formattedName.lowercased().contains("center")) {
            return formattedName
        }
        let placemark = item.placemark
        if let street = placemark.thoroughfare, !street.isEmpty {
            if let number = placemark.subThoroughfare {
                formattedName = "\(number) \(street) Garage"
            } else {
                formattedName = "\(street) Garage"
            }
        } else if let name = placemark.name, !name.isEmpty {
            formattedName = name
            if !formattedName.lowercased().contains("garage") &&
               !formattedName.lowercased().contains("deck") &&
               !formattedName.lowercased().contains("parking") {
                formattedName = "\(formattedName) Garage"
            }
        } else {
            formattedName = "Parking Garage"
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
            address: "Locating...",
            floor: floor,
            timestamp: Date(),
            garageName: garageName
        )
        setParkedLocation(parkingLocation)
        HapticManager.mediumImpact()
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
        let sharedDefaults = UserDefaults(suiteName: "group.com.tyler.crossstreets")
        sharedDefaults?.removeObject(forKey: "parkedLocation")
        detectedGarageInfo = nil
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
            let sharedDefaults = UserDefaults(suiteName: "group.com.tyler.crossstreets")
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
        }
    }
    
    private func saveFloorCorrections() {
        if let data = try? JSONEncoder().encode(floorCorrections) {
            UserDefaults.standard.set(data, forKey: correctionsKey)
        }
    }
    
    private func loadUserIssues() {
        if let data = UserDefaults.standard.data(forKey: issuesKey),
           let issues = try? JSONDecoder().decode([UserIssue].self, from: data) {
            userIssues = issues
        }
    }
    
    private func saveUserIssues() {
        if let data = try? JSONEncoder().encode(userIssues) {
            UserDefaults.standard.set(data, forKey: issuesKey)
        }
    }
    
    func recordFloorCorrection(garageName: String, floor: String) {
        if floorCorrections[garageName] == nil {
            floorCorrections[garageName] = [:]
        }
        floorCorrections[garageName]?[floor, default: 0] += 1
        saveFloorCorrections()
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
}
