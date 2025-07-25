import Foundation
import CoreLocation

struct GarageDetectionResult: Equatable {
    let isInGarage: Bool
    let garageName: String?
    
    init(isInGarage: Bool, garageName: String?) {
        self.isInGarage = isInGarage
        self.garageName = garageName
    }
}

struct ParkingLocation: Codable, Identifiable, Equatable {
    let id: UUID
    let coordinate: CLLocationCoordinate2D
    var address: String
    var floor: String?
    let timestamp: Date
    let garageName: String?
    var notes: String?
    var photoPaths: [String]? // Store file paths to photos
    
    static func == (lhs: ParkingLocation, rhs: ParkingLocation) -> Bool {
        lhs.id == rhs.id
    }
}
