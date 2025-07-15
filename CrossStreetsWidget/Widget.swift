import WidgetKit
import SwiftUI
import CoreLocation

struct ParkingLocation: Codable {
    let id: UUID
    let coordinate: CLLocationCoordinate2D
    let address: String
    let floor: String?
    let timestamp: Date
    let garageName: String?
}

extension CLLocationCoordinate2D: Codable {
    enum CodingKeys: String, CodingKey {
        case latitude
        case longitude
    }
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(latitude, forKey: .latitude)
        try container.encode(longitude, forKey: .longitude)
    }
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let latitude = try container.decode(Double.self, forKey: .latitude)
        let longitude = try container.decode(Double.self, forKey: .longitude)
        self.init(latitude: latitude, longitude: longitude)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let address: String?
    let garageName: String?
    let floor: String?
    let timestamp: Date?
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), address: "123 Main St", garageName: "Downtown Garage", floor: "F2", timestamp: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> Void) {
        completion(getEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> Void) {
        let entry = getEntry()
        let timeline = Timeline(entries: [entry], policy: .atEnd)
        completion(timeline)
    }

    private func getEntry() -> SimpleEntry {
        let sharedDefaults = UserDefaults(suiteName: "group.com.tyler.crossstreets")
        if let data = sharedDefaults?.data(forKey: "parkedLocation"),
           let location = try? JSONDecoder().decode(ParkingLocation.self, from: data) {
            return SimpleEntry(date: Date(), address: location.address, garageName: location.garageName, floor: location.floor, timestamp: location.timestamp)
        } else {
            return SimpleEntry(date: Date(), address: nil, garageName: nil, floor: nil, timestamp: nil)
        }
    }
}

struct CrossStreetsWidgetEntryView: View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        Link(destination: URL(string: "crossstreets://")!) {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(LinearGradient(gradient: Gradient(colors: [Color.blue.opacity(0.18), Color(.systemBackground)]), startPoint: .top, endPoint: .bottom))
                
                VStack(spacing: 8) {
                    // Header with car icon
                    HStack {
                        Image(systemName: "car.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.blue)
                        Text("CrossStreets")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.primary)
                        Spacer()
                    }
                    
                    Spacer()
                    
                    // Main content
                    if let garage = entry.garageName, let floor = entry.floor {
                        // Garage parking
                        VStack(spacing: 4) {
                            Text(garage)
                                .font(.system(size: family == .systemSmall ? 14 : 16, weight: .semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                            
                            let displayFloor = (floor == "RF") ? "Roof" : floor
                            Text("Floor \(displayFloor)")
                                .font(.system(size: family == .systemSmall ? 12 : 14))
                                .foregroundColor(.blue)
                        }
                    } else if let address = entry.address {
                        // Street parking
                        Text(address)
                            .font(.system(size: family == .systemSmall ? 12 : 14, weight: .medium))
                            .lineLimit(2)
                            .minimumScaleFactor(0.7)
                            .multilineTextAlignment(.center)
                    } else {
                        // No parking
                        VStack(spacing: 4) {
                            Image(systemName: "car.circle")
                                .font(.system(size: 24))
                                .foregroundColor(.gray)
                            Text("No car parked")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    // Time info
                    if let timestamp = entry.timestamp {
                        Text(timeAgo(since: timestamp))
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(12)
            }
            .containerBackground(Color.clear, for: .widget)
        }
    }

    func timeAgo(since date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

@main
struct CrossStreetsWidget: Widget {
    let kind: String = "CrossStreetsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            CrossStreetsWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("CrossStreets")
        .description("Shows your parking location and time.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
