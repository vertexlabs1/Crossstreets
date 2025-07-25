//
//  CrossStreetsTests.swift
//  CrossStreetsTests
//
//  Created by Tyler Amos 24 on 7/11/25.
//

import Testing
@testable import CrossStreets

struct CrossStreetsTests {

    @Test func testSupabaseManagerInitialization() async throws {
        // Test that SupabaseManager singleton can be initialized
        let manager = SupabaseManager.shared
        #expect(manager != nil)
    }
    
    @Test func testLocationManagerInitialization() async throws {
        // Test that LocationManager can be initialized
        let manager = LocationManager()
        #expect(manager != nil)
    }
    
    @Test func testPerformanceMonitorInitialization() async throws {
        // Test that PerformanceMonitor singleton can be initialized
        let monitor = PerformanceMonitor.shared
        #expect(monitor != nil)
    }

}
