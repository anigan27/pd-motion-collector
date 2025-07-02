//
//  MotionManager.swift
//  Motion Collector
//
//  Created by Anika Ganu on 6/4/25.
//
import Foundation
import CoreMotion
import WatchConnectivity
import WatchKit

struct MotionSample: Codable {
    let timestamp: TimeInterval
        let x: Double
        let y: Double
        let z: Double
        // Add these new fields:
        let roll: Double
        let pitch: Double
        let yaw: Double
        let gravityX: Double
        let gravityY: Double
        let gravityZ: Double
        let rotationRateX: Double
        let rotationRateY: Double
        let rotationRateZ: Double
        let userAccelX: Double
        let userAccelY: Double
        let userAccelZ: Double
        let quatX: Double
        let quatY: Double
        let quatZ: Double
        let quatW: Double
}

class MotionManager: NSObject, ObservableObject, WCSessionDelegate {
    private let motionManager = CMMotionManager()
    private var samples: [MotionSample] = []
    private var timer: Timer?
    private var sampleRate: Double = 20
    private var latestRawAccel: CMAccelerometerData?
    @Published var showSentPopup = false
    @Published var currentTestType: String = "finger_tapping"
    @Published var useTimer: Bool = false
    
    override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
            
        }
    }
    
    func toggleCollection(isCollecting: Bool) {
        if isCollecting {
            startCollecting()
            WKInterfaceDevice.current().play(.start)
        } else {
            stopCollecting()
            WKInterfaceDevice.current().play(.stop)
        }
        
    }
    
    func startCollecting() {
        samples.removeAll()
        motionManager.accelerometerUpdateInterval = 1.0 / sampleRate
        motionManager.deviceMotionUpdateInterval = 1.0 / sampleRate
        
        // Start raw accelerometer updates
        motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, _ in
            self?.latestRawAccel = data
        }
        
        // Start device motion updates
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] data, _ in
            guard let self = self, let dmData = data, let accelData = self.latestRawAccel else { return }
            let sample = MotionSample(
                timestamp: Date().timeIntervalSince1970,
                x: accelData.acceleration.x,
                y: accelData.acceleration.y,
                z: accelData.acceleration.z,
                roll: dmData.attitude.roll,
                pitch: dmData.attitude.pitch,
                yaw: dmData.attitude.yaw,
                gravityX: dmData.gravity.x,
                gravityY: dmData.gravity.y,
                gravityZ: dmData.gravity.z,
                rotationRateX: dmData.rotationRate.x,
                rotationRateY: dmData.rotationRate.y,
                rotationRateZ: dmData.rotationRate.z,
                userAccelX: dmData.userAcceleration.x,
                userAccelY: dmData.userAcceleration.y,
                userAccelZ: dmData.userAcceleration.z,
                quatX: dmData.attitude.quaternion.x,
                quatY: dmData.attitude.quaternion.y,
                quatZ: dmData.attitude.quaternion.z,
                quatW: dmData.attitude.quaternion.w
            )
            self.samples.append(sample)
        }
    }
    
    func stopCollecting() {
        motionManager.stopAccelerometerUpdates()
        motionManager.stopDeviceMotionUpdates()
    }
    
    
    func exportAndSendCSV() {
        let filenameFormatter = DateFormatter()
        filenameFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let fileName = "\(currentTestType).csv"
        
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm:ss"
        
        let csvHeader = [
            "timestamp",
            "raw_accel_x", "raw_accel_y", "raw_accel_z",
            "roll", "pitch", "yaw",
            "gravity_x", "gravity_y", "gravity_z",
            "rotation_rate_x", "rotation_rate_y", "rotation_rate_z",
            "user_accel_x", "user_accel_y", "user_accel_z",
            "quaternion_x", "quaternion_y", "quaternion_z", "quaternion_w"
        ].joined(separator: ",")
        
        let csvBody = samples.map { sample in
            let date = Date(timeIntervalSince1970: sample.timestamp)
            let timeString = timeFormatter.string(from: date)
            return [
                timeString,
                String(sample.x), String(sample.y), String(sample.z),
                String(sample.roll), String(sample.pitch), String(sample.yaw),
                String(sample.gravityX), String(sample.gravityY), String(sample.gravityZ),
                String(sample.rotationRateX), String(sample.rotationRateY), String(sample.rotationRateZ),
                String(sample.userAccelX), String(sample.userAccelY), String(sample.userAccelZ),
                String(sample.quatX), String(sample.quatY), String(sample.quatZ), String(sample.quatW)
            ].joined(separator: ",")
        }.joined(separator: "\n")
        
        let csvString = csvHeader + "\n" + csvBody
        
        
        // 3. File handling and transfer (unchanged)
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        do {
            try csvString.write(to: tempURL, atomically: true, encoding: .utf8)
            if WCSession.default.isReachable {
                WCSession.default.transferFile(tempURL, metadata: ["filename": fileName])
                WKInterfaceDevice.current().play(.success)
                self.showSentPopup = true  // Show popup
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    self.showSentPopup = false  // Hide after 2 seconds
                }
            } else {
                WKInterfaceDevice.current().play(.failure)
            }
        } catch {
            WKInterfaceDevice.current().play(.failure)
        }
    }
    
    func deleteData() {
        samples.removeAll()
        WKInterfaceDevice.current().play(.directionDown)
    }
    
    // MARK: - WCSessionDelegate
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        // You can leave this empty or add print/debug info if you want
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        // Your logic to handle messages from the phone (e.g., set useTimer/currentTestType)
        if let needsTimer = message["needsTimer"] as? Bool {
            DispatchQueue.main.async {
                self.useTimer = needsTimer
            }
        }
        if let testType = message["testType"] as? String {
            DispatchQueue.main.async {
                self.currentTestType = testType
            }
        }
    }
}

