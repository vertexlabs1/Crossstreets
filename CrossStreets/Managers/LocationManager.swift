import Foundation
import CoreLocation
import MapKit
import UIKit
import UserNotifications
import SwiftUI // Added for @AppStorage

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    private var isSearchingForGarage = false
    
    @Published var currentLocation: CLLocation?
    @Published var parkedLocation: ParkingLocation?
    @Published var detectedGarageInfo: (Bool, String?)?
    
    @Published var testModeEnabled: Bool = false
    
    private var addressCache: [String: String] = [:]
    private let addressCacheKey = "cachedAddresses"
    
    var cacheCount: Int {
        return addressCache.count
    }
    
    // Altitude estimation
    private var altitudeReadings: [Double] = []
    @AppStorage("averageFloorHeight") private var averageFloorHeight: Double = 3.5
    private var baselineAltitude: Double?
    private var userFloorCorrections: [String: Double] = [:] // garageName: adjustment
    private let correctionsKey = "floorCorrections"
    
    private var floorAltitudes: [String: [String: Double]] = [:] // garageName: [floor: altitude]
    private let floorAltitudesKey = "floorAltitudes"
    
    // --- Auto-park detection state ---
    private var stationaryStartTime: Date?
    private var lastSpeed: CLLocationSpeed = -1
    private var autoParkTimer: Timer?
    // ---
    
    override init() {
        super.init()
        setupLocationManager()
        loadParkedLocation()
        loadAddressCache()
        loadFloorCorrections()
        loadFloorAltitudes()
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        locationManager.distanceFilter = 25
    }
    
    private func loadFloorCorrections() {
        if let data = UserDefaults.standard.data(forKey: correctionsKey),
           let decoded = try? JSONDecoder().decode([String: Double].self, from: data) {
            userFloorCorrections = decoded
        }
    }
    
    private func saveFloorCorrections() {
        if let encoded = try? JSONEncoder().encode(userFloorCorrections) {
            UserDefaults.standard.set(encoded, forKey: correctionsKey)
        }
    }
    
    private func loadFloorAltitudes() {
        if let data = UserDefaults.standard.data(forKey: floorAltitudesKey),
           let decoded = try? JSONDecoder().decode([String: [String: Double]].self, from: data) {
            floorAltitudes = decoded
        }
    }
    
    private func saveFloorAltitudes() {
        if let encoded = try? JSONEncoder().encode(floorAltitudes) {
            UserDefaults.standard.set(encoded, forKey: floorAltitudesKey)
        }
    }
    
    func setGroundFloorBaseline() {
        guard let currentAltitude = currentLocation?.altitude else { return }
        let garage = detectedGarageInfo?.1 ?? "default"
        UserDefaults.standard.set(currentAltitude, forKey: "baseline_\(garage)")
        baselineAltitude = currentAltitude
    }
    
    func estimateFloor(completion: @escaping (String?) -> Void) {
        guard let currentAltitude = currentLocation?.altitude else {
            completion(nil)
            return
        }
        let garage = detectedGarageInfo?.1 ?? "default"
        // --- Use per-floor mapping if available ---
        if let floorMap = floorAltitudes[garage] {
            // Find the closest mapped floor by altitude
            let sorted = floorMap.sorted { abs($0.value - currentAltitude) < abs($1.value - currentAltitude) }
            if let (floor, mappedAltitude) = sorted.first, abs(mappedAltitude - currentAltitude) < averageFloorHeight / 2 {
                completion(floor)
                return
            }
        }
        // ---
        if let storedBaseline = UserDefaults.standard.value(forKey: "baseline_\(garage)") as? Double {
            baselineAltitude = storedBaseline
        } else if baselineAltitude == nil {
            baselineAltitude = currentAltitude
        }
        let correction = userFloorCorrections[garage] ?? 0
        altitudeReadings.append(currentAltitude)
        if altitudeReadings.count > 5 {
            altitudeReadings.removeFirst()
        }
        let averageAltitude = altitudeReadings.reduce(0, +) / Double(altitudeReadings.count)
        let difference = averageAltitude - baselineAltitude! + correction
        let floorNumber = round(difference / averageFloorHeight)
        let floorString: String
        if floorNumber > 0 {
            floorString = "F\(Int(floorNumber))"
        } else if floorNumber < 0 {
            floorString = "B\(Int(-floorNumber))"
        } else {
            floorString = "G"
        }
        completion(floorString)
    }
    
    func saveUserFloorCorrection(selected: String, estimated: String?) {
        guard let estimated = estimated, let garage = detectedGarageInfo?.1 else { return }
        // Save per-garage, per-floor altitude mapping
        if let currentAltitude = currentLocation?.altitude {
            var garageMap = floorAltitudes[garage] ?? [:]
            garageMap[selected] = currentAltitude
            floorAltitudes[garage] = garageMap
            saveFloorAltitudes()
        }
        // Correction logic for smoothing
        let selectedNum: Double
        if selected.hasPrefix("F") {
            selectedNum = Double(String(selected.dropFirst())) ?? 0
        } else if selected.hasPrefix("B") {
            selectedNum = -(Double(String(selected.dropFirst())) ?? 0)
        } else {
            selectedNum = 0
        }
        let estimatedNum: Double
        if estimated.hasPrefix("F") {
            estimatedNum = Double(String(estimated.dropFirst())) ?? 0
        } else if estimated.hasPrefix("B") {
            estimatedNum = -(Double(String(estimated.dropFirst())) ?? 0)
        } else {
            estimatedNum = 0
        }
        let adjustment = (selectedNum - estimatedNum) * averageFloorHeight
        userFloorCorrections[garage] = adjustment
        saveFloorCorrections()
        // Future: Send to server for crowdsourcing
    }
    
    private func loadAddressCache() {
        if let data = UserDefaults.standard.data(forKey: addressCacheKey),
           let decoded = try? JSONDecoder().decode([String: String].self, from: data) {
            addressCache = decoded
            print("📍 Loaded \(addressCache.count) cached addresses")
        }
    }
    
    private func saveAddressCache() {
        if let encoded = try? JSONEncoder().encode(addressCache) {
            UserDefaults.standard.set(encoded, forKey: addressCacheKey)
        }
    }
    
    private func getCachedAddress(for coordinate: CLLocationCoordinate2D) -> String? {
        let lat = String(format: "%.4f", coordinate.latitude)
        let lon = String(format: "%.4f", coordinate.longitude)
        let key = "\(lat),\(lon)"
        
        if let cached = addressCache[key] {
            return cached
        }
        
        for (cachedKey, cachedAddress) in addressCache {
            let components = cachedKey.split(separator: ",")
            if components.count == 2,
               let cachedLat = Double(components[0]),
               let cachedLon = Double(components[1]) {
                
                let cachedLocation = CLLocation(latitude: cachedLat, longitude: cachedLon)
                let currentLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
                
                if cachedLocation.distance(from: currentLocation) < 50 {
                    return cachedAddress
                }
            }
        }
        
        return nil
    }
    
    private func cacheAddress(for coordinate: CLLocationCoordinate2D, address: String) {
        let lat = String(format: "%.4f", coordinate.latitude)
        let lon = String(format: "%.4f", coordinate.longitude)
        let key = "\(lat),\(lon)"
        
        addressCache[key] = address
        saveAddressCache()
    }
    
    private func formatCoordinatesNicely(_ coordinate: CLLocationCoordinate2D) -> String {
        let latDirection = coordinate.latitude >= 0 ? "N" : "S"
        let lonDirection = coordinate.longitude >= 0 ? "E" : "W"
        
        let lat = String(format: "%.2f°%@", abs(coordinate.latitude), latDirection)
        let lon = String(format: "%.2f°%@", abs(coordinate.longitude), lonDirection)
        
        return "\(lat), \(lon)"
    }
    
    private func getSmartAddress(for coordinate: CLLocationCoordinate2D, completion: @escaping (String) -> Void) {
        if let cached = getCachedAddress(for: coordinate) {
            completion(cached)
            return
        }
        
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
                
                self?.cacheAddress(for: coordinate, address: address)
                completion(address)
            }
        }
    }
    
    func enableTestMode() {
        testModeEnabled = true
        print("🧪 Test mode enabled")
        HapticManager.lightImpact()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 60.0) {
            self.testModeEnabled = false
        }
    }
    
    func requestLocationPermission() {
        guard CLLocationManager.locationServicesEnabled() else { return }
        
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.startUpdatingLocation()
        case .denied, .restricted:
            print("Location permission denied")
        @unknown default:
            break
        }
    }
    
    func requestLocation() {
        locationManager.requestLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        DispatchQueue.main.async { [weak self] in
            self?.currentLocation = location
        }
        // --- Auto-park detection logic ---
        guard parkedLocation == nil else { return } // Only if not already parked
        let speed = location.speed >= 0 ? location.speed : lastSpeed
        lastSpeed = speed
        if speed < 2.0 { // Stationary or walking (<2 m/s)
            if stationaryStartTime == nil {
                stationaryStartTime = Date()
                autoParkTimer?.invalidate()
                autoParkTimer = Timer.scheduledTimer(withTimeInterval: 120, repeats: false) { [weak self] _ in
                    guard let self = self, self.parkedLocation == nil else { return }
                    self.saveParkedLocation(floor: nil)
                }
            }
        } else {
            stationaryStartTime = nil
            autoParkTimer?.invalidate()
        }
        // ---
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager failed with error: \(error.localizedDescription)")
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.startUpdatingLocation()
        case .denied, .restricted:
            print("Location permission denied/restricted")
        default:
            break
        }
    }
    
    func detectParkingType() {
        guard !isSearchingForGarage else { return }
        
        if testModeEnabled {
            isSearchingForGarage = true
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.isSearchingForGarage = false
                self.detectedGarageInfo = (true, "Test Parking Garage")
                self.testModeEnabled = false
            }
            return
        }
        
        if currentLocation == nil {
            locationManager.requestLocation()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.detectParkingType()
            }
            return
        }
        
        guard let location = currentLocation else { return }
        
        isSearchingForGarage = true
        
        checkForParkingGarage(at: location) { [weak self] isInGarage, garageName in
            DispatchQueue.main.async {
                self?.isSearchingForGarage = false
                
                if isInGarage {
                    self?.detectedGarageInfo = (true, garageName)
                    // --- Push notification for garage floor selection ---
                    self?.sendGarageFloorNotification(garageName: garageName)
                    // ---
                } else {
                    self?.saveParkedLocation(floor: nil)
                    self?.detectedGarageInfo = (false, nil)
                }
            }
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
        let searchRequest = MKLocalSearch.Request()
        searchRequest.naturalLanguageQuery = query
        searchRequest.region = MKCoordinateRegion(
            center: location.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.002, longitudeDelta: 0.002)
        )
        
        let search = MKLocalSearch(request: searchRequest)
        search.start { response, error in
            guard let response = response, error == nil else {
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
        
        // Also clear from shared UserDefaults for widget
        let sharedDefaults = UserDefaults(suiteName: "group.com.tyler.crossstreets")
        sharedDefaults?.removeObject(forKey: "parkedLocation")
        
        testModeEnabled = false
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
            
            // Also save to shared UserDefaults for widget
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
    
    // --- Push notification helper ---
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
    // ---
}
