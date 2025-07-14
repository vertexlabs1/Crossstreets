//
//  AppIntent.swift
//  CrossStreetsWidget
//
//  Created by Tyler Amos 24 on 7/11/25.
//

import WidgetKit
import AppIntents

struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "CrossStreets Widget Configuration" }
    static var description: IntentDescription { "Configure your parking widget display options." }

    @Parameter(title: "Show Garage Name", default: true)
    var showGarageName: Bool
    
    @Parameter(title: "Show Floor Info", default: true)
    var showFloorInfo: Bool
    
    @Parameter(title: "Show Time Ago", default: true)
    var showTimeAgo: Bool
}
