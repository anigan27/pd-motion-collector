import WatchKit
import WatchConnectivity
import CoreMotion
import Foundation
import HealthKit

struct MotionSample: Codable {
    let timestamp: String
    let raw_accel_x: Double; let raw_accel_y: Double; let raw_accel_z: Double
    let roll: Double; let pitch: Double; let yaw: Double
    let gravity_x: Double; let gravity_y: Double; let gravity_z: Double
    let user_accel_x: Double; let user_accel_y: Double; let user_accel_z: Double
    let rotation_rate_x: Double; let rotation_rate_y: Double; let rotation_rate_z: Double
    let quaternion_x: Double; let quaternion_y: Double; let quaternion_z: Double; let quaternion_w: Double
}

class EnhancedConnectionManager: NSObject, ObservableObject {
    @Published var isConnected = false
    @Published var connectionQuality: ConnectionQuality = .unknown
    
    var pendingMessages: [String: PendingMessage] = [:]
    private var heartbeatTimer: Timer?
    private var receivedHeartbeatResponse = false
    private var connectionRecoveryAttempts = 0
    private var lastHeartbeatTime: Date = Date()
    
    enum ConnectionQuality {
        case excellent, good, poor, unknown
        
        var description: String {
            switch self {
            case .excellent: return "Excellent"
            case .good: return "Good" 
            case .poor: return "Poor"
            case .unknown: return "Unknown"
            }
        }
    }
    
    struct PendingMessage {
        let message: [String: Any]
        let timestamp: Date
        var retryCount: Int
    }
    
    override init() {
        super.init()
        startBidirectionalHeartbeat()
    }
    
    // MARK: - Reliable Message Sending
    func sendReliableMessage(_ message: [String: Any]) {
        let messageId = UUID().uuidString
        var messageWithId = message
        messageWithId["messageId"] = messageId
        messageWithId["timestamp"] = Date().timeIntervalSince1970
        messageWithId["sender"] = "watch"
        
        // Store for confirmation tracking
        pendingMessages[messageId] = PendingMessage(
            message: messageWithId,
            timestamp: Date(),
            retryCount: 0
        )
        
        // Send via transferUserInfo only (most reliable)
        WCSession.default.transferUserInfo(messageWithId)
        print("[EnhancedConnection] Sent reliable message: \(message["type"] ?? "unknown")")
        
        // Set confirmation timeout
        Timer.scheduledTimer(withTimeInterval: 8.0, repeats: false) { _ in
            self.checkMessageConfirmation(messageId)
        }
    }
    
    private func checkMessageConfirmation(_ messageId: String) {
        guard let pendingMsg = pendingMessages[messageId] else { return }
        
        if pendingMsg.retryCount < 3 {
            // Retry the message
            var retryMsg = pendingMsg
            retryMsg.retryCount += 1
            pendingMessages[messageId] = retryMsg
            
            WCSession.default.transferUserInfo(retryMsg.message)
            print("[EnhancedConnection] Retrying message \(messageId), attempt \(retryMsg.retryCount)")
            
            // Set another timeout
            Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false) { _ in
                self.checkMessageConfirmation(messageId)
            }
        } else {
            // Message failed after retries
            pendingMessages.removeValue(forKey: messageId)
            handleMessageFailure()
        }
    }
    
    // MARK: - Bidirectional Heartbeat
    func startBidirectionalHeartbeat() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: true) { _ in
            self.sendHeartbeat()
        }
    }
    
    private func sendHeartbeat() {
        receivedHeartbeatResponse = false
        lastHeartbeatTime = Date()
        
        let heartbeat: [String: Any] = [
            "type": "heartbeat",
            "sender": "watch",
            "timestamp": Date().timeIntervalSince1970,
            "connectionQuality": connectionQuality.description
        ]
        
        // Use direct transferUserInfo for heartbeat
        WCSession.default.transferUserInfo(heartbeat)
        
        // Check for response within 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            if !self.receivedHeartbeatResponse {
                self.handleMissedHeartbeat()
            }
        }
    }
    
    func handleHeartbeatResponse() {
        receivedHeartbeatResponse = true
        connectionRecoveryAttempts = 0
        
        // Update connection quality based on response time
        let responseTime = Date().timeIntervalSince(lastHeartbeatTime)
        if responseTime < 1.0 {
            connectionQuality = .excellent
        } else if responseTime < 2.0 {
            connectionQuality = .good
        } else {
            connectionQuality = .poor
        }
        
        DispatchQueue.main.async {
            self.isConnected = true
        }
    }
    
    private func handleMissedHeartbeat() {
        connectionRecoveryAttempts += 1
        connectionQuality = .poor
        
        DispatchQueue.main.async {
            self.isConnected = false
        }
        
        if connectionRecoveryAttempts >= 3 {
            handleConnectionDegradation()
        }
    }
    
    private func handleConnectionDegradation() {
        print("[EnhancedConnection] Connection severely degraded, attempting recovery")
        
        // Save emergency session state but don't trigger exports
        saveEmergencySession()
        
        // Try to force reconnection
        forceReconnection()
        
        // DO NOT trigger exportAndSend() here to prevent duplicate exports during weak connection
    }
    
    private func handleMessageFailure() {
        connectionQuality = .poor
        connectionRecoveryAttempts += 1
    }
    
    private func saveEmergencySession() {
        // Implement emergency session save
        let emergencyState = [
            "timestamp": Date().timeIntervalSince1970,
            "connectionLost": true,
            "recoveryAttempts": connectionRecoveryAttempts
        ] as [String : Any]
        
        UserDefaults.standard.set(emergencyState, forKey: "emergencyConnectionState")
    }
    
    private func forceReconnection() {
        // Attempt to reactivate WCSession
        if WCSession.default.activationState != .activated {
            WCSession.default.activate()
        }
        
        // Reset recovery attempts after forcing reconnection
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.connectionRecoveryAttempts = 0
        }
    }
    
    func cleanup() {
        heartbeatTimer?.invalidate()
        pendingMessages.removeAll()
    }
}

// MARK: - Enhanced Power Management
class PowerManager: NSObject {
    private var backgroundTimer: Timer?
    private var lastActivityTime: CFAbsoluteTime = CFAbsoluteTimeGetCurrent()
    private var powerSaveDetectionTimer: Timer?
    
    override init() {
        super.init()
        enableMaximumWakeTime()
        startPowerSaveDetection()
    }
    
    func enableMaximumWakeTime() {
        // Continuous background processing with more frequent intervals
        backgroundTimer?.invalidate()
        backgroundTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            self.performBackgroundWork()
        }
        
        print("[PowerManager] Maximum wake time enabled")
    }
    
    private func performBackgroundWork() {
        lastActivityTime = CFAbsoluteTimeGetCurrent()
        // Minimal work to keep the app active
        _ = Date().timeIntervalSince1970
    }
    
    func startPowerSaveDetection() {
        powerSaveDetectionTimer?.invalidate()
        powerSaveDetectionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            self.detectPowerSaveMode()
        }
    }
    
    private func detectPowerSaveMode() {
        let currentTime = CFAbsoluteTimeGetCurrent()
        if currentTime - lastActivityTime > 6.0 {
            // Watch likely going to sleep - send urgent status
            sendUrgentKeepAlive()
        }
    }
    
    private func sendUrgentKeepAlive() {
        let urgentMessage: [String: Any] = [
            "type": "urgentKeepAlive",
            "sender": "watch",
            "timestamp": Date().timeIntervalSince1970,
            "reason": "powerSaveDetected"
        ]
        
        WCSession.default.transferUserInfo(urgentMessage)
    }
    
    func cleanup() {
        backgroundTimer?.invalidate()
        powerSaveDetectionTimer?.invalidate()
    }
}

// MARK: - Session Persistence
struct TestSession: Codable {
    let sessionId: String
    let currentTestId: String
    let testStartTime: Date
    let isCollecting: Bool
    let samplesCollected: Int
    let testType: String
    
    func save() {
        if let encoded = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(encoded, forKey: "currentTestSession")
        }
    }
    
    static func restore() -> TestSession? {
        guard let data = UserDefaults.standard.data(forKey: "currentTestSession"),
              let session = try? JSONDecoder().decode(TestSession.self, from: data) else { return nil }
        return session
    }
    
    static func clear() {
        UserDefaults.standard.removeObject(forKey: "currentTestSession")
    }
}

// MARK: - Original MotionManager with Enhanced Connection Integration
@objc class MotionManager: NSObject, ObservableObject, WCSessionDelegate {
    private let motion = CMMotionManager()
    private let queue = OperationQueue()
    @Published var samples = [MotionSample]()
    @Published var isCollecting = false
    @Published var currentTest = "Waiting to start test..."
    @Published var sessionID = "default_session"
    @Published var lastErrorMsg = ""
    @Published var isSessionActive = false
    @Published var isConnected = false
    
    // Enhanced connection management
    @Published var connectionManager = EnhancedConnectionManager()
    private var powerManager = PowerManager()
    private var activeTestSession: TestSession?
    
    // HealthKit properties
    private let healthStore = HKHealthStore()
    private var workoutSession: HKWorkoutSession?
    private var workoutBuilder: HKLiveWorkoutBuilder?
    
    // Legacy properties for compatibility (simplified)
    private var keepAliveTimer: Timer?
    private var connectionMonitorTimer: Timer?
    private var backgroundTimer: Timer?

    override init() {
        super.init()
        activateSession()
        // Start enhanced background activity and connection monitoring
        setupConnectionManagerIntegration()
        startBackgroundActivity()
        startConnectionMonitoring()
    }
    
    private func setupConnectionManagerIntegration() {
        // Monitor connection manager state changes
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            DispatchQueue.main.async {
                self.isConnected = self.connectionManager.isConnected
            }
        }
    }
    
    deinit {
        connectionManager.cleanup()
        powerManager.cleanup()
        stopBackgroundActivity()
        stopConnectionMonitoring()
    }
    
    private func startBackgroundActivity() {
        // Use a timer to keep the app active and responsive
        backgroundTimer = Timer.scheduledTimer(withTimeInterval: 8.0, repeats: true) { [weak self] _ in
            // This helps keep the app in a responsive state
            print("[DEBUG] Background activity ping")
            self?.updateConnectionState()
        }
    }
    
    private func stopBackgroundActivity() {
        backgroundTimer?.invalidate()
        backgroundTimer = nil
    }

    func activateSession() {
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }
    
    private func startConnectionMonitoring() {
        connectionMonitorTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.updateConnectionState()
        }
    }
    
    private func stopConnectionMonitoring() {
        connectionMonitorTimer?.invalidate()
        connectionMonitorTimer = nil
    }
    
    private func updateConnectionState() {
        let newConnectionState = WCSession.default.isReachable && WCSession.default.activationState == .activated
        if newConnectionState != isConnected {
            DispatchQueue.main.async {
                self.isConnected = newConnectionState
                print("[DEBUG] Connection state changed: \(newConnectionState)")
                if newConnectionState {
                    self.onConnectionRestored()
                }
            }
        }
    }
    
    private func onConnectionRestored() {
        // Send current state to phone when connection is restored
        let stateMessage = [
            "connectionRestored": true,
            "sessionID": sessionID,
            "isCollecting": isCollecting,
            "currentTest": currentTest
        ] as [String: Any]
        
        sendMessageWithRetry(stateMessage)
        print("[DEBUG] Connection restored - sent current state to phone")
    }

    func startCollecting() {
        // Already keeping watch awake globally, no need to change idle timer here
        DispatchQueue.main.async {
            self.isCollecting = true
            self.samples.removeAll()
            print("[DEBUG] Started collecting samples for session: \(self.sessionID), test: \(self.currentTest)")
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
        // Keep watch awake globally - don't disable idle timer here
        DispatchQueue.main.async { self.isCollecting = false }
        motion.stopDeviceMotionUpdates()
        motion.stopAccelerometerUpdates()
        
        // SIMPLE: Only export if we have samples and haven't exported for THIS specific test
        let exportKey = "exported_\(sessionID)_\(currentTest)"
        let hasExportedThisTest = UserDefaults.standard.bool(forKey: exportKey)
        
        guard !samples.isEmpty && !hasExportedThisTest else {
            print("[DEBUG] Skip export - samples: \(samples.count), already exported: \(hasExportedThisTest)")
            return
        }
        
        // Mark as exported IMMEDIATELY to prevent any duplicates
        UserDefaults.standard.set(true, forKey: exportKey)
        print("[DEBUG] Marked as exported: \(exportKey)")
        
        exportAndSend()
    }

    func exportAndSend() {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MM-dd-yy_HHmmss"
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
        
        print("[DEBUG] SIMPLE EXPORT: \(samples.count) samples to \(fileName)")
        
        do {
            try csvString.write(to: tempURL, atomically: true, encoding: .utf8)
            print("[DEBUG] File written successfully: \(tempURL.path)")
            
            // SIMPLE: Just send the file, no complex retry logic
            if WCSession.default.activationState == .activated {
                WCSession.default.transferFile(tempURL, metadata: [
                    "fileName": fileName,
                    "sessionID": sessionID,
                    "testType": currentTest
                ])
                print("[DEBUG] File transfer initiated: \(fileName)")
            }
            
        } catch {
            print("[ERROR] Failed to write file: \(error)")
            WKInterfaceDevice.current().play(.failure)
            DispatchQueue.main.async { 
                self.lastErrorMsg = "Failed to write file: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Session Management
    
    func startTestSession() {
        isSessionActive = true
        startKeepAlive()
        print("[DEBUG] Test session started - workout processing mode active")
        startWorkoutSession()
    }
    
    func endTestSession() {
        isSessionActive = false
        stopKeepAlive()
        endWorkoutSession()
        print("[DEBUG] Test session ended - workout processing mode ended")
    }
    
    func closeWatchApp() {
        // Clean up all resources and close the app
        print("[DEBUG] Closing watch app - cleaning up resources")
        
        // Stop any active data collection
        stopCollecting()
        
        // End any active test session
        endTestSession()
        
        // Clear any saved session data
        TestSession.clear()
        
        // Clear all export tracking flags
        let defaults = UserDefaults.standard
        let keys = defaults.dictionaryRepresentation().keys.filter { $0.hasPrefix("exported_") }
        for key in keys {
            defaults.removeObject(forKey: key)
        }
        defaults.synchronize()
        
        // Clean up connection and power managers
        connectionManager.cleanup()
        powerManager.cleanup()
        
        // Stop all timers and monitoring
        stopBackgroundActivity()
        stopConnectionMonitoring()
        
        // Send final status to iPhone
        let closingMessage: [String: Any] = [
            "type": "watchAppClosing",
            "sessionID": sessionID,
            "timestamp": Date().timeIntervalSince1970
        ]
        WCSession.default.transferUserInfo(closingMessage)
        
        print("[DEBUG] Watch app close requested - performing cleanup")
        
        // Update UI to show app is closed and provide user guidance
        DispatchQueue.main.async {
            self.currentTest = "App Closed"
            self.lastErrorMsg = "Press Digital Crown twice to exit"
            self.isSessionActive = false
            self.isCollecting = false
            WKInterfaceDevice.current().play(.notification)
            print("[DEBUG] Watch app cleanup complete. App is now in closed state.")
            print("[DEBUG] User should manually exit by pressing Digital Crown twice.")
        }
    }
    
    private func startKeepAlive() {
        stopKeepAlive() // Stop any existing timer
        // Reduced interval for better connection stability
        keepAliveTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: true) { [weak self] _ in
            self?.sendKeepAlive()
        }
    }
    
    private func stopKeepAlive() {
        keepAliveTimer?.invalidate()
        keepAliveTimer = nil
    }
    
    private func sendKeepAlive() {
        guard isSessionActive else { return }
        
        let message = [
            "keepAlive": true,
            "sessionID": sessionID,
            "isCollecting": isCollecting,
            "connectionQuality": WCSession.default.isReachable ? "good" : "poor"
        ] as [String: Any]
        
        sendMessageWithRetry(message)
    }
    
    private func sendMessageWithRetry(_ message: [String: Any], maxRetries: Int = 3, attempt: Int = 1) {
        guard WCSession.default.activationState == .activated else {
            if attempt <= maxRetries {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    self.sendMessageWithRetry(message, maxRetries: maxRetries, attempt: attempt + 1)
                }
            }
            return
        }
        
        // Try immediate message first
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(message, replyHandler: nil) { error in
                print("[DEBUG] Message send failed: \(error.localizedDescription)")
                // Fall back to transferUserInfo for reliability
                WCSession.default.transferUserInfo(message)
            }
        } else {
            // Use transferUserInfo when not immediately reachable
            WCSession.default.transferUserInfo(message)
        }
    }

    // MARK: - WCSessionDelegate
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isConnected = activationState == .activated && session.isReachable
            self.connectionManager.isConnected = self.isConnected
        }
        
        if activationState == .activated && session.isReachable {
            handleConnectionRestored()
        }
        
        print("[DEBUG] Enhanced WCSession activation: \(activationState.rawValue), error: \(String(describing: error))")
    }
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        let wasConnected = isConnected
        
        DispatchQueue.main.async {
            self.isConnected = session.isReachable && session.activationState == .activated
            self.connectionManager.isConnected = self.isConnected
        }
        
        print("[DEBUG] Enhanced session reachability changed: \(session.isReachable)")
        
        if session.isReachable && !wasConnected {
            // Connection restored
            handleConnectionRestored()
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        handleReceivedMessage(message)
    }
    
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any]) {
        handleReceivedMessage(userInfo)
        
        // Handle heartbeat responses
        if let type = userInfo["type"] as? String, type == "heartbeatResponse" {
            connectionManager.handleHeartbeatResponse()
        }
        
        print("[DEBUG] Received enhanced user info message")
    }
    
    private func handleReceivedMessage(_ message: [String: Any]) {
        print("[DEBUG] Watch received message: \(message)")
        
        // Handle test type changes
        if let testType = message["testType"] as? String {
            DispatchQueue.main.async { 
                self.currentTest = testType 
                print("[DEBUG] Set test type: \(testType)")
            }
        }
        
        // Handle session ID changes - this resets export tracking for new sessions
        if let sessionID = message["sessionID"] as? String, sessionID != self.sessionID {
            DispatchQueue.main.async { 
                self.sessionID = sessionID 
                print("[DEBUG] NEW SESSION: \(sessionID) - clearing export flags")
                
                // Clear ALL export flags for the new session
                let defaults = UserDefaults.standard
                let keys = defaults.dictionaryRepresentation().keys.filter { $0.hasPrefix("exported_") }
                for key in keys {
                    defaults.removeObject(forKey: key)
                }
                defaults.synchronize()
            }
        }
        
        // Handle commands
        if let cmd = message["cmd"] as? String {
            print("[DEBUG] Processing command: \(cmd)")
            
            switch cmd {
            case "start":
                DispatchQueue.main.async {
                    self.startCollecting()
                }
            case "stop":
                DispatchQueue.main.async {
                    self.stopCollecting()
                }
            case "wait":
                DispatchQueue.main.async {
                    if let testType = message["testType"] as? String {
                        self.currentTest = testType
                    }
                }
            case "startSession":
                self.startTestSession()
            case "endSession":
                self.endTestSession()
            case "closeApp":
                self.closeWatchApp()
            default:
                print("[DEBUG] Unknown command: \(cmd)")
            }
        }
    }
    
    private func handleSessionRecoveryResponse(_ message: [String: Any]) {
        // Handle response from iPhone about session state
        if let shouldResume = message["shouldResume"] as? Bool {
            if shouldResume {
                // Resume the test
                startCollecting()
            } else {
                // Clear the saved session
                TestSession.clear()
                activeTestSession = nil
            }
        }
    }
    
    func session(_ session: WCSession, didFinish fileTransfer: WCSessionFileTransfer, error: Error?) {
        if let error = error {
            print("[DEBUG] File transfer FAILED: \(error.localizedDescription)")
            DispatchQueue.main.async {
                WKInterfaceDevice.current().play(.failure)
                self.lastErrorMsg = "File transfer failed: \(error.localizedDescription)"
            }
        } else {
            print("[DEBUG] File transfer SUCCESS")
            DispatchQueue.main.async {
                WKInterfaceDevice.current().play(.success)
                self.lastErrorMsg = "File sent successfully!"
                
                // Hide success message after 2 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    if self.lastErrorMsg == "File sent successfully!" {
                        self.lastErrorMsg = ""
                    }
                }
            }
        }
    }
    
    // MARK: - Enhanced Session Management
    
    private func saveCurrentSession() {
        guard isCollecting else { return }
        
        activeTestSession = TestSession(
            sessionId: sessionID,
            currentTestId: currentTest,
            testStartTime: Date(),
            isCollecting: isCollecting,
            samplesCollected: samples.count,
            testType: currentTest
        )
        
        activeTestSession?.save()
    }
    
    private func handleConnectionRestored() {
        connectionManager.handleHeartbeatResponse()
        
        // Check if there was an active test session
        if let session = TestSession.restore() {
            // Verify with iPhone what the actual state should be
            let recoveryQuery: [String: Any] = [
                "type": "sessionRecovery",
                "sessionId": session.sessionId,
                "watchState": "collecting",
                "testId": session.currentTestId,
                "samplesCollected": session.samplesCollected
            ]
            connectionManager.sendReliableMessage(recoveryQuery)
            
            // Restore session state
            DispatchQueue.main.async {
                self.sessionID = session.sessionId
                self.currentTest = session.testType
                if session.isCollecting {
                    // Resume collecting if it was active
                    self.startCollecting()
                }
            }
        }
    }
    
    // MARK: - Enhanced Communication Methods
    
    private func sendReliableWatchCommand(_ message: [String: Any]) {
        // Use the enhanced connection manager for all communication
        connectionManager.sendReliableMessage(message)
        
        // Also save session state when sending important commands
        if let type = message["type"] as? String {
            if ["start", "stop", "sessionUpdate"].contains(type) {
                saveCurrentSession()
            }
        }
    }
    
    // MARK: - Workout Session Management
    
    private func startWorkoutSession() {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("[ERROR] Health data not available on this device.")
            return
        }
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .other
        configuration.locationType = .unknown
        do {
            workoutSession = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            workoutBuilder = workoutSession?.associatedWorkoutBuilder()
            workoutSession?.delegate = self
            workoutBuilder?.delegate = self
            workoutSession?.startActivity(with: Date())
            print("[DEBUG] Workout session started")
        } catch {
            print("[ERROR] Failed to start workout session: \(error)")
        }
    }
    private func endWorkoutSession() {
        workoutSession?.end()
        print("[DEBUG] Workout session ended")
    }
}

extension MotionManager: HKWorkoutSessionDelegate, HKLiveWorkoutBuilderDelegate {
    func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        print("[DEBUG] Workout session state changed: \(toState.rawValue)")
        if toState == .ended || toState == .stopped{
            DispatchQueue.main.async {
                self.lastErrorMsg = "Workout session ended or interrupted. Please restart the test."
                WKInterfaceDevice.current().play(.notification)
                self.isSessionActive = false
                self.isCollecting = false
                self.currentTest = "Session Ended"
                
            }
            // Optionally, you could call self.startWorkoutSession() to auto-restart, but user action is safer.
        }
    }
    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        print("[ERROR] Workout session failed: \(error)")
        DispatchQueue.main.async {
            self.lastErrorMsg = "Workout session error: \(error.localizedDescription). Please restart the test."
            WKInterfaceDevice.current().play(.failure)
            self.isSessionActive = false
            self.isCollecting = false
            self.currentTest = "Session Error"
        }
    }
    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        // No-op for now
    }
    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
        // No-op for now
    }
}
