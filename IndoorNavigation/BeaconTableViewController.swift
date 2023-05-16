//
//  BeaconTableViewController.swift
//  IndoorNavigation
//
//  Created by Jongheon Kim on 2023/05/11.
//  Copyright © 2023 Apple. All rights reserved.
//

import UIKit
import CoreLocation
import UserNotifications

class ViewController: UITableViewController, CLLocationManagerDelegate, UNUserNotificationCenterDelegate {
    let locationManager = CLLocationManager()
    var foundBeacons = [CLBeacon]()
    
    var beaconRegion: CLBeaconRegion!
    
    var isRanging = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "iBeacons"
                
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            print("Permission granted? \(granted)")
        }
        UNUserNotificationCenter.current().delegate = self
        
        locationManager.delegate = self // Location Manager 이벤트 핸들러 작성을 위해 CLLocationManagerDelegate 프로토콜 구현체로서 self 객체 할당
        
        let uuid = UUID(uuidString: "fda50693-a4e2-4fb1-afcf-c6eb07647825")!
        beaconRegion = CLBeaconRegion(uuid: uuid, major: 10001, minor: 19641, identifier: uuid.uuidString)
                
        if CLLocationManager.authorizationStatus() != .authorizedAlways {
            locationManager.requestAlwaysAuthorization()
        } else {
            locationManager.startMonitoring(for: beaconRegion)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        switch status {
        case .authorizedAlways:
            print("temp")
            // always permission granted
        case .authorizedWhenInUse:
            print("temp")
            // when-in-use permission granted
        default:
            print("authorisation not granted") // handle appropriately
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didDetermineState state: CLRegionState, for region: CLRegion) {
        print("Did determine state for region \(region)")
     
        switch state {
        case .inside:
            print("Device is within the beacon's range")
        case .outside:
            print("Device is outside the beacon's range")
        case .unknown:
            print("Beacon’s range is unknown")
        }
    }
    
    // beacon region 진입 이벤트 핸들러
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        postNotification()
    }
    
    // beacon region 탈출 이벤트 핸들러
    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        print("didExit")
    }
    
    func postNotification() {
        let content = UNMutableNotificationContent()
        content.title = "한양대학교 제3공학관 진입"
        content.body = "앱을 통해 실내 공간 정보를 확인하세요."
        content.sound = UNNotificationSound.default
        
        let request = UNNotificationRequest(identifier: "EntryNotification", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error: \(error.localizedDescription)")
            }
        }
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler(.alert)
    }
}
