
///https://medium.com/combo-fm/hacking-with-ibeacons-what-i-wish-id-known-475968f790f7
///https://developer.apple.com/documentation/corelocation/turning_an_ios_device_into_an_ibeacon_device
///https://www.appcoda.com/ibeacons-swift-tutorial/

import CoreLocation
import CoreBluetooth
import UIKit
import UserNotifications

class Beacon {
    let major: UInt16
    let minor: UInt16
    let accuracy: CLLocationAccuracy
    let proximity: CLProximity
    
    init(major: UInt16, minor: UInt16, accuracy: CLLocationAccuracy, proximity: CLProximity) {
        self.major = major
        self.minor = minor
        self.accuracy = accuracy
        self.proximity = proximity
    }
}

extension Beacon: Hashable, Equatable {
    public static func ==(lhs: Beacon, rhs: Beacon) -> Bool {
        return lhs.major == rhs.major
            && lhs.minor == rhs.minor
            && lhs.accuracy == rhs.accuracy
            && lhs.proximity == rhs.proximity
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(major)
        hasher.combine(minor)
        hasher.combine(accuracy)
        hasher.combine(proximity)
    }
}


class ViewController: UIViewController, CBPeripheralManagerDelegate {
    let uuid = UUID(uuidString: "F34A1A1F-500F-48FB-AFAA-9584D641D7B1")
    var beaconRegion: CLBeaconRegion!
    var bluetoothPeripheralManager: CBPeripheralManager!
    var isBroadcasting = false
    var dataDictionary = NSDictionary()
    var locationManager: CLLocationManager!
    var isSearchingForBeacons = false
    var foundBeacons = Set<Beacon>()
    
    lazy var button: UIButton = {
        let button = UIButton()
        button.setTitle("Start", for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.titleLabel?.textColor = .white
        button.addTarget(self, action: #selector(switchMonitoringState), for: .touchUpInside)
        button.backgroundColor = .blue
        return button
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(button)
        
        addBroadcastingButton()
        //initPeripheralAdvertiser()
        
        locationManager = CLLocationManager()
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.delegate = self
        locationManager.requestAlwaysAuthorization()

        //montiring iBeacons range
        initBeaconMonitor()
        beaconRegion.notifyOnEntry = true
        beaconRegion.notifyOnExit = true
        beaconRegion.notifyEntryStateOnDisplay = true
    }
    
    func initBeaconMonitor() {
        beaconRegion = CLBeaconRegion(proximityUUID: uuid!, identifier: "com.2cloz.AXT45")
    }
    
    func initPeripheralAdvertiser() {
        bluetoothPeripheralManager = CBPeripheralManager(delegate: self, queue: .main)
    }
    
    func addBroadcastingButton() {
        button.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        button.centerYAnchor.constraint(equalTo: view.centerYAnchor).isActive = true
        button.widthAnchor.constraint(equalToConstant: 100).isActive = true
        button.heightAnchor.constraint(equalToConstant: 100).isActive = true
    }
    
    @objc
    func switchMonitoringState() {
        if !isSearchingForBeacons {
            button.setTitle("Stop", for: .normal)
            button.backgroundColor = .darkGray
            
            locationManager.startMonitoring(for: beaconRegion)
            locationManager.startUpdatingLocation()
            print("monitoring beacons.....")
        } else {
            locationManager.stopMonitoring(for: beaconRegion)
            locationManager.stopRangingBeacons(in: beaconRegion)
            locationManager.stopUpdatingLocation()
            
            button.setTitle("Start", for: .normal)
            button.backgroundColor = .blue
            print("not monitoring beacons")
            initPeripheralAdvertiser()
        }
        
        isSearchingForBeacons = !isSearchingForBeacons
    }
    
    @objc
    func switchBroadcastingState() {
        if !isBroadcasting {
            button.setTitle("Stop", for: .normal)
            button.backgroundColor = .darkGray
            
            if bluetoothPeripheralManager.state == CBManagerState.poweredOn {
                //1.initialize the beacon region & start advertising the region.
                let major: CLBeaconMajorValue = UInt16(100)
                let minor: CLBeaconMinorValue = UInt16(50)
                beaconRegion = CLBeaconRegion(proximityUUID: uuid!, major: major, minor: minor, identifier: "com.2cloz.Elon")
                
                //2.we must advertise the above region, so when a receiver app is nearby to be able to identify the beacon.
                dataDictionary = beaconRegion.peripheralData(withMeasuredPower: -58)
                bluetoothPeripheralManager.startAdvertising(((dataDictionary as NSDictionary) as! [String : Any]))
                print("Broadcasting...")
                isBroadcasting = true
            }
        } else {
            button.setTitle("Start", for: .normal)
            button.backgroundColor = .blue
            
            //We’ll stop the beacon advertising.
            //We’ll indicate that the device is no longer broadcasting.
            bluetoothPeripheralManager.stopAdvertising()
            isBroadcasting = false
            print("Broadcasting stopped")
        }
    }
    
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        var statusMessage = ""
        switch peripheral.state {
        case .poweredOn:
            statusMessage = "Bluetooth Status: Turned On"
        case .poweredOff:
            if isBroadcasting {
                switchBroadcastingState()
            }
            statusMessage = "Bluetooth Status: Turned Off"
        case .resetting:
            statusMessage = "Bluetooth Status: Resetting"
        case .unauthorized:
            statusMessage = "Bluetooth Status: Not Authorized"
        case .unsupported:
            statusMessage = "Bluetooth Status: Not Supported"
        default:
            statusMessage = "Bluetooth Status: Unknown"
        }
        print(statusMessage)
    }
}

extension ViewController: CLLocationManagerDelegate {
    
    func locationManager(_ manager: CLLocationManager, didStartMonitoringFor region: CLRegion) {
        locationManager.requestState(for: region)
    }
    
    func locationManager(_ manager: CLLocationManager, didDetermineState state: CLRegionState, for region: CLRegion) {
        
        if state == CLRegionState.inside {
            locationManager.startRangingBeacons(in: beaconRegion)
        }
        else {
            locationManager.stopRangingBeacons(in: beaconRegion)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        if let localRegion = region as? CLBeaconRegion {
            print(localRegion.identifier)
        }
        print("Beacon in range")
    }
    
    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        print("No beacons in range")
    }
    
    func locationManager(_ manager: CLLocationManager, didRangeBeacons beacons: [CLBeacon], in region: CLBeaconRegion) {
        if beacons.count > 0 {
            print(region.identifier)

            for beacon in beacons {
               
                var proximityMessage = String()
                switch beacon.proximity {
                case .immediate:
                    proximityMessage = "Very close"
                    
                case .near:
                    proximityMessage = "Near"
                    
                case .far:
                    proximityMessage = "Far"
                    
                default:
                    proximityMessage = "Where's the beacon?"
                }
                
                let detail = "Beacon Details:\nMajor = " + String(beacon.major.intValue) + "\nMinor = " + String(beacon.minor.intValue) + "\nDistance: " + proximityMessage
                print(detail)
            }
        }
        
        func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
            print(error)
        }
        
        func locationManager(manager: CLLocationManager!, monitoringDidFailForRegion region: CLRegion!, withError error: NSError!) {
            print(error)
        }
        
        func locationManager(manager: CLLocationManager!, rangingBeaconsDidFailForRegion region: CLBeaconRegion!, withError error: NSError!) {
            print(error)
        }
    }
}

//Now we will track all the nearby devices that advertise themselves as iBeacons
