import CoreLocation
import XCTest
@testable import MogMe

final class GPSFilterTests: XCTestCase {
    func testRejectsNegativeAccuracy() {
        let bad = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 37.77, longitude: -122.41),
            altitude: 0,
            horizontalAccuracy: -1,
            verticalAccuracy: -1,
            timestamp: Date()
        )
        XCTAssertFalse(GPSFilter.accept(bad, previous: nil))
    }

    func testAcceptsFreshAccuratePoint() {
        let good = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 37.77, longitude: -122.41),
            altitude: 10,
            horizontalAccuracy: 8,
            verticalAccuracy: 4,
            timestamp: Date()
        )
        XCTAssertTrue(GPSFilter.accept(good, previous: nil))
    }

    func testRejectsTeleport() {
        let first = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 37.77, longitude: -122.41),
            altitude: 10,
            horizontalAccuracy: 6,
            verticalAccuracy: 4,
            timestamp: Date()
        )
        let jumped = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 37.87, longitude: -122.41),
            altitude: 10,
            horizontalAccuracy: 6,
            verticalAccuracy: 4,
            timestamp: Date().addingTimeInterval(1)
        )
        XCTAssertFalse(GPSFilter.accept(jumped, previous: first))
    }
}

final class FoodQueryTests: XCTestCase {
    func testPrefersProductNameOverNutritionHeading() {
        let ocr = """
        Nutrition Facts
        Calories 250
        KIND Dark Chocolate Nuts
        """
        XCTAssertEqual(FoodLookupService.bestQuery(from: ocr), "KIND Dark Chocolate Nuts")
    }
}
