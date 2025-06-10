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
}

class MotionManager: NSObject, ObservableObject, WCSessionDelegate {
    private let motionManager = CMMotionManager()
    private var samples: [MotionSample] = []
    private var timer: Timer?
    private var sampleRate: Double = 20
    
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
        motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, _ in
            guard let self, let data = data else { return }
            let sample = MotionSample(
                timestamp: Date().timeIntervalSince1970,
                x: data.acceleration.x,
                y: data.acceleration.y,
                z: data.acceleration.z
            )
            self.samples.append(sample)
        }
    }
    
    func stopCollecting() {
        motionManager.stopAccelerometerUpdates()
        
    }
    
//    func exportAndSendCSV() {
////        let csvHeader = "timestamp,x,y,z\n"
////        let csvBody = samples.map { "\($0.timestamp),\($0.x),\($0.y),\($0.z)"}.joined(separator: "\n")
////        let csvString = csvHeader + csvBody
//        let csvHeader = "time,x,y,z\r\n"
//        let formatter = DateFormatter()
//        formatter.dateFormat = "HH:mm:ss" // or "h:mm:ss a" for 12-hour
//
//        let csvBody = samples.map { sample in
//            let date = Date(timeIntervalSince1970: sample.timestamp)
//            let timeString = formatter.string(from: date)
//            return "\(timeString),\(sample.x),\(sample.y),\(sample.z)"
//        }.joined(separator: "\r\n")
//
//        let csvString = csvHeader + csvBody
//        let fileName = "MotionData-\(Int(Date().timeIntervalSince1970)).csv"
//        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
//        do {
//            try csvString.write(to: tempURL, atomically: true, encoding: .utf8)
//            if WCSession.default.isReachable {
//                WCSession.default.transferFile(tempURL, metadata: ["filename": fileName])
//                WKInterfaceDevice.current().play(.success)
//                
//            } else {
//                WKInterfaceDevice.current().play(.failure)
//            }
//        } catch {
//            WKInterfaceDevice.current().play(.failure)
//        }
//        
//    }
    func exportAndSendCSV() {
        // 1. Create unique filename with formatted timestamp
        let filenameFormatter = DateFormatter()
        filenameFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let fileName = "MotionData-\(filenameFormatter.string(from: Date())).csv"
        
        // 2. Format CSV content
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm:ss" // or "h:mm:ss a" for 12-hour format
        
        let csvHeader = "time,x,y,z\n" // Use \n instead of \r\n
        let csvBody = samples.map { sample in
            let date = Date(timeIntervalSince1970: sample.timestamp)
            let timeString = timeFormatter.string(from: date)
            return "\(timeString),\(sample.x),\(sample.y),\(sample.z)"
        }.joined(separator: "\n") // Use \n instead of \r^n
        
        let csvString = csvHeader + csvBody
        
        // 3. File handling and transfer (unchanged)
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        do {
            try csvString.write(to: tempURL, atomically: true, encoding: .utf8)
            if WCSession.default.isReachable {
                WCSession.default.transferFile(tempURL, metadata: ["filename": fileName])
                WKInterfaceDevice.current().play(.success)
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
    
    func session (_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}
}
