import Foundation
import CoreMotion
import WatchConnectivity
import WatchKit

struct MotionSample: Codable {
    let timestamp: String
    let raw_accel_x: Double; let raw_accel_y: Double; let raw_accel_z: Double
    let roll: Double; let pitch: Double; let yaw: Double
    let gravity_x: Double; let gravity_y: Double; let gravity_z: Double
    let user_accel_x: Double; let user_accel_y: Double; let user_accel_z: Double
    let rotation_rate_x: Double; let rotation_rate_y: Double; let rotation_rate_z: Double
    let quaternion_x: Double; let quaternion_y: Double; let quaternion_z: Double; let quaternion_w: Double
}

class MotionManager: NSObject, ObservableObject, WCSessionDelegate {
    private let motion = CMMotionManager()
    private let queue = OperationQueue()
    @Published var samples = [MotionSample]()
    @Published var isCollecting = false
    @Published var currentTest = "Waiting to start test..."
    @Published var sessionID = "default_session"
    @Published var lastErrorMsg = ""

    override init() {
        super.init()
        activateSession()
    }

    func activateSession() {
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    func startCollecting() {
        //WKExtension.shared().isIdleTimerDisabled = true
        DispatchQueue.main.async {
            self.isCollecting = true
            self.samples.removeAll()
        }
        if motion.isDeviceMotionActive {
            motion.stopDeviceMotionUpdates()
        }
        motion.deviceMotionUpdateInterval = 0.05
            motion.startDeviceMotionUpdates(to: queue) { [weak self] data, _ in
            guard let self = self, let d = data, self.isCollecting else { return }
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss"
            let timeString = formatter.string(from: Date())
            let acc = d.userAcceleration
            let grav = d.gravity
            let att = d.attitude
            let rot = d.rotationRate
            let quat = d.attitude.quaternion
            let rawAcc = self.motion.accelerometerData?.acceleration
            // Debug: Print out the main sensor values
            //print("[DEBUG] DeviceMotion: acc=(\(acc.x), \(acc.y), \(acc.z)), grav=(\(grav.x), \(grav.y), \(grav.z)), att=(\(att.roll), \(att.pitch), \(att.yaw)), rot=(\(rot.x), \(rot.y), \(rot.z)), quat=(\(quat.x), \(quat.y), \(quat.z), \(quat.w)), rawAcc=(\(rawAcc?.x ?? 0), \(rawAcc?.y ?? 0), \(rawAcc?.z ?? 0))")
            DispatchQueue.main.async {
                self.samples.append(MotionSample(
                    timestamp: timeString,
                    raw_accel_x: rawAcc?.x ?? 0,
                    raw_accel_y: rawAcc?.y ?? 0,
                    raw_accel_z: rawAcc?.z ?? 0,
                    roll: att.roll,
                    pitch: att.pitch,
                    yaw: att.yaw,
                    gravity_x: grav.x,
                    gravity_y: grav.y,
                    gravity_z: grav.z,
                    user_accel_x: acc.x,
                    user_accel_y: acc.y,
                    user_accel_z: acc.z,
                    rotation_rate_x: rot.x,
                    rotation_rate_y: rot.y,
                    rotation_rate_z: rot.z,
                    quaternion_x: quat.x,
                    quaternion_y: quat.y,
                    quaternion_z: quat.z,
                    quaternion_w: quat.w
                ))
            }
        }
        motion.startAccelerometerUpdates()
    }

    func stopCollecting() {
        //WKExtension.shared().isIdleTimerDisabled = false
        DispatchQueue.main.async { self.isCollecting = false }
        motion.stopDeviceMotionUpdates()
        motion.stopAccelerometerUpdates()
        exportAndSend()
    }

    func exportAndSend() {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MM-dd-yy_HHmmss" // Include hours, minutes, seconds
        let dateStr = dateFormatter.string(from: Date())
        let charset = Array("abcdefghijklmnopqrstuvwxyz0123456789")
        let rand = String((0..<5).compactMap { _ in charset.randomElement() })
        let name = currentTest
            .lowercased()
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "-", with: "_")
        let fileName = "\(name)_\(dateStr)_\(rand).csv"
        let headers = [
            "timestamp", "raw_accel_x", "raw_accel_y", "raw_accel_z", "roll", "pitch", "yaw",
            "gravity_x", "gravity_y", "gravity_z",
            "user_accel_x", "user_accel_y", "user_accel_z",
            "rotation_rate_x", "rotation_rate_y", "rotation_rate_z",
            "quaternion_x", "quaternion_y", "quaternion_z", "quaternion_w"
        ].joined(separator: ",") + "\n"
        let csvBody = samples.map {
            "\($0.timestamp),\($0.raw_accel_x),\($0.raw_accel_y),\($0.raw_accel_z),\($0.roll),\($0.pitch),\($0.yaw),\($0.gravity_x),\($0.gravity_y),\($0.gravity_z),\($0.user_accel_x),\($0.user_accel_y),\($0.user_accel_z),\($0.rotation_rate_x),\($0.rotation_rate_y),\($0.rotation_rate_z),\($0.quaternion_x),\($0.quaternion_y),\($0.quaternion_z),\($0.quaternion_w)"
        }.joined(separator: "\n")
        let csvString = headers + csvBody
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        do {
            try csvString.write(to: tempURL, atomically: true, encoding: .utf8)
            print("[DEBUG] File saved at: \(tempURL.path)")
            if WCSession.default.isReachable || WCSession.default.activationState == .activated {
                WCSession.default.transferFile(tempURL, metadata: ["collectionFinished": true])
                print("[DEBUG] File sent to iPhone: \(fileName)")
                // Show success haptic and notification
                WKInterfaceDevice.current().play(.success)
                DispatchQueue.main.async {
                    self.lastErrorMsg = "File written and sent successfully!"
                }
            } else {
                WKInterfaceDevice.current().play(.failure)
                DispatchQueue.main.async { self.lastErrorMsg = "Not reachable for file transfer." }
            }
        } catch {
            WKInterfaceDevice.current().play(.failure)
            DispatchQueue.main.async { self.lastErrorMsg = "Failed to write file." }
        }
    }

    // WCSessionDelegate -- connects with phone, updates state
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}

    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        if let testType = message["testType"] as? String {
            DispatchQueue.main.async { self.currentTest = testType }
        }
        if let sessionID = message["sessionID"] as? String {
            DispatchQueue.main.async { self.sessionID = sessionID }
        }
        if let cmd = message["cmd"] as? String {
            switch cmd {
            case "start":
                self.startCollecting()
            case "stop":
                self.stopCollecting()
            case "wait":
                DispatchQueue.main.async {
                    self.isCollecting = false
                    self.lastErrorMsg = ""
                }
            default: break
            }
        }
    }
}
