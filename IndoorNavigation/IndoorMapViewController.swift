/*
See LICENSE folder for this sample’s licensing information.

Abstract:
The main view controller.
*/

import UIKit
import CoreLocation
import MapKit
import Zip
import UserNotifications

@available(iOS 15.0, *)
class IndoorMapViewController: UIViewController, MKMapViewDelegate, LevelPickerDelegate, CLLocationManagerDelegate, UNUserNotificationCenterDelegate {
    @IBOutlet var mapView: MKMapView!
    private let locationManager = CLLocationManager()
    @IBOutlet var levelPicker: LevelPickerView!
    
    var venue: Venue?
    private var levels: [Level] = []
    private var currentLevelFeatures = [StylableFeature]()
    private var currentLevelOverlays = [MKOverlay]()
    private var currentLevelAnnotations = [MKAnnotation]()
    let pointAnnotationViewIdentifier = "PointAnnotationView"
    let labelAnnotationViewIdentifier = "LabelAnnotationView"
    
//    let locationManager = CLLocationManager()
    var foundBeacons = [CLBeacon]()
    
    var beaconRegion: CLBeaconRegion!
    
    var isRanging = false
    
    // MARK: - View life cycle
    override func viewDidLoad() {
        super.viewDidLoad()

        // Request location authorization so the user's current location can be displayed on the map
        locationManager.requestWhenInUseAuthorization()

        self.mapView.delegate = self
        self.mapView.register(PointAnnotationView.self, forAnnotationViewWithReuseIdentifier: pointAnnotationViewIdentifier)
        self.mapView.register(LabelAnnotationView.self, forAnnotationViewWithReuseIdentifier: labelAnnotationViewIdentifier)
        
        Task {
            let unzipDirectory = try await fetchImdfFileData()
            do {
                let imdfDecoder = IMDFDecoder()
                venue = try imdfDecoder.decode(unzipDirectory.appendingPathComponent("IMDFData"))
            } catch let error {
                print(error)
            }
        
            // You might have multiple levels per ordinal. A selected level picker item displays all levels with the same ordinal.
            if let levelsByOrdinal = self.venue?.levelsByOrdinal {
                let levels = levelsByOrdinal.mapValues { (levels: [Level]) -> [Level] in
                    // Choose indoor level over outdoor level
                    if let level = levels.first(where: { $0.properties.outdoor == false }) {
                        return [level]
                    } else {
                        return [levels.first!]
                    }
                }.flatMap({ $0.value })
                
                // Sort levels by their ordinal numbers
                self.levels = levels.sorted(by: { $0.properties.ordinal > $1.properties.ordinal })
            }
            
            // Set the map view's region to enclose the venue
            if let venue = venue, let venueOverlay = venue.geometry[0] as? MKOverlay {
                self.mapView.setVisibleMapRect(venueOverlay.boundingMapRect, edgePadding:
                                                UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20), animated: false)
            }
            
            // Display a default level at start, for example a level with ordinal 0
            showFeaturesForOrdinal(0)
            
            // Setup the level picker with the shortName of each level
            setupLevelPicker()
        }
        
        //temp
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            print("Permission granted? \(granted)")
        }
        UNUserNotificationCenter.current().delegate = self
        
        locationManager.delegate = self // Location Manager 이벤트 핸들러 작성을 위해 CLLocationManagerDelegate 프로토콜 구현체로서 self 객체 할당
        
        let uuid = UUID(uuidString: "fda50693-a4e2-4fb1-afcf-c6eb07647825")!
        let major = 10001
        let minor = 19641
        beaconRegion = CLBeaconRegion(uuid: uuid, major: CLBeaconMajorValue(major), minor: CLBeaconMinorValue(minor), identifier: "\(uuid.uuidString):\(major):\(minor)")
                
        if CLLocationManager.authorizationStatus() != .authorizedAlways {
            locationManager.requestAlwaysAuthorization()
        } else {
            locationManager.startMonitoring(for: beaconRegion)
        }
    }
    
    private func showFeaturesForOrdinal(_ ordinal: Int) {
        guard self.venue != nil else {
            return
        }

        // Clear out the previously-displayed level's geometry
        self.currentLevelFeatures.removeAll()
        self.mapView.removeOverlays(self.currentLevelOverlays)
        self.mapView.removeAnnotations(self.currentLevelAnnotations)
        self.currentLevelAnnotations.removeAll()
        self.currentLevelOverlays.removeAll()

        // Display the level's footprint, unit footprints, opening geometry, and occupant annotations
        if let levels = self.venue?.levelsByOrdinal[ordinal] {
            for level in levels {
                self.currentLevelFeatures.append(level)
                self.currentLevelFeatures += level.units
                self.currentLevelFeatures += level.openings
                
                let occupants = level.units.flatMap({ $0.occupants })
                let amenities = level.units.flatMap({ $0.amenities })
                self.currentLevelAnnotations += occupants
                self.currentLevelAnnotations += amenities
            }
        }
        
        let currentLevelGeometry = self.currentLevelFeatures.flatMap({ $0.geometry })
        self.currentLevelOverlays = currentLevelGeometry.compactMap({ $0 as? MKOverlay })

        // Add the current level's geometry to the map
        self.mapView.addOverlays(self.currentLevelOverlays)
        self.mapView.addAnnotations(self.currentLevelAnnotations)
    }
    
    private func setupLevelPicker() {
        // Use the level's short name for a level picker item display name
        self.levelPicker.levelNames = self.levels.map {
            if let shortName = $0.properties.shortName.bestLocalizedValue {
                return shortName
            } else {
                return "\($0.properties.ordinal)"
            }
        }
        
        // Begin by displaying the level-specific information for Ordinal 0 (which is not necessarily the first level in the list).
        if let baseLevel = levels.first(where: { $0.properties.ordinal == 0 }) {
            levelPicker.selectedIndex = self.levels.firstIndex(of: baseLevel)!
        }
    }

    // MARK: - MKMapViewDelegate
    
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        guard let shape = overlay as? (MKShape & MKGeoJSONObject),
            let feature = currentLevelFeatures.first( where: { $0.geometry.contains( where: { $0 == shape }) }) else {
            return MKOverlayRenderer(overlay: overlay)
        }

        let renderer: MKOverlayPathRenderer
        switch overlay {
        case is MKMultiPolygon:
            renderer = MKMultiPolygonRenderer(overlay: overlay)
        case is MKPolygon:
            renderer = MKPolygonRenderer(overlay: overlay)
        case is MKMultiPolyline:
            renderer = MKMultiPolylineRenderer(overlay: overlay)
        case is MKPolyline:
            renderer = MKPolylineRenderer(overlay: overlay)
        default:
            return MKOverlayRenderer(overlay: overlay)
        }

        // Configure the overlay renderer's display properties in feature-specific ways.
        feature.configure(overlayRenderer: renderer)

        return renderer
    }

    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if annotation is MKUserLocation {
            return nil
        }

        if let stylableFeature = annotation as? StylableFeature {
            if stylableFeature is Occupant {
                let annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: labelAnnotationViewIdentifier, for: annotation)
                stylableFeature.configure(annotationView: annotationView)
                return annotationView
            } else {
                let annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: pointAnnotationViewIdentifier, for: annotation)
                stylableFeature.configure(annotationView: annotationView)
                return annotationView
            }
        }

        return nil
    }

    func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
        guard let venue = self.venue, let location = userLocation.location else {
            return
        }

        // Display location only if the user is inside this venue.
        var isUserInsideVenue = false
        let userMapPoint = MKMapPoint(location.coordinate)
        for geometry in venue.geometry {
            guard let overlay = geometry as? MKOverlay else {
                continue
            }

            if overlay.boundingMapRect.contains(userMapPoint) {
                isUserInsideVenue = true
                break
            }
        }

        guard isUserInsideVenue else {
            return
        }

        // If the device knows which level the user is physically on, automatically switch to that level.
        if let ordinal = location.floor?.level {
            showFeaturesForOrdinal(ordinal)
        }
    }
    
    // MARK: - LevelPickerDelegate
    
    func selectedLevelDidChange(selectedIndex: Int) {
        precondition(selectedIndex >= 0 && selectedIndex < self.levels.count)
        let selectedLevel = self.levels[selectedIndex]
        showFeaturesForOrdinal(selectedLevel.properties.ordinal)
    }
    
    // MARK: temp notification configuration
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        switch status {
        case .authorizedAlways:
            print("status: authorizedAlways")
            // always permission granted
        case .authorizedWhenInUse:
            print("status: authorizedWhenInUse")
            // when-in-use permission granted
        default:
            print("authorisation not granted") // handle appropriately
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didDetermineState state: CLRegionState, for region: CLRegion) {
        print("Did determine state for region \(region)")
        let beaconId = region.identifier.split(separator: ":")
        let major = beaconId[1]
        let minor = beaconId[2]
        
        switch state {
        case .inside:
            Task {
                await postNotification(major: Int(major)!, minor: Int(minor)!)
            }

            print("Device is within the beacon's range")
        case .outside:
            print("Device is outside the beacon's range")
        case .unknown:
            print("Beacon’s range is unknown")
        }
    }
    
    // beacon region 진입 이벤트 핸들러
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        print(region.identifier)
    }
    
    // beacon region 탈출 이벤트 핸들러
    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        print("didExit")
    }
    
    func postNotification(major: Int, minor: Int) async {
        let beaconModel: BeaconModel
        do {
            beaconModel = try await getBeaconData(major: major, minor: minor)
        } catch (let error) {
            print(error)
            return
        }
        let venueName = beaconModel.venue.name
        let content = UNMutableNotificationContent()
        content.title = "\(venueName) 진입"
        content.body = "앱을 통해 실내 공간 정보를 확인하세요."
        content.sound = UNNotificationSound.default
        
        let request = UNNotificationRequest(identifier: "EntryNotification", content: content, trigger: nil)
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch let error {
            print(error.localizedDescription)
        }
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler(.alert)
    }
}
