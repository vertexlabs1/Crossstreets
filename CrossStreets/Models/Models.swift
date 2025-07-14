import Foundation
import CoreLocation

struct ParkingLocation: Codable, Identifiable, Equatable {
    let id: UUID
    let coordinate: CLLocationCoordinate2D
    var address: String
    var floor: String?
    let timestamp: Date
    let garageName: String?
    
    static func == (lhs: ParkingLocation, rhs: ParkingLocation) -> Bool {
        lhs.id == rhs.id
    }
}
