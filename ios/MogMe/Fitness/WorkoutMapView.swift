import MapKit
import SwiftUI

struct WorkoutMapView: View {
    let route: [GPSPoint]
    let isHard: Bool

    var body: some View {
        Map {
            if route.count >= 2 {
                MapPolyline(coordinates: route.map(\.coordinate))
                    .stroke(isHard ? Color.orange : MogTheme.gold, lineWidth: 4)
            }
            if let last = route.last {
                Annotation("You", coordinate: last.coordinate) {
                    Circle()
                        .fill(MogTheme.gold)
                        .frame(width: 12, height: 12)
                        .overlay(Circle().stroke(Color.black.opacity(0.4), lineWidth: 1))
                }
            }
        }
        .mapStyle(.standard(elevation: .realistic))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
