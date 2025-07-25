import Foundation
import CoreLocation
import Network
import UIKit

class SupabaseManager: ObservableObject {
    static let shared = SupabaseManager()
    
    // Supabase configuration
    private let baseURL = "https://iravqhplqvdjetpvnlmo.supabase.co"
    // Load API key from Info.plist
    private let apiKey: String = {
        #if DEBUG
        print("🔍 Debug: Checking Bundle.main.infoDictionary for SupabaseAPIKey")
        if let infoDict = Bundle.main.infoDictionary {
            print("🔍 Debug: Bundle info dictionary keys: \(infoDict.keys.sorted())")
            if let key = infoDict["SupabaseAPIKey"] as? String {
                print("🔍 Debug: Found SupabaseAPIKey in bundle: \(key.prefix(30))... (length: \(key.count))")
                print("🔍 Debug: Full API key value: '\(key)'")
                print("🔍 Debug: API key starts with 'eyJ': \(key.hasPrefix("eyJ"))")
            } else {
                print("🔍 Debug: SupabaseAPIKey not found or not a string in bundle")
            }
        } else {
            print("🔍 Debug: Bundle.main.infoDictionary is nil")
        }
        #endif
        
        guard let key = Bundle.main.infoDictionary?["SupabaseAPIKey"] as? String else {
            fatalError("SupabaseAPIKey not found in Info.plist. Please add it securely.")
        }
        
        // Check if the key is the placeholder value
        if key == "REPLACE_WITH_YOUR_SUPABASE_API_KEY" {
            #if DEBUG
            print("⚠️ WARNING: Info.plist contains placeholder API key. Using fallback key.")
            #endif
            // Fallback to the real API key
            return "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlyYXZxaHBscXZkamV0cHZubG1vIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTMzODA2OTUsImV4cCI6MjA2ODk1NjY5NX0.Gm5wRCvbtc-4bF5MvZNsBVIxDGTi6AoENF6s8MvKWRQ"
        }
        
        #if DEBUG
        print("🔑 Supabase API key loaded: \(key.prefix(30))... (length: \(key.count))")
        #endif
        return key
    }()
    
    private let session = URLSession.shared
    // Network monitoring - REMOVED: Using shared network status from app level
    
    @Published var isOnline = true
    @Published var lastSyncTime: Date?
    
    private init() {
        // Network monitoring removed - using shared status from app level
        cleanupInvalidUserDefaults()
    }
    
    // MARK: - Cleanup Invalid UserDefaults
    private func cleanupInvalidUserDefaults() {
        // Remove any existing invalid UserDefaults entries that might cause crashes
        let keysToCleanup = [
            "queuedUserActions",
            "queuedPerformanceMetrics", 
            "queuedErrorLogs",
            "queued_supabase_issues",
            "queuedFloorCorrections"
        ]
        
        for key in keysToCleanup {
            if let _ = UserDefaults.standard.object(forKey: key) {
                // Try to access the data to see if it's valid
                if let _ = UserDefaults.standard.array(forKey: key) {
                    // Data is valid, keep it
                } else {
                    // If it's invalid, remove it
                    #if DEBUG
                    print("🧹 Cleaning up invalid UserDefaults key: \(key)")
                    #endif
                    UserDefaults.standard.removeObject(forKey: key)
                }
            }
        }
    }
    
    // MARK: - Network Monitoring
    
    // Network monitoring removed - using shared status from app level
    
    // MARK: - Issue Logging
    
    func logUserIssue(notes: String, issueType: String, location: CLLocationCoordinate2D, address: String, completion: @escaping (Bool) -> Void) {
        guard isOnline else {
            #if DEBUG
            print("⚠️ Supabase: Offline - queuing issue for later sync")
            #endif
            queueIssueForLaterSync(notes: notes, issueType: issueType, location: location, address: address)
            completion(false)
            return
        }
        
        let issueData: [String: Any] = [
            "notes": notes,
            "issue_type": issueType,
            "latitude": location.latitude,
            "longitude": location.longitude,
            "address": address,
            "device_info": getDeviceInfo(),
            "app_version": getAppVersion()
            // Remove timestamp - let database set created_at automatically
        ]
        
        sendRequest(endpoint: "/rest/v1/user_issues", method: "POST", data: issueData) { [weak self] success in
            DispatchQueue.main.async {
                if success {
                    self?.lastSyncTime = Date()
                    #if DEBUG
                    print("✅ Supabase: Issue logged successfully")
                    #endif
                } else {
                    #if DEBUG
                    print("❌ Supabase: Failed to log issue")
                    #endif
                }
                completion(success)
            }
        }
    }
    
    // MARK: - Floor Correction Logging
    
    func logFloorCorrection(
        garageName: String,
        detectedFloor: String,
        actualFloor: String,
        altitude: Double,
        altitudeSource: String,
        barometricPressure: Double?,
        wasCorrect: Bool,
        location: CLLocationCoordinate2D,
        completion: @escaping (Bool) -> Void
    ) {
        let data: [String: Any] = [
            "garage_name": garageName,
            "detected_floor": detectedFloor,
            "actual_floor": actualFloor,
            "altitude": altitude,
            "altitude_source": altitudeSource,
            "barometric_pressure": barometricPressure as Any,
            "gps_accuracy": 0.0, // Will be updated if available
            "was_correct": wasCorrect,
            "latitude": location.latitude,
            "longitude": location.longitude,
            "address": "Getting address..." // Will be updated later
            // Remove timestamp - let database set created_at automatically
        ]
        
        sendRequest(endpoint: "/rest/v1/floor_corrections", method: "POST", data: data) { success in
            if success {
                #if DEBUG
                print("✅ Supabase: Floor correction logged successfully")
                #endif
            } else {
                #if DEBUG
                print("⚠️ Supabase: Floor correction queued for later sync")
                #endif
                // Queue for later sync if needed
                self.queueFloorCorrection(data)
            }
            completion(success)
        }
    }
    
    // MARK: - Performance & Error Monitoring
    func logPerformanceMetric(
        metricName: String,
        value: Double,
        unit: String,
        context: [String: Any] = [:],
        completion: @escaping (Bool) -> Void
    ) {
        let data: [String: Any] = [
            "metric_name": metricName,
            "value": value,
            "unit": unit,
            "context": context,
            "device_model": UIDevice.current.model,
            "os_version": UIDevice.current.systemVersion,
            "app_version": getAppVersion()
            // Remove timestamp - let database set created_at automatically
        ]
        
        sendRequest(endpoint: "/rest/v1/performance_metrics", method: "POST", data: data) { success in
            if success {
                #if DEBUG
                print("📊 Supabase: Performance metric logged: \(metricName) = \(value) \(unit)")
                #endif
            } else {
                #if DEBUG
                print("⚠️ Supabase: Performance metric queued for later sync")
                #endif
                self.queuePerformanceMetric(data)
            }
            completion(success)
        }
    }
    
    func logError(
        errorType: String,
        errorMessage: String,
        stackTrace: String? = nil,
        context: [String: Any] = [:],
        completion: @escaping (Bool) -> Void
    ) {
        let data: [String: Any] = [
            "error_type": errorType,
            "error_message": errorMessage,
            "stack_trace": stackTrace ?? "",
            "context": context,
            "device_model": UIDevice.current.model,
            "os_version": UIDevice.current.systemVersion,
            "app_version": getAppVersion()
            // Remove timestamp - let database set created_at automatically
        ]
        
        sendRequest(endpoint: "/rest/v1/error_logs", method: "POST", data: data) { success in
            if success {
                #if DEBUG
                print("🚨 Supabase: Error logged: \(errorType) - \(errorMessage)")
                #endif
            } else {
                #if DEBUG
                print("⚠️ Supabase: Error queued for later sync")
                #endif
                self.queueErrorLog(data)
            }
            completion(success)
        }
    }
    
    func logUserAction(
        action: String,
        screen: String,
        success: Bool,
        duration: Double? = nil,
        context: [String: Any] = [:],
        completion: @escaping (Bool) -> Void
    ) {
        let data: [String: Any] = [
            "action": action,
            "screen": screen,
            "success": success,
            "duration": duration ?? 0.0,
            "context": context,
            "device_model": UIDevice.current.model,
            "os_version": UIDevice.current.systemVersion,
            "app_version": getAppVersion()
            // Remove timestamp - let database set created_at automatically
        ]
        
        sendRequest(endpoint: "/rest/v1/user_actions", method: "POST", data: data) { success in
            if success {
                #if DEBUG
                print("👤 Supabase: User action logged: \(action) on \(screen) (\(success ? "✅" : "❌"))")
                #endif
            } else {
                #if DEBUG
                print("⚠️ Supabase: User action queued for later sync")
                #endif
                self.queueUserAction(data)
            }
            completion(success)
        }
    }
    
    // MARK: - Private Methods
    
    private func sendRequest(endpoint: String, method: String, data: [String: Any], completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: baseURL + endpoint) else {
            #if DEBUG
            print("❌ Supabase: Invalid URL")
            #endif
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        
        // Debug: Log the request headers (without exposing API key)
        #if DEBUG
        print("📤 Supabase: Request headers:")
        print("  - Authorization: Bearer [REDACTED]")
        print("  - apikey: [REDACTED]")
        print("  - Content-Type: \(request.value(forHTTPHeaderField: "Content-Type") ?? "nil")")
        #endif
        
        // Wrap data in array as Supabase expects
        let requestBody = [data]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            
            // Debug: Log the request data
            #if DEBUG
            if let httpBody = request.httpBody, let jsonString = String(data: httpBody, encoding: .utf8) {
                print("📤 Supabase: Sending to \(endpoint): \(jsonString)")
            }
            #endif
        } catch {
            #if DEBUG
            print("❌ Supabase: JSON serialization failed: \(error)")
            #endif
            completion(false)
            return
        }
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                #if DEBUG
                print("❌ Supabase: Network error: \(error)")
                #endif
                completion(false)
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                let success = (200...299).contains(httpResponse.statusCode)
                if !success {
                    #if DEBUG
                    print("❌ Supabase: HTTP \(httpResponse.statusCode)")
                    // Log response body for debugging
                    if let data = data, let responseString = String(data: data, encoding: .utf8) {
                        print("❌ Supabase: Response body: \(responseString)")
                    }
                    #endif
                } else {
                    #if DEBUG
                    print("✅ Supabase: Request successful")
                    #endif
                }
                completion(success)
            } else {
                completion(false)
            }
        }
        
        task.resume()
    }
    
    private func queueIssueForLaterSync(notes: String, issueType: String, location: CLLocationCoordinate2D, address: String) {
        // Store in UserDefaults for later sync when online
        let queuedIssue: [String: Any] = [
            "notes": notes,
            "issue_type": issueType,
            "latitude": location.latitude,
            "longitude": location.longitude,
            "address": address,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        // Convert to property list compatible types
        let plistData = convertToPropertyListCompatible(queuedIssue)
        var queuedIssues = UserDefaults.standard.array(forKey: "queued_supabase_issues") as? [[String: Any]] ?? []
        queuedIssues.append(plistData)
        UserDefaults.standard.set(queuedIssues, forKey: "queued_supabase_issues")
    }
    
    private func queueFloorCorrection(_ data: [String: Any]) {
        // Convert to property list compatible types
        let plistData = convertToPropertyListCompatible(data)
        var queuedCorrections = UserDefaults.standard.array(forKey: "queuedFloorCorrections") as? [[String: Any]] ?? []
        queuedCorrections.append(plistData)
        UserDefaults.standard.set(queuedCorrections, forKey: "queuedFloorCorrections")
        #if DEBUG
        print("📱 Queued floor correction for later sync")
        #endif
    }
    
    // MARK: - Queue Management for Offline Support
    private func queuePerformanceMetric(_ data: [String: Any]) {
        // Convert to property list compatible types
        let plistData = convertToPropertyListCompatible(data)
        var queuedMetrics = UserDefaults.standard.array(forKey: "queuedPerformanceMetrics") as? [[String: Any]] ?? []
        queuedMetrics.append(plistData)
        UserDefaults.standard.set(queuedMetrics, forKey: "queuedPerformanceMetrics")
        #if DEBUG
        print("📱 Queued performance metric for later sync")
        #endif
    }
    
    private func queueErrorLog(_ data: [String: Any]) {
        // Convert to property list compatible types
        let plistData = convertToPropertyListCompatible(data)
        var queuedErrors = UserDefaults.standard.array(forKey: "queuedErrorLogs") as? [[String: Any]] ?? []
        queuedErrors.append(plistData)
        UserDefaults.standard.set(queuedErrors, forKey: "queuedErrorLogs")
        #if DEBUG
        print("📱 Queued error log for later sync")
        #endif
    }
    
    private func queueUserAction(_ data: [String: Any]) {
        // Convert to property list compatible types
        let plistData = convertToPropertyListCompatible(data)
        var queuedActions = UserDefaults.standard.array(forKey: "queuedUserActions") as? [[String: Any]] ?? []
        queuedActions.append(plistData)
        UserDefaults.standard.set(queuedActions, forKey: "queuedUserActions")
        #if DEBUG
        print("�� Queued user action for later sync")
        #endif
    }
    
    // Helper function to convert data to property list compatible types
    private func convertToPropertyListCompatible(_ data: [String: Any]) -> [String: Any] {
        var converted: [String: Any] = [:]
        
        for (key, value) in data {
            switch value {
            case let boolValue as Bool:
                converted[key] = boolValue
            case let intValue as Int:
                converted[key] = intValue
            case let doubleValue as Double:
                converted[key] = doubleValue
            case let stringValue as String:
                converted[key] = stringValue
            case let dateValue as Date:
                converted[key] = dateValue.timeIntervalSince1970
            case let arrayValue as [Any]:
                // Recursively convert array elements
                let convertedArray = arrayValue.map { element -> Any in
                    if let dict = element as? [String: Any] {
                        return convertToPropertyListCompatible(dict)
                    }
                    return element
                }
                converted[key] = convertedArray
            case let dictValue as [String: Any]:
                // Recursively convert dictionary
                converted[key] = convertToPropertyListCompatible(dictValue)
            case is NSNull:
                converted[key] = NSNull()
            default:
                // Convert unknown types to string representation
                converted[key] = String(describing: value)
            }
        }
        
        return converted
    }
    
    private func getDeviceInfo() -> [String: String] {
        let device = UIDevice.current
        return [
            "model": device.model,
            "system": device.systemName,
            "version": device.systemVersion,
            "name": device.name
        ]
    }
    
    private func getAppVersion() -> String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }
    
    // MARK: - Enhanced Network Request Monitoring
    private func sendRequestWithMonitoring(endpoint: String, method: String, data: [String: Any], completion: @escaping (Bool) -> Void) {
        let startTime = Date()
        
        sendRequest(endpoint: endpoint, method: method, data: data) { success in
            let duration = Date().timeIntervalSince(startTime)
            
            // Log network performance
            self.logPerformanceMetric(
                metricName: "network_request_time",
                value: duration,
                unit: "seconds",
                context: [
                    "endpoint": endpoint,
                    "method": method,
                    "success": success
                ]
            ) { _ in }
            
            completion(success)
        }
    }
    
    // MARK: - Sync Queued Data
    
    func syncQueuedData() {
        guard isOnline else { return }
        
        // Sync queued issues
        if let queuedIssues = UserDefaults.standard.array(forKey: "queued_supabase_issues") as? [[String: Any]] {
            for issueData in queuedIssues {
                if let notes = issueData["notes"] as? String,
                   let issueType = issueData["issue_type"] as? String,
                   let latitude = issueData["latitude"] as? Double,
                   let longitude = issueData["longitude"] as? Double,
                   let address = issueData["address"] as? String {
                    
                    let location = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
                    logUserIssue(notes: notes, issueType: issueType, location: location, address: address) { _ in }
                }
            }
            
            // Clear queued issues after sync
            UserDefaults.standard.removeObject(forKey: "queued_supabase_issues")
        }
    }
    
    // MARK: - Test Supabase Connection
    
    func testSupabaseConnection(completion: @escaping (Bool) -> Void) {
        // First test: Simple health check
        guard let url = URL(string: baseURL + "/rest/v1/") else {
            #if DEBUG
            print("❌ Supabase: Invalid test URL")
            #endif
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                #if DEBUG
                print("❌ Supabase: Test connection failed: \(error)")
                #endif
                completion(false)
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                let success = (200...299).contains(httpResponse.statusCode)
                if success {
                    #if DEBUG
                    print("✅ Supabase: Basic connection successful")
                    #endif
                    
                    // Now test the specific table
                    self.testUserActionsTable { tableSuccess in
                        completion(tableSuccess)
                    }
                } else {
                    #if DEBUG
                    print("❌ Supabase: Basic connection failed - HTTP \(httpResponse.statusCode)")
                    if let data = data, let responseString = String(data: data, encoding: .utf8) {
                        print("❌ Supabase: Test response: \(responseString)")
                    }
                    #endif
                    completion(false)
                }
            } else {
                completion(false)
            }
        }
        
        task.resume()
    }
    
    private func testUserActionsTable(completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: baseURL + "/rest/v1/user_actions?select=count") else {
            #if DEBUG
            print("❌ Supabase: Invalid table test URL")
            #endif
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                #if DEBUG
                print("❌ Supabase: Table test failed: \(error)")
                #endif
                completion(false)
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                let success = (200...299).contains(httpResponse.statusCode)
                if success {
                    #if DEBUG
                    print("✅ Supabase: user_actions table accessible")
                    #endif
                    completion(true)
                } else {
                    #if DEBUG
                    print("❌ Supabase: user_actions table test failed - HTTP \(httpResponse.statusCode)")
                    if let data = data, let responseString = String(data: data, encoding: .utf8) {
                        print("❌ Supabase: Table test response: \(responseString)")
                    }
                    #endif
                    completion(false)
                }
            } else {
                completion(false)
            }
        }
        
        task.resume()
    }
} 