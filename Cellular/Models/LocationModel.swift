//
//  LocationModel.swift
//  Cellular
//
//  Created by Xuan Han on 2/9/23.
//

import Foundation
import CoreLocation

class LocationModel: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    private var onAuthorized: () -> Void = {}
    private var onError: () -> Void = {}
    
    @Published var isLocationPermissionDenied = true
    
    override init() {
        super.init()
        locationManager.delegate = self
    }
    
    func registerForAuthorizationChanges(onAuthorized: @escaping () -> Void, onError: @escaping () -> Void) {
        self.onAuthorized = onAuthorized
        self.onError = onError
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorized:           // Location services are available.
            isLocationPermissionDenied = false
            onAuthorized()
            break
            
        case .restricted, .denied:  // Location services currently unavailable.
            isLocationPermissionDenied = true
            onError()
            break
            
        case .notDetermined:        // Authorization not determined yet.
            if bluetoothModel.isSetupComplete {
                isLocationPermissionDenied = true
                onError()
            } else {
                manager.requestWhenInUseAuthorization()
            }
            break
            
        default:
            break
        }
    }
}
