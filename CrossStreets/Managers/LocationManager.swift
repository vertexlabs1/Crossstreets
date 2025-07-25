import Foundation
import CoreLocation
import MapKit
import UIKit
import UserNotifications
import SwiftUI // Added for @AppStorage
import Network // Added for NWPathMonitor
import CoreMotion

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    // MARK: - Properties
    @Published var currentLocation: CLLocation? {
        didSet {
            // Only log significant location changes to prevent spam
            if let newLocation = currentLocation,
               let oldLocation = oldValue {
                let distance = newLocation.distance(from: oldLocation)
                if distance > 10 {
                    #if DEBUG
                    // Reduced logging frequency
                    #endif
                }
            } else if currentLocation != nil {
                #if DEBUG
                print("📍 currentLocation: First location set")
                #endif
            }
        }
    }
    @Published var parkedLocation: ParkingLocation?
    @Published var isLocationEnabled = false
    @Published var locationPermissionError: String?
    @Published var isDetectingParking = false
    @Published var isOnline = true
    @Published var detectedGarageInfo: GarageDetectionResult? = nil {
        didSet {
            // Throttle updates: only publish if value changed and at least 1s since last update
            let now = Date()
            if let old = oldValue, let new = detectedGarageInfo, old == new, now.timeIntervalSince(lastGarageInfoUpdate) < 1.0 {
                // Throttling update (same value, too soon)
                return
            }
            
            lastGarageInfoUpdate = now
        }
    }
    private var lastGarageInfoUpdate: Date = .distantPast
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    
    // Throttle helpers
    private var lastBarometricUpdate: Date = .distantPast
    private var lastLocationUpdate: Date = .distantPast
    
    // Location manager
    private let locationManager = CLLocationManager()
    
    // Altimeter for barometric pressure
    private let altimeter = CMAltimeter()
    @Published var barometricAltitude: Double? {
        didSet {
            // Only log significant changes to prevent spam
            if let newValue = barometricAltitude,
               let oldValue = oldValue {
                let difference = abs(newValue - oldValue)
                if difference > 1.0 { // Only log if altitude changed by more than 1 meter
                    #if DEBUG
                    print("📊 barometricAltitude: Updated (\(difference)m)")
                    #endif
                }
            } else if barometricAltitude != nil {
                #if DEBUG
                print("📊 barometricAltitude: First reading set")
                #endif
            }
        }
    }
    @Published var barometricPressure: Double?
    
    // Enhanced sensor data tracking
    @Published var gpsAltitude: Double?
    @Published var gpsVerticalAccuracy: Double?
    @Published var sensorDataQuality: SensorDataQuality = .unknown
    
    // Sensor data quality enum
    enum SensorDataQuality {
        case excellent
        case good
        case poor
        case unavailable
        case unknown
        
        var description: String {
            switch self {
            case .excellent: return "excellent"
            case .good: return "good"
            case .poor: return "poor"
            case .unavailable: return "unavailable"
            case .unknown: return "unknown"
            }
        }
    }
    
    // Network monitor
    // Network monitoring - REMOVED: Using shared network status from app level
    
    // Local storage keys
    private let parkedLocationKey = "parkedLocation"
    // Removed: correctionsKey, issuesKey, altitudeDataKey - now handled by Supabase
    
    // Data storage - only keep what's needed for current session
    // Removed: floorCorrections, userIssues, garageAltitudeData - now handled by Supabase
    
    // Keep these structs for Supabase data transfer
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
        let altitudeSource: String // "barometric" or "gps"
        let gpsAccuracy: Double
        let barometricPressure: Double?
        let wasCorrect: Bool
        let location: CLLocationCoordinate2D
        let address: String
    }
    
    override init() {
        super.init()
        setupLocationManager()
        // Network monitoring removed - using shared status from app level
        setupAltimeter()
        loadParkedLocation() // Keep this - needed for parked car location
        // Removed: loadFloorCorrections() - now handled by Supabase
        // Removed: loadUserIssues() - now handled by Supabase  
        // Removed: loadAltitudeData() - now handled by Supabase
    }
    
    deinit {
        // Network monitoring removed - using shared status from app level
        stopAltimeter()
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        locationManager.distanceFilter = 100 // Increased to prevent tiny movements from triggering updates
        locationManager.allowsBackgroundLocationUpdates = false
        locationManager.pausesLocationUpdatesAutomatically = true
    }
    
    private func setupAltimeter() {
        // Check if altimeter is available
        guard CMAltimeter.isRelativeAltitudeAvailable() else {
            print("⚠️ Barometric altimeter not available on this device")
            sensorDataQuality = .unavailable
            return
        }
        
        print("✅ Barometric altimeter available - starting monitoring")
        startAltimeter()
    }
    
    private func startAltimeter() {
        guard CMAltimeter.isRelativeAltitudeAvailable() else { 
            print("⚠️ Cannot start altimeter - not available")
            return 
        }
        
        print("🔄 Starting barometric altitude monitoring...")
        altimeter.startRelativeAltitudeUpdates(to: .main) { [weak self] data, error in
            if let error = error {
                print("❌ Altimeter error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self?.sensorDataQuality = .unavailable
                }
                return
            }
            
            guard let data = data else {
                print("⚠️ Altimeter returned no data")
                return
            }
            
            // Throttle updates to prevent excessive view rebuilds
            DispatchQueue.main.async {
                let now = Date()
                guard now.timeIntervalSince(self?.lastBarometricUpdate ?? .distantPast) > 10.0 else { return }
                
                let altitude = data.relativeAltitude.doubleValue
                let pressure = data.pressure.doubleValue
                
                self?.barometricAltitude = altitude
                self?.barometricPressure = pressure
                self?.lastBarometricUpdate = now
                
                // Assess data quality
                let quality = self?.assessBarometricDataQuality(altitude: altitude, pressure: pressure) ?? .unknown
                self?.sensorDataQuality = quality
                
                // Log significant changes for debugging
                if abs(altitude) > 1.0 {
                    print("📊 Barometric: \(altitude)m, \(pressure) kPa (quality: \(quality.description))")
                }
            }
        }
    }
    
    private func assessBarometricDataQuality(altitude: Double, pressure: Double) -> SensorDataQuality {
        // Check for reasonable pressure values (typically 90-110 kPa at sea level)
        let isPressureReasonable = pressure >= 80.0 && pressure <= 120.0
        
        // Check for reasonable altitude values (not extreme)
        let isAltitudeReasonable = abs(altitude) < 1000.0
        
        if isPressureReasonable && isAltitudeReasonable {
            return .excellent
        } else if isPressureReasonable || isAltitudeReasonable {
            return .good
        } else {
            return .poor
        }
    }
    
    private func stopAltimeter() {
        altimeter.stopRelativeAltitudeUpdates()
    }
    
    private func formatCoordinatesNicely(_ coordinate: CLLocationCoordinate2D) -> String {
        let latDirection = coordinate.latitude >= 0 ? "N" : "S"
        let lonDirection = coordinate.longitude >= 0 ? "E" : "W"
        let lat = String(format: "%.2f°%@", abs(coordinate.latitude), latDirection)
        let lon = String(format: "%.2f°%@", abs(coordinate.longitude), lonDirection)
        return "\(lat), \(lon)"
    }
    
    private func getSmartAddress(for coordinate: CLLocationCoordinate2D, completion: @escaping (String) -> Void) {
        print("🌍 getSmartAddress: Starting for coordinate \(coordinate)")
        let niceCoordinates = formatCoordinatesNicely(coordinate)
        
        // Start with a more user-friendly initial message
        completion("Getting address...")
        
        // Use retry logic for better reliability
        attemptAddressResolution(coordinate: coordinate, niceCoordinates: niceCoordinates, retryCount: 0, completion: completion)
    }
    
    private func attemptAddressResolution(
        coordinate: CLLocationCoordinate2D, 
        niceCoordinates: String, 
        retryCount: Int, 
        completion: @escaping (String) -> Void
    ) {
        let maxRetries = 2
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let geocoder = CLGeocoder()
        var hasCompleted = false
        
        print("🌍 Address resolution attempt \(retryCount + 1)/\(maxRetries + 1)")
        
        // Timeout based on retry count (longer for retries)
        let timeout = retryCount == 0 ? 2.0 : 3.0
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout) {
            if !hasCompleted {
                print("🌍 Address resolution: Timeout reached (attempt \(retryCount + 1))")
                hasCompleted = true
                
                if retryCount < maxRetries {
                    print("🌍 Address resolution: Retrying...")
                    self.attemptAddressResolution(coordinate: coordinate, niceCoordinates: niceCoordinates, retryCount: retryCount + 1, completion: completion)
                } else {
                    print("🌍 Address resolution: All attempts failed, using coordinates")
                    completion(niceCoordinates)
                }
            }
        }
        
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            guard !hasCompleted else { return }
            hasCompleted = true
            
            if let error = error {
                print("🌍 Address resolution: Error on attempt \(retryCount + 1): \(error.localizedDescription)")
                
                if retryCount < maxRetries {
                    print("🌍 Address resolution: Retrying due to error...")
                    self?.attemptAddressResolution(coordinate: coordinate, niceCoordinates: niceCoordinates, retryCount: retryCount + 1, completion: completion)
                } else {
                    print("🌍 Address resolution: All attempts failed, using coordinates")
                    completion(niceCoordinates)
                }
                return
            }
            
            var address = niceCoordinates
            if let placemark = placemarks?.first {
                print("🌍 Address resolution: Found placemark: \(placemark.name ?? "unnamed")")
                
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
                
                // Check for nearby stores as fallback
                self?.checkForNearbyStores(at: location) { nearbyStore in
                    if let store = nearbyStore {
                        print("🌍 Address resolution: Found nearby store: \(store)")
                        completion("Near \(store)")
                    } else {
                        print("🌍 Address resolution: Using resolved address: \(address)")
                        completion(address)
                    }
                }
            } else {
                print("🌍 Address resolution: No placemark found, checking nearby stores")
                self?.checkForNearbyStores(at: location) { nearbyStore in
                    if let store = nearbyStore {
                        print("🌍 Address resolution: Found nearby store: \(store)")
                        completion("Near \(store)")
                    } else {
                        print("🌍 Address resolution: Using coordinates: \(address)")
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
    
    func detectParkingType(completion: @escaping () -> Void = {}) {
        guard !isDetectingParking else { return }
        
        isDetectingParking = true
        let detectionStartTime = Date()
        
        print("🚗 Starting parking detection...")
        PerformanceMonitor.shared.startAction("garage_detection")
        
        // MUCH FASTER: Quick proximity check with 1.5s timeout
        let quickTimeout = DispatchTime.now() + 1.5
        
        DispatchQueue.main.asyncAfter(deadline: quickTimeout) { [weak self] in
            guard let self = self, self.isDetectingParking else { return }
            print("⏱️ Quick garage check timed out - parking normally")
            self.isDetectingParking = false
            self.saveParkedLocation(floor: nil)
            self.detectedGarageInfo = GarageDetectionResult(isInGarage: false, garageName: nil)
            
            let detectionDuration = Date().timeIntervalSince(detectionStartTime)
            PerformanceMonitor.shared.endAction("garage_detection", screen: "main", success: false, context: ["timeout": true])
            PerformanceMonitor.shared.logGarageDetectionTime(detectionDuration, success: false)
            completion()
        }
        
        guard let currentLocation = currentLocation else {
            print("❌ No current location available")
            isDetectingParking = false
            self.saveParkedLocation(floor: nil)
            self.detectedGarageInfo = GarageDetectionResult(isInGarage: false, garageName: nil)
            completion()
            return
        }
        
        // QUICK PROXIMITY CHECK: Only search if we have reasonable accuracy
        guard currentLocation.horizontalAccuracy <= 50 else {
            print("📍 Very poor GPS accuracy (\(currentLocation.horizontalAccuracy)m) - parking normally")
            isDetectingParking = false
            self.saveParkedLocation(floor: nil)
            self.detectedGarageInfo = GarageDetectionResult(isInGarage: false, garageName: nil)
            completion()
            return
        }
        
        print("📍 GPS accuracy acceptable (\(currentLocation.horizontalAccuracy)m) - proceeding with garage detection")
        
        // FAST GARAGE CHECK: Only look for very close, obvious garages
        performQuickGarageCheck(at: currentLocation) { [weak self] isInGarage, garageName in
            guard let self = self, self.isDetectingParking else { return }
            
            self.isDetectingParking = false
            let detectionDuration = Date().timeIntervalSince(detectionStartTime)
            
            if isInGarage {
                #if DEBUG
                print("🏢 Quick check: Found garage '\(garageName ?? "Unknown")' - showing floor picker")
                #endif
                self.detectedGarageInfo = GarageDetectionResult(isInGarage: true, garageName: garageName)
                PerformanceMonitor.shared.endAction("garage_detection", screen: "main", success: true, context: ["garage_name": garageName ?? "unknown"])
                PerformanceMonitor.shared.logGarageDetectionTime(detectionDuration, success: true)
            } else {
                #if DEBUG
                print("🚗 Quick check: No obvious garage - parking normally")
                #endif
                self.saveParkedLocation(floor: nil)
                self.detectedGarageInfo = GarageDetectionResult(isInGarage: false, garageName: nil)
                PerformanceMonitor.shared.endAction("garage_detection", screen: "main", success: false, context: ["no_garage": true])
                PerformanceMonitor.shared.logGarageDetectionTime(detectionDuration, success: false)
            }
            completion()
        }
    }
    
    private func checkForNearbyParking(at location: CLLocation) -> Bool {
        // Quick check for nearby parking structures (within 100m)
        let searchRequest = MKLocalSearch.Request()
        searchRequest.naturalLanguageQuery = "parking garage"
        searchRequest.region = MKCoordinateRegion(
            center: location.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.002, longitudeDelta: 0.002) // ~200m radius
        )
        
        let search = MKLocalSearch(request: searchRequest)
        let semaphore = DispatchSemaphore(value: 0)
        var hasNearbyParking = false
        
        search.start { response, error in
            defer { semaphore.signal() }
            
            guard let response = response, error == nil else { return }
            
            for item in response.mapItems {
                let distance = location.distance(from: item.placemark.location ?? CLLocation())
                let name = item.name?.lowercased() ?? ""
                
                // Check for real parking structures within 100m
                let isRealParking = (name.contains("garage") || name.contains("deck") || name.contains("structure")) && distance <= 150
                
                if isRealParking {
                    hasNearbyParking = true
                    break
                }
            }
        }
        
        // Wait for search to complete (with timeout)
        _ = semaphore.wait(timeout: .now() + 1.0)
        return hasNearbyParking
    }
    
    private func isInUrbanArea(at location: CLLocation) -> Bool {
        // Simplified urban detection without blocking the main thread
        // For now, assume most locations are urban to avoid blocking
        return true
    }
    
    private func checkNetworkConnectivity() -> Bool {
        // Use the existing network monitor instead of creating a new one
        // This avoids blocking the main thread
        return isOnline
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
        print("🔍 Starting PRECISE garage detection...")
        
        // Add a flag to ensure completion is only called once
        var garageSearchCompleted = false
        
        func completeOnce(_ found: Bool, _ name: String?) {
            if !garageSearchCompleted {
                garageSearchCompleted = true
                completion(found, name)
            }
        }
        
        // Shorter timeout for faster response
        let searchTimeout = DispatchTime.now() + 2.5
        
        // PRECISE GARAGE DETECTION: Only search for specific garage types
        performPreciseGarageSearch(at: location) { found, name in
            print("🔍 Precise garage search result: \(found ? "INSIDE" : "Outside") - \(name ?? "None")")
            completeOnce(found, name)
        }
        
        // Fallback timeout
        DispatchQueue.main.asyncAfter(deadline: searchTimeout) {
            print("⚠️ Precise garage search timed out")
            completeOnce(false, nil)
        }
    }
    
    private func performQuickGarageCheck(at location: CLLocation, completion: @escaping (Bool, String?) -> Void) {
        print("🔍 Performing QUICK garage check...")
        print("📍 Current location: \(location.coordinate.latitude), \(location.coordinate.longitude)")
        print("📍 GPS Accuracy: \(location.horizontalAccuracy)m (vertical: \(location.verticalAccuracy)m)")
        print("📍 Altitude: \(location.altitude)m")
        
        // Only search for very close, obvious garages
        let searchRequest = MKLocalSearch.Request()
        searchRequest.naturalLanguageQuery = "parking garage"
        searchRequest.region = MKCoordinateRegion(
            center: location.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.002, longitudeDelta: 0.002) // Increased search area (~200m)
        )
        
        let search = MKLocalSearch(request: searchRequest)
        let searchTimeout = DispatchTime.now() + 1.5 // Increased timeout
        
        search.start { response, error in
            // Check timeout
            guard DispatchTime.now() <= searchTimeout else {
                print("⏱️ Quick garage check timed out")
                completion(false, nil)
                return
            }
            
            guard let response = response, error == nil else {
                print("⚠️ Quick garage check failed: \(error?.localizedDescription ?? "Unknown error")")
                completion(false, nil)
                return
            }
            
            print("🔍 Found \(response.mapItems.count) potential structures")
            
            // ENHANCED DETECTION: More lenient criteria for troubleshooting
            for item in response.mapItems {
                let distance = location.distance(from: item.placemark.location ?? CLLocation())
                let name = item.name?.lowercased() ?? ""
                
                print("🔍 Checking structure: '\(item.name ?? "unnamed")' at \(distance)m")
                print("   - Name: '\(item.name ?? "unnamed")'")
                print("   - Distance: \(distance)m")
                print("   - GPS Accuracy: \(location.horizontalAccuracy)m")
                
                // ENHANCED CRITERIA: More lenient for troubleshooting
                // 1. Must be a clear garage/structure name
                let isClearGarage = name.contains("garage") || 
                                   name.contains("deck") ||
                                   name.contains("structure") ||
                                   (name.contains("parking") && (name.contains("structure") || name.contains("center")))
                
                // SPECIAL CHECK: Richardson Street parking garage
                let isRichardsonGarage = name.contains("richardson") || 
                                        (item.name?.contains("Richardson") == true)
                if isRichardsonGarage {
                    print("🎯 RICHARDSON GARAGE DETECTED: '\(item.name ?? "unnamed")'")
                }
                
                // 2. More lenient distance (increased from 50m to 100m)
                let isVeryClose = distance <= 100
                
                // 3. More lenient GPS accuracy (increased from 10m to 30m)
                let hasGoodAccuracy = location.horizontalAccuracy <= 30
                
                // 4. Optional: Check for altitude difference (inside multi-level)
                let hasAltitudeData = location.verticalAccuracy > 0 && location.verticalAccuracy < 20
                let isAtDifferentElevation = hasAltitudeData && abs(location.altitude - (item.placemark.location?.altitude ?? 0)) > 3
                
                print("   - Is clear garage: \(isClearGarage)")
                print("   - Is very close: \(isVeryClose) (max 100m)")
                print("   - Has good accuracy: \(hasGoodAccuracy) (max 30m)")
                if hasAltitudeData {
                    print("   - Altitude data available: \(location.altitude)m vs \(item.placemark.location?.altitude ?? 0)m")
                    print("   - Elevation difference: \(isAtDifferentElevation)")
                }
                
                // ENHANCED DETECTION: More lenient criteria
                if isClearGarage && isVeryClose && hasGoodAccuracy {
                    let formattedName = self.formatGarageName(for: item)
                    print("✅ QUICK CHECK: Likely in garage '\(formattedName)' at \(distance)m")
                    if hasAltitudeData && isAtDifferentElevation {
                        print("   - Elevation difference confirms multi-level garage")
                    }
                    completion(true, formattedName)
                    return
                } else if isRichardsonGarage {
                    // SPECIAL CASE: If it's Richardson garage but doesn't meet other criteria, log it
                    print("⚠️ Richardson garage found but criteria not met:")
                    print("   - Distance: \(distance)m (max 100m)")
                    print("   - Accuracy: \(location.horizontalAccuracy)m (max 30m)")
                    print("   - Is clear garage: \(isClearGarage)")
                } else {
                    print("❌ Structure '\(item.name ?? "unnamed")' rejected:")
                    print("   - Distance: \(distance)m (max 100m)")
                    print("   - Accuracy: \(location.horizontalAccuracy)m (max 30m)")
                    print("   - Is clear garage: \(isClearGarage)")
                }
            }
            
            // FALLBACK: If no garage found, try a specific search for "Richardson"
            print("🔍 No garage found in initial search, trying Richardson-specific search...")
            self.performRichardsonSpecificSearch(at: location) { found, name in
                if found {
                    print("✅ Richardson-specific search found: \(name ?? "Unknown")")
                    completion(true, name)
                } else {
                    print("❌ No Richardson garage found in specific search")
                    completion(false, nil)
                }
            }
        }
    }
    
    private func performRichardsonSpecificSearch(at location: CLLocation, completion: @escaping (Bool, String?) -> Void) {
        print("🔍 Performing Richardson-specific search...")
        
        let searchRequest = MKLocalSearch.Request()
        searchRequest.naturalLanguageQuery = "Richardson"
        searchRequest.region = MKCoordinateRegion(
            center: location.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.003, longitudeDelta: 0.003) // Larger search area
        )
        
        let search = MKLocalSearch(request: searchRequest)
        let searchTimeout = DispatchTime.now() + 1.0
        
        search.start { response, error in
            guard DispatchTime.now() <= searchTimeout else {
                print("⏱️ Richardson search timed out")
                completion(false, nil)
                return
            }
            
            guard let response = response, error == nil else {
                print("⚠️ Richardson search failed: \(error?.localizedDescription ?? "Unknown error")")
                completion(false, nil)
                return
            }
            
            print("🔍 Found \(response.mapItems.count) Richardson-related items")
            
            for item in response.mapItems {
                let distance = location.distance(from: item.placemark.location ?? CLLocation())
                let name = item.name?.lowercased() ?? ""
                
                print("🔍 Richardson item: '\(item.name ?? "unnamed")' at \(distance)m")
                
                // Check if it's a parking-related Richardson item
                let isParkingRelated = name.contains("parking") || 
                                      name.contains("garage") || 
                                      name.contains("deck") ||
                                      name.contains("structure")
                
                let isCloseEnough = distance <= 150 // More lenient for Richardson
                let hasReasonableAccuracy = location.horizontalAccuracy <= 50 // Very lenient
                
                if isParkingRelated && isCloseEnough && hasReasonableAccuracy {
                    let formattedName = self.formatGarageName(for: item)
                    print("✅ Richardson parking found: '\(formattedName)' at \(distance)m")
                    completion(true, formattedName)
                    return
                }
            }
            
            print("❌ No Richardson parking found")
            completion(false, nil)
        }
    }
    
    private func performPreciseGarageSearch(at location: CLLocation, completion: @escaping (Bool, String?) -> Void) {
        print("🔍 Performing PRECISE garage search...")
        
        // Search specifically for garage structures
        let searchRequest = MKLocalSearch.Request()
        searchRequest.naturalLanguageQuery = "parking garage"
        searchRequest.region = MKCoordinateRegion(
            center: location.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.003, longitudeDelta: 0.003) // Smaller, more precise search area
        )
        
        let search = MKLocalSearch(request: searchRequest)
        let searchTimeout = DispatchTime.now() + 2.0
        
        search.start { response, error in
            // Check timeout
            guard DispatchTime.now() <= searchTimeout else {
                print("⚠️ Precise garage search timed out")
                completion(false, nil)
                return
            }
            
            guard let response = response, error == nil else {
                print("⚠️ Precise garage search failed: \(error?.localizedDescription ?? "Unknown error")")
                completion(false, nil)
                return
            }
            
            print("🔍 Found \(response.mapItems.count) potential garage structures")
            
            // PRECISE DETECTION: Only consider if user is actually INSIDE the garage
            for item in response.mapItems {
                let distance = location.distance(from: item.placemark.location ?? CLLocation())
                let name = item.name?.lowercased() ?? ""
                
                // PRECISE CRITERIA: Must be a real garage structure AND very close
                let isRealGarage = name.contains("garage") || 
                                  name.contains("structure") ||
                                  name.contains("deck") ||
                                  (name.contains("parking") && (name.contains("garage") || name.contains("deck") || name.contains("structure")))
                
                // PRECISE DISTANCE: Must be within 100m AND have good GPS accuracy
                let isCloseEnough = distance <= 150 // Increased from 100m to 150m
                let hasGoodAccuracy = location.horizontalAccuracy <= 25 // Increased for outdoor use
                
                // PRECISE ALTITUDE: Check if user is at a different elevation (inside garage)
                let hasAltitudeData = location.verticalAccuracy > 0 && location.verticalAccuracy < 20
                let isAtDifferentElevation = hasAltitudeData && abs(location.altitude - (item.placemark.location?.altitude ?? 0)) > 5
                
                // PRECISE DETECTION: Only if all criteria are met
                if isRealGarage && isCloseEnough && hasGoodAccuracy {
                    let formattedName = self.formatGarageName(for: item)
                    print("✅ PRECISE DETECTION: User NEAR garage '\(formattedName)' at \(distance)m (accuracy: \(location.horizontalAccuracy)m)")
                    if hasAltitudeData {
                        print("   - Altitude: \(location.altitude)m (accuracy: \(location.verticalAccuracy)m)")
                        if isAtDifferentElevation {
                            print("   - Elevation difference detected - likely inside multi-level garage")
                        }
                    }
                    completion(true, formattedName)
                    return
                } else {
                    #if DEBUG
                    print("❌ Garage '\(item.name ?? "unnamed")' rejected:")
                    #endif
                    #if DEBUG
                    print("   - Distance: \(distance)m (max 100m)")
                    #endif
                    #if DEBUG
                    print("   - Accuracy: \(location.horizontalAccuracy)m (max 25m)")
                    #endif
                    #if DEBUG
                    print("   - Is real garage: \(isRealGarage)")
                    #endif
                    if hasAltitudeData {
                        #if DEBUG
                        print("   - Altitude: \(location.altitude)m (accuracy: \(location.verticalAccuracy)m)")
                        #endif
                    }
                }
            }
            
            print("❌ No precise garage match found - user likely outside")
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
    
    func saveParkedLocation(floor: String?, notes: String? = nil) {
        guard let location = currentLocation else { 
            print("❌ saveParkedLocation: No current location available")
            return 
        }
        #if DEBUG
        print("📍 saveParkedLocation: Starting with location \(location.coordinate)")
        #endif
        let garageName = detectedGarageInfo?.garageName
        let parkingLocation = ParkingLocation(
            id: UUID(),
            coordinate: location.coordinate,
            address: "Getting address...", // Better initial state
            floor: floor,
            timestamp: Date(),
            garageName: garageName,
            notes: notes
        )
        setParkedLocation(parkingLocation)
        HapticManager.mediumImpact()
        
        // Get the smart address with better loading state
        #if DEBUG
        print("📍 saveParkedLocation: Starting address resolution...")
        #endif
        getSmartAddress(for: location.coordinate) { [weak self] address in
            #if DEBUG
            print("📍 saveParkedLocation: Address resolved: \(address)")
            #endif
            DispatchQueue.main.async {
                let updatedLocation = ParkingLocation(
                    id: parkingLocation.id,
                    coordinate: parkingLocation.coordinate,
                    address: address,
                    floor: parkingLocation.floor,
                    timestamp: parkingLocation.timestamp,
                    garageName: parkingLocation.garageName,
                    notes: parkingLocation.notes
                )
                self?.setParkedLocation(updatedLocation)
                self?.saveToUserDefaults(updatedLocation)
                #if DEBUG
                print("📍 saveParkedLocation: Updated parking location with address")
                #endif
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
            garageName: location.garageName,
            notes: location.notes
        )
        setParkedLocation(updatedLocation)
        saveToUserDefaults(updatedLocation)
    }
    
    func updateNotes(_ notes: String?) {
        guard let location = parkedLocation else { return }
        let updatedLocation = ParkingLocation(
            id: location.id,
            coordinate: location.coordinate,
            address: location.address,
            floor: location.floor,
            timestamp: location.timestamp,
            garageName: location.garageName,
            notes: notes
        )
        setParkedLocation(updatedLocation)
        saveToUserDefaults(updatedLocation)
    }
    
    func clearParkedLocation() {
        #if DEBUG
        print("🗑️ clearParkedLocation: Starting...")
        #endif
        setParkedLocation(nil)
        UserDefaults.standard.removeObject(forKey: "parkedLocation")
        
        // Handle app group UserDefaults with error handling
        if let sharedDefaults = UserDefaults(suiteName: "group.CC3YTPPQQJ.crossstreets") {
            sharedDefaults.removeObject(forKey: "parkedLocation")
            #if DEBUG
            print("🗑️ clearParkedLocation: Cleared shared UserDefaults")
            #endif
        } else {
            #if DEBUG
            print("⚠️ clearParkedLocation: Could not access shared UserDefaults")
            #endif
        }
        
        detectedGarageInfo = nil
        isDetectingParking = false
        HapticManager.lightImpact()
        #if DEBUG
        print("🗑️ clearParkedLocation: Completed")
        #endif
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
            
            // Handle app group UserDefaults with error handling
            if let sharedDefaults = UserDefaults(suiteName: "group.CC3YTPPQQJ.crossstreets") {
                sharedDefaults.set(encoded, forKey: "parkedLocation")
                #if DEBUG
                print("💾 saveToUserDefaults: Saved to shared UserDefaults")
                #endif
            } else {
                #if DEBUG
                print("⚠️ saveToUserDefaults: Could not access shared UserDefaults")
                #endif
            }
        } else {
            #if DEBUG
            print("❌ saveToUserDefaults: Failed to encode parking location")
            #endif
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
    // Removed: loadFloorCorrections() - now handled by Supabase
    // Removed: saveFloorCorrections() - now handled by Supabase
    // Removed: loadUserIssues() - now handled by Supabase
    // Removed: saveUserIssues() - now handled by Supabase
    
    // Removed: recordFloorCorrection() - now handled by Supabase
    // Removed: logGarageDetectionFailure() - now handled by Supabase
    
    func logUserIssue(notes: String, issueType: String = "general_issue") {
        guard let currentLocation = currentLocation else {
            #if DEBUG
            print("⚠️ Cannot log issue: No current location available")
            #endif
            return
        }
        
        // Get current address for context
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(currentLocation) { placemarks, error in
            let address = placemarks?.first?.name ?? "Unknown location"
            
            DispatchQueue.main.async {
                #if DEBUG
                print("✅ Logged user issue: \(notes)")
                #endif
                
                // Send to Supabase for real-time analytics
                SupabaseManager.shared.logUserIssue(
                    notes: notes,
                    issueType: issueType,
                    location: currentLocation.coordinate,
                    address: address
                ) { success in
                    if success {
                        #if DEBUG
                        print("✅ Supabase: Issue synced successfully")
                        #endif
                    } else {
                        #if DEBUG
                        print("⚠️ Supabase: Issue queued for later sync")
                        #endif
                    }
                }
            }
        }
    }
    
    // Removed: getFloorCorrectionCount() - now handled by Supabase
    // Removed: getGarageNames() - now handled by Supabase
    // Removed: getFloors(for:) - now handled by Supabase
    

    
    // MARK: - Altitude-Based Floor Detection
    
    func detectFloorForGarage(_ garageName: String) -> String? {
        guard let location = currentLocation else { 
            print("⚠️ Floor detection: No current location available")
            return nil 
        }
        
        print("🏢 Floor detection for '\(garageName)' - analyzing sensor data...")
        
        // Collect all available sensor data
        let sensorData = collectSensorData(location: location)
        print("📊 Sensor data: \(sensorData.description)")
        
        // Determine best altitude source
        let (altitude, altitudeSource) = determineBestAltitudeSource(sensorData: sensorData, location: location)
        
        guard let finalAltitude = altitude else {
            print("❌ Floor detection: No valid altitude data available")
            return nil
        }
        
        // Validate altitude data quality
        guard isValidAltitude(finalAltitude, source: altitudeSource, location: location) else {
            print("⚠️ Floor detection: Poor altitude data quality - skipping")
            return nil
        }
        
        // Make educated guess based on common patterns
        let detectedFloor = makeInitialFloorGuess(altitude: finalAltitude, garageName: garageName, source: altitudeSource)
        print("🏢 Floor detection: Detected \(detectedFloor) (altitude: \(finalAltitude)m, source: \(altitudeSource))")
        
        return detectedFloor
    }
    
    private struct SensorData {
        let barometricAltitude: Double?
        let barometricPressure: Double?
        let gpsAltitude: Double?
        let gpsVerticalAccuracy: Double?
        let barometricQuality: SensorDataQuality
        let gpsQuality: SensorDataQuality
        
        var description: String {
            var parts: [String] = []
            if let baroAlt = barometricAltitude {
                parts.append("baro: \(baroAlt)m")
            }
            if let baroPress = barometricPressure {
                parts.append("pressure: \(baroPress) kPa")
            }
            if let gpsAlt = gpsAltitude {
                parts.append("gps: \(gpsAlt)m ±\(gpsVerticalAccuracy ?? 0)m")
            }
            parts.append("baro quality: \(barometricQuality.description)")
            parts.append("gps quality: \(gpsQuality.description)")
            return parts.joined(separator: ", ")
        }
    }
    
    private func collectSensorData(location: CLLocation) -> SensorData {
        let barometricQuality = sensorDataQuality
        let gpsQuality = assessGPSDataQuality(location: location)
        
        return SensorData(
            barometricAltitude: barometricAltitude,
            barometricPressure: barometricPressure,
            gpsAltitude: location.altitude,
            gpsVerticalAccuracy: location.verticalAccuracy,
            barometricQuality: barometricQuality,
            gpsQuality: gpsQuality
        )
    }
    
    private func determineBestAltitudeSource(sensorData: SensorData, location: CLLocation) -> (altitude: Double?, source: String) {
        // Priority: Barometric (if available and good quality)
        if let barometricAltitude = sensorData.barometricAltitude,
           let _ = sensorData.barometricPressure,
           sensorData.barometricQuality == .excellent || sensorData.barometricQuality == .good {
            return (roundAltitude(barometricAltitude), "barometric")
        }
        
        // Fallback: GPS (if available and reasonable accuracy)
        if let gpsAltitude = sensorData.gpsAltitude,
           sensorData.gpsQuality != .unavailable,
           location.verticalAccuracy > 0 && location.verticalAccuracy < 50.0 {
            return (roundAltitude(gpsAltitude), "gps")
        }
        
        // Last resort: Barometric even if poor quality
        if let barometricAltitude = sensorData.barometricAltitude,
           let _ = sensorData.barometricPressure {
            return (roundAltitude(barometricAltitude), "barometric_poor")
        }
        
        return (nil, "none")
    }
    
    private func isValidAltitude(_ altitude: Double, source: String, location: CLLocation) -> Bool {
        // Check for reasonable altitude values
        guard altitude > -1000 && altitude < 10000 else {
            #if DEBUG
            print("⚠️ Altitude out of reasonable range: \(altitude)m")
            #endif
            return false
        }
        
        // Check GPS accuracy if using GPS altitude
        if source == "gps" && location.verticalAccuracy > 20 {
            #if DEBUG
            print("⚠️ Poor GPS vertical accuracy: \(location.verticalAccuracy)m")
            #endif
            return false
        }
        
        return true
    }
    
    private func roundAltitude(_ altitude: Double) -> Double {
        // Round to nearest 3 meters (typical floor height)
        return round(altitude / 3.0) * 3.0
    }
    
    private func predictFloorFromAltitude(_ altitude: Double, garageData: GarageAltitudeData, source: String) -> String? {
        var bestFloor: String?
        var smallestDifference = Double.infinity
        
        for (floor, floorAltitude) in garageData.floorElevations {
            let difference = abs(altitude - floorAltitude)
            if difference < smallestDifference {
                smallestDifference = difference
                bestFloor = floor
            }
        }
        
        // More lenient threshold for barometric pressure (more accurate)
        let threshold = source == "barometric" ? 4.5 : 6.0
        
        // Only return prediction if difference is reasonable
        return smallestDifference <= threshold ? bestFloor : nil
    }
    
    private func makeInitialFloorGuess(altitude: Double, garageName: String, source: String) -> String {
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
            // For higher altitudes, calculate floor based on typical floor height
            let floorNumber = Int(round(altitude / 3.0)) // 3m per floor
            return floorNumber > 0 ? "F\(floorNumber)" : "G"
        }
    }
    
    func logFloorDetectionResult(detectedFloor: String, actualFloor: String, garageName: String) {
        guard let location = currentLocation else { 
            print("⚠️ Floor logging: No current location available")
            return 
        }
        
        print("📊 Floor Detection Result: \(detectedFloor) → \(actualFloor)")
        
        // Collect comprehensive sensor data
        let sensorData = collectSensorData(location: location)
        let (altitude, altitudeSource) = determineBestAltitudeSource(sensorData: sensorData, location: location)
        
        let wasCorrect = detectedFloor == actualFloor
        
        // Log floor detection accuracy for monitoring
        PerformanceMonitor.shared.logFloorDetectionAccuracy(wasCorrect, altitudeSource: altitudeSource)
        
        // Log user action for floor selection
        SupabaseManager.shared.logUserAction(
            action: "floor_selection",
            screen: "floor_picker",
            success: true,
            context: [
                "detected_floor": detectedFloor,
                "actual_floor": actualFloor,
                "garage_name": garageName,
                "was_correct": wasCorrect,
                "altitude_source": altitudeSource,
                "sensor_data": sensorData.description
            ]
        ) { _ in }
        
        // Log for analysis
        print("📊 Floor Detection: \(detectedFloor) → \(actualFloor) (\(wasCorrect ? "✅" : "❌"))")
        print("📊 Sensor Data: \(sensorData.description)")
        if let finalAltitude = altitude {
            print("📊 Final Altitude: \(finalAltitude)m (\(altitudeSource))")
        }
        
        // Send to Supabase for real-time analytics with enhanced data
        SupabaseManager.shared.logFloorCorrection(
            garageName: garageName,
            detectedFloor: detectedFloor,
            actualFloor: actualFloor,
            altitude: altitude ?? 0.0,
            altitudeSource: altitudeSource,
            barometricPressure: sensorData.barometricPressure,
            wasCorrect: wasCorrect,
            location: location.coordinate,
            gpsAltitude: sensorData.gpsAltitude,
            gpsVerticalAccuracy: sensorData.gpsVerticalAccuracy,
            barometricAltitude: sensorData.barometricAltitude,
            sensorQuality: sensorDataQuality.description
        ) { success in
            if success {
                print("✅ Supabase: Floor correction synced successfully")
            } else {
                print("⚠️ Supabase: Floor correction queued for later sync")
            }
        }
    }
    
    // Removed: updateGarageAltitudeData() - now handled by Supabase
    // Removed: loadAltitudeData() - now handled by Supabase
    // Removed: saveAltitudeData() - now handled by Supabase
    
    // Network monitoring removed - using shared status from app level
    
    // Test method to verify location manager functionality
    func debugLocationStatus() {
        #if DEBUG
        print("🔍 DEBUG: Location Manager Status")
        #endif
    }
    
    // MARK: - Parking Notes Management
    
    func updateParkingNotes(_ notes: String) {
        guard var currentParking = parkedLocation else { return }
        currentParking.notes = notes.isEmpty ? nil : notes
        parkedLocation = currentParking
        
        // Save to UserDefaults
        if let parkingData = try? JSONEncoder().encode(currentParking) {
            UserDefaults.standard.set(parkingData, forKey: "parkedLocation")
        }
        
        print("📝 Updated parking notes: \(notes)")
    }
    
    func updateParkingPhotos(_ photos: [UIImage]) {
        guard var currentParking = parkedLocation else { return }
        
        // Move file operations to background queue
        DispatchQueue.global(qos: .userInitiated).async {
            // Create photos directory if it doesn't exist
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let photosDirectory = documentsPath.appendingPathComponent("ParkingPhotos")
            
            do {
                try FileManager.default.createDirectory(at: photosDirectory, withIntermediateDirectories: true)
            } catch {
                print("❌ Failed to create photos directory: \(error)")
                return
            }
            
            var photoPaths: [String] = []
            
            // Save each photo to file system with compression
            for (index, photo) in photos.enumerated() {
                let fileName = "\(currentParking.id.uuidString)_\(index).jpg"
                let fileURL = photosDirectory.appendingPathComponent(fileName)
                
                // Compress image to reduce file size and memory usage
                if let imageData = photo.jpegData(compressionQuality: 0.6) {
                    do {
                        try imageData.write(to: fileURL)
                        photoPaths.append(fileName)
                    } catch {
                        print("❌ Failed to save photo: \(error)")
                    }
                }
            }
            
            // Update UI on main thread
            DispatchQueue.main.async {
                currentParking.photoPaths = photoPaths.isEmpty ? nil : photoPaths
                self.parkedLocation = currentParking
                
                // Save to UserDefaults
                if let parkingData = try? JSONEncoder().encode(currentParking) {
                    UserDefaults.standard.set(parkingData, forKey: "parkedLocation")
                }
            }
        }
    }
    
    func loadParkingPhotos() -> [UIImage] {
        guard let currentParking = parkedLocation,
              let photoPaths = currentParking.photoPaths else { return [] }
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let photosDirectory = documentsPath.appendingPathComponent("ParkingPhotos")
        
        var photos: [UIImage] = []
        
        // Limit the number of photos to prevent memory issues
        let maxPhotos = min(photoPaths.count, 10)
        
        for (_, photoPath) in photoPaths.prefix(maxPhotos).enumerated() {
            let fileURL = photosDirectory.appendingPathComponent(photoPath)
            if let imageData = try? Data(contentsOf: fileURL),
               let image = UIImage(data: imageData) {
                photos.append(image)
            }
        }
        
        return photos
    }
    
    // MARK: - App Lifecycle Management
    
    func refreshLocationPermissions() {
        print("🔄 Refreshing location permissions...")
        
        let status = locationManager.authorizationStatus
        print("📍 Current authorization status: \(status.rawValue)")
        
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            print("✅ Location authorized - restarting services")
            ensureLocationServicesRunning()
        case .denied, .restricted:
            print("❌ Location access denied or restricted")
            // Don't show alert here - let the UI handle it
        case .notDetermined:
            print("❓ Location permission not determined - requesting")
            locationManager.requestWhenInUseAuthorization()
        @unknown default:
            print("❓ Unknown authorization status: \(status)")
        }
    }
    
    func ensureLocationServicesRunning() {
        print("🔄 Ensuring location services are running...")
        
        // Check if location manager is actually updating by checking last update time
        let timeSinceLastUpdate = Date().timeIntervalSince(lastLocationUpdate)
        if timeSinceLastUpdate > 30.0 { // If no updates in 30 seconds, restart
            print("⚠️ Location manager not updating - restarting")
            locationManager.startUpdatingLocation()
        }
        
        // Ensure altimeter is running
        if CMAltimeter.isRelativeAltitudeAvailable() {
            print("✅ Altimeter available - ensuring it's running")
            startAltimeter()
        }
    }
    
    // MARK: - Helper Methods
    
    private func assessGPSDataQuality(location: CLLocation) -> SensorDataQuality {
        let horizontalAccuracy = location.horizontalAccuracy
        let verticalAccuracy = location.verticalAccuracy
        
        // Check if we have valid altitude data
        let hasValidAltitude = verticalAccuracy > 0 && verticalAccuracy < 50.0
        
        // Assess horizontal accuracy
        let horizontalQuality: SensorDataQuality
        if horizontalAccuracy <= 5.0 {
            horizontalQuality = .excellent
        } else if horizontalAccuracy <= 15.0 {
            horizontalQuality = .good
        } else if horizontalAccuracy <= 50.0 {
            horizontalQuality = .poor
        } else {
            horizontalQuality = .unavailable
        }
        
        // If we have good horizontal accuracy but poor vertical, still consider it usable
        if hasValidAltitude && horizontalQuality != .unavailable {
            return verticalAccuracy <= 10.0 ? .excellent : .good
        }
        
        return horizontalQuality
    }
    
    private func checkForParkingDetection() {
        // This method is called when location updates to check if we should detect parking
        // For now, we'll leave it empty as parking detection is handled elsewhere
        // This prevents the compilation error while maintaining the existing logic
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        // Record GPS altitude and accuracy
        gpsAltitude = location.altitude
        gpsVerticalAccuracy = location.verticalAccuracy
        
        // Assess GPS data quality
        if location.verticalAccuracy > 0 && location.verticalAccuracy < 20 {
            sensorDataQuality = .excellent
        } else if location.verticalAccuracy >= 20 && location.verticalAccuracy < 50 {
            sensorDataQuality = .good
        } else {
            sensorDataQuality = .poor
        }
        
        // Only update if we have a significant improvement or first location
        if currentLocation == nil || 
           location.horizontalAccuracy < currentLocation!.horizontalAccuracy ||
           abs(location.timestamp.timeIntervalSince(currentLocation!.timestamp)) > 30.0 {
            
            currentLocation = location
            lastLocationUpdate = Date()
            
            // Only log first location to reduce noise
            if currentLocation == location {
                print("📍 currentLocation: First location set")
            }
        }
        
        // Check for parking detection
        checkForParkingDetection()
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ Location manager failed with error: \(error.localizedDescription)")
        
        // Handle specific error types
        if let clError = error as? CLError {
            switch clError.code {
            case .denied:
                print("📍 Location access denied by user")
                // Don't show alert here - let the UI handle it
            case .locationUnknown:
                print("📍 Location temporarily unavailable")
                // This is temporary, don't restart services
            case .network:
                print("📍 Network error - location unavailable")
                // This is temporary, don't restart services
            default:
                print("📍 Other location error: \(clError.localizedDescription)")
                // For other errors, try to restart after a delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                    if self.locationManager.authorizationStatus == .authorizedWhenInUse ||
                       self.locationManager.authorizationStatus == .authorizedAlways {
                        print("🔄 Retrying location services after error")
                        self.locationManager.startUpdatingLocation()
                    }
                }
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        print("📍 Location authorization changed to: \(status.rawValue)")
        
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            print("✅ Location authorized - starting services")
            locationManager.startUpdatingLocation()
            if CMAltimeter.isRelativeAltitudeAvailable() {
                startAltimeter()
            }
        case .denied, .restricted:
            print("❌ Location access denied or restricted")
            // Don't show alert here - let the UI handle it
        case .notDetermined:
            print("❓ Location permission not determined")
        @unknown default:
            print("❓ Unknown authorization status: \(status)")
        }
    }
}
