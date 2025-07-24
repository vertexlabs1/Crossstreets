import Foundation
import UIKit
import CoreLocation

class PerformanceMonitor: ObservableObject {
    static let shared = PerformanceMonitor()
    
    private var actionStartTimes: [String: Date] = [:]
    private var memoryWarningCount = 0
    private var lastMemoryCheck = Date()
    
    private init() {
        setupMemoryWarningObserver()
    }
    
    // MARK: - Action Timing
    func startAction(_ actionName: String) {
        actionStartTimes[actionName] = Date()
    }
    
    func endAction(_ actionName: String, screen: String, success: Bool = true, context: [String: Any] = [:]) {
        guard let startTime = actionStartTimes[actionName] else { return }
        
        let duration = Date().timeIntervalSince(startTime)
        actionStartTimes.removeValue(forKey: actionName)
        
        // Log user action with timing
        SupabaseManager.shared.logUserAction(
            action: actionName,
            screen: screen,
            success: success,
            duration: duration,
            context: context
        ) { _ in }
        
        // Log performance metric if duration is significant
        if duration > 0.5 { // Log actions taking more than 500ms
            SupabaseManager.shared.logPerformanceMetric(
                metricName: "action_duration",
                value: duration,
                unit: "seconds",
                context: [
                    "action": actionName,
                    "screen": screen,
                    "success": success
                ]
            ) { _ in }
        }
    }
    
    // MARK: - Memory Monitoring
    private func setupMemoryWarningObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }
    
    @objc private func handleMemoryWarning() {
        memoryWarningCount += 1
        
        SupabaseManager.shared.logError(
            errorType: "memory_warning",
            errorMessage: "Memory warning received",
            context: [
                "warning_count": memoryWarningCount,
                "available_memory": getAvailableMemory(),
                "time_since_last_warning": Date().timeIntervalSince(lastMemoryCheck)
            ]
        ) { _ in }
        
        lastMemoryCheck = Date()
    }
    
    private func getAvailableMemory() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return Double(info.resident_size) / 1024.0 / 1024.0 // Convert to MB
        }
        return 0.0
    }
    
    // MARK: - Error Logging
    func logError(_ error: Error, context: [String: Any] = [:]) {
        SupabaseManager.shared.logError(
            errorType: String(describing: type(of: error)),
            errorMessage: error.localizedDescription,
            stackTrace: Thread.callStackSymbols.joined(separator: "\n"),
            context: context
        ) { _ in }
    }
    
    // MARK: - Performance Metrics
    func logAppLaunchTime(_ duration: Double) {
        SupabaseManager.shared.logPerformanceMetric(
            metricName: "app_launch_time",
            value: duration,
            unit: "seconds"
        ) { _ in }
    }
    
    func logLocationAccuracy(_ accuracy: Double) {
        SupabaseManager.shared.logPerformanceMetric(
            metricName: "location_accuracy",
            value: accuracy,
            unit: "meters"
        ) { _ in }
    }
    
    func logGarageDetectionTime(_ duration: Double, success: Bool) {
        SupabaseManager.shared.logPerformanceMetric(
            metricName: "garage_detection_time",
            value: duration,
            unit: "seconds",
            context: ["success": success]
        ) { _ in }
    }
    
    func logFloorDetectionAccuracy(_ wasCorrect: Bool, altitudeSource: String) {
        SupabaseManager.shared.logPerformanceMetric(
            metricName: "floor_detection_accuracy",
            value: wasCorrect ? 1.0 : 0.0,
            unit: "percentage",
            context: ["altitude_source": altitudeSource]
        ) { _ in }
    }
    
    // MARK: - UI Performance
    func logUIResponseTime(_ duration: Double, action: String) {
        SupabaseManager.shared.logPerformanceMetric(
            metricName: "ui_response_time",
            value: duration,
            unit: "seconds",
            context: ["action": action]
        ) { _ in }
    }
    
    // MARK: - Network Performance
    func logNetworkRequest(_ endpoint: String, duration: Double, success: Bool) {
        SupabaseManager.shared.logPerformanceMetric(
            metricName: "network_request_time",
            value: duration,
            unit: "seconds",
            context: [
                "endpoint": endpoint,
                "success": success
            ]
        ) { _ in }
    }
} 