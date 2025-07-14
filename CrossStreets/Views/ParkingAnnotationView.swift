import SwiftUI
import Foundation
import CoreLocation

struct ParkingAnnotationView: View {
    let location: ParkingLocation
    
    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: 48, height: 48)
                    .shadow(color: .black.opacity(0.2), radius: 5, y: 3)
                
                Circle()
                    .strokeBorder(Color.blue, lineWidth: 3)
                    .frame(width: 48, height: 48)
                
                Text(location.garageName != nil ? "🏢" : "🚗")
                    .font(.system(size: 26))
            }
            
            if let floor = location.floor {
                Text(floor)
                    .font(.system(size: 12, weight: .bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .offset(y: -4)
                    .shadow(color: .black.opacity(0.15), radius: 3, y: 2)
            }
        }
    }
}

#Preview {
    ParkingAnnotationView(location: ParkingLocation(id: UUID(), coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194), address: "Test", floor: "F2", timestamp: Date(), garageName: "Test Garage"))
}
