import Foundation
import CoreLocation
import SwiftUI

extension CLLocationCoordinate2D: Codable {
    enum CodingKeys: String, CodingKey {
        case latitude, longitude
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let latitude = try container.decode(Double.self, forKey: .latitude)
        let longitude = try container.decode(Double.self, forKey: .longitude)
        self.init(latitude: latitude, longitude: longitude)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(latitude, forKey: .latitude)
        try container.encode(longitude, forKey: .longitude)
    }
}

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let width = rect.size.width
        let height = rect.size.height
        
        // Ensure radius doesn't exceed half the smallest dimension
        let effectiveRadius = min(radius, min(width, height) / 2)
        
        // Start from top-left
        path.move(to: CGPoint(x: corners.contains(.topLeft) ? effectiveRadius : 0, y: 0))
        
        // Top edge
        path.addLine(to: CGPoint(x: width - (corners.contains(.topRight) ? effectiveRadius : 0), y: 0))
        
        // Top-right corner
        if corners.contains(.topRight) {
            path.addArc(center: CGPoint(x: width - effectiveRadius, y: effectiveRadius),
                       radius: effectiveRadius,
                       startAngle: Angle(degrees: -90),
                       endAngle: Angle(degrees: 0),
                       clockwise: false)
        } else {
            path.addLine(to: CGPoint(x: width, y: 0))
        }
        
        // Right edge
        path.addLine(to: CGPoint(x: width, y: height - (corners.contains(.bottomRight) ? effectiveRadius : 0)))
        
        // Bottom-right corner
        if corners.contains(.bottomRight) {
            path.addArc(center: CGPoint(x: width - effectiveRadius, y: height - effectiveRadius),
                       radius: effectiveRadius,
                       startAngle: Angle(degrees: 0),
                       endAngle: Angle(degrees: 90),
                       clockwise: false)
        } else {
            path.addLine(to: CGPoint(x: width, y: height))
        }
        
        // Bottom edge
        path.addLine(to: CGPoint(x: corners.contains(.bottomLeft) ? effectiveRadius : 0, y: height))
        
        // Bottom-left corner
        if corners.contains(.bottomLeft) {
            path.addArc(center: CGPoint(x: effectiveRadius, y: height - effectiveRadius),
                       radius: effectiveRadius,
                       startAngle: Angle(degrees: 90),
                       endAngle: Angle(degrees: 180),
                       clockwise: false)
        } else {
            path.addLine(to: CGPoint(x: 0, y: height))
        }
        
        // Left edge
        path.addLine(to: CGPoint(x: 0, y: corners.contains(.topLeft) ? effectiveRadius : 0))
        
        // Top-left corner
        if corners.contains(.topLeft) {
            path.addArc(center: CGPoint(x: effectiveRadius, y: effectiveRadius),
                       radius: effectiveRadius,
                       startAngle: Angle(degrees: 180),
                       endAngle: Angle(degrees: 270),
                       clockwise: false)
        }
        
        path.closeSubpath()
        return path
    }
}
