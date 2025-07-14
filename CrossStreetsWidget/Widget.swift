import WidgetKit
import SwiftUI
import CoreLocation
import MapKit

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
    let coordinate: CLLocationCoordinate2D?
    let timestamp: Date?
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), address: "123 Main St", garageName: "Downtown Garage", floor: "F2", coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194), timestamp: Date())
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
            return SimpleEntry(date: Date(), address: location.address, garageName: location.garageName, floor: location.floor, coordinate: location.coordinate, timestamp: location.timestamp)
        } else {
            return SimpleEntry(date: Date(), address: nil, garageName: nil, floor: nil, coordinate: nil, timestamp: nil)
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
                VStack(spacing: 10) {
                    if let coordinate = entry.coordinate {
                        // --- Map snapshot (mocked with static image for now) ---
                        AsyncImage(url: mapSnapshotURL(for: coordinate)) { image in
                            image.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Color(.systemGray5)
                        }
                        .frame(height: family == .systemSmall ? 80 : 120)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            Image(systemName: "mappin.circle.fill")
                                .font(.system(size: 32))
                                .foregroundColor(.red)
                                .offset(y: -10)
                        , alignment: .center)
                    }
                    // ---
                    if let garage = entry.garageName, let floor = entry.floor {
                        let displayFloor = (floor == "RF") ? "Roof" : floor
                        Text(garage)
                            .font(.headline)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Text("Floor \(displayFloor)")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                        if let t = entry.timestamp {
                            Text(timeAgo(since: t))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else if let address = entry.address {
                        Text(address)
                            .font(.headline)
                            .lineLimit(2)
                            .minimumScaleFactor(0.7)
                        if let t = entry.timestamp {
                            Text(timeAgo(since: t))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        VStack(spacing: 8) {
                            Image(systemName: "car.circle")
                                .font(.system(size: 32))
                                .foregroundColor(.gray)
                            Text("No car parked")
                                .font(.headline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
            }
            .containerBackground(Color.clear, for: .widget)
        }
    }

    // Mocked static map snapshot URL (replace with real snapshotter for production)
    func mapSnapshotURL(for coordinate: CLLocationCoordinate2D) -> URL? {
        // For demo: use a static map image from Mapbox Static API or similar
        // Replace with your own API key or snapshot logic
        let lat = coordinate.latitude
        let lon = coordinate.longitude
        let urlString = "https://api.mapbox.com/styles/v1/mapbox/streets-v11/static/pin-s-car+285A98(\(lon),\(lat))/\(lon),\(lat),16,0/400x200?access_token=pk.eyJ1IjoibWFwYm94dXNlciIsImEiOiJja2xqZ2Z2b3YwM2JwMnBvN2Z6b2J6b2JzIn0.2v9wQw1Qw1Qw1Qw1Qw1Qw1Q"
        return URL(string: urlString)
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
        .description("Shows your parking info.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
