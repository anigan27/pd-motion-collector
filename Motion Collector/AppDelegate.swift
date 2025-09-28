//
//  AppDelegate.swift
//  Motion Collector
//
//  Created by Anika Ganu on 9/13/25.
//


import UIKit
import WatchConnectivity

// MARK: - Enhanced Connection Management for iPhone
class EnhancedConnectionManager: NSObject, ObservableObject {
    @Published var isConnected = false
    @Published var connectionQuality: ConnectionQuality = .unknown
    @Published var lastHeartbeatReceived: Date?
    
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
        
        var color: UIColor {
            switch self {
            case .excellent: return .systemGreen
            case .good: return .systemBlue
            case .poor: return .systemOrange
            case .unknown: return .systemGray
            }
        }
    }
    
    private var heartbeatTimer: Timer?
    // Removed complex pendingMessages logic
    
    struct PendingMessage {
        let message: [String: Any]
        let timestamp: Date
        var retryCount: Int
    }
    
    override init() {
        super.init()
        setupWCSession()
        startHeartbeatMonitoring()
    }
    
    private func setupWCSession() {
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }
    
    func sendReliableMessage(_ message: [String: Any]) {
        var messageToSend = message
        messageToSend["timestamp"] = Date().timeIntervalSince1970
        messageToSend["sender"] = "iPhone"
        
        print("[iPhone] Sending SIMPLE command: \(message["cmd"] ?? "unknown")")
        
        // SIMPLE: Just send the message directly
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(messageToSend, replyHandler: nil) { error in
                print("[iPhone] Direct message failed, using transferUserInfo: \(error.localizedDescription)")
                WCSession.default.transferUserInfo(messageToSend)
            }
        } else {
            WCSession.default.transferUserInfo(messageToSend)
        }
    }
    
    private func startHeartbeatMonitoring() {
        // Monitor for heartbeats from watch
        Timer.scheduledTimer(withTimeInterval: 8.0, repeats: true) { _ in
            self.checkHeartbeatTimeout()
        }
    }
    
    private func checkHeartbeatTimeout() {
        if let lastHeartbeat = lastHeartbeatReceived {
            let timeSinceLastHeartbeat = Date().timeIntervalSince(lastHeartbeat)
            
            if timeSinceLastHeartbeat > 10.0 { // No heartbeat for 10 seconds
                DispatchQueue.main.async {
                    self.isConnected = false
                    self.connectionQuality = .poor
                }
            }
        } else if WCSession.default.isReachable {
            // No heartbeat received yet, but session says reachable
            DispatchQueue.main.async {
                self.connectionQuality = .unknown
            }
        }
    }
    
    func handleHeartbeatReceived(from message: [String: Any]) {
        lastHeartbeatReceived = Date()
        
        // Send heartbeat response
        let response: [String: Any] = [
            "type": "heartbeatResponse",
            "sender": "iPhone",
            "timestamp": Date().timeIntervalSince1970
        ]
        
        WCSession.default.transferUserInfo(response)
        
        // Update connection status
        DispatchQueue.main.async {
            self.isConnected = true
            
            // Determine quality based on heartbeat frequency
            if let timestamp = message["timestamp"] as? Double {
                let heartbeatAge = Date().timeIntervalSince1970 - timestamp
                if heartbeatAge < 2.0 {
                    self.connectionQuality = .excellent
                } else if heartbeatAge < 5.0 {
                    self.connectionQuality = .good
                } else {
                    self.connectionQuality = .poor
                }
            }
        }
    }
    
    private func handleMessageFailure() {
        DispatchQueue.main.async {
            self.connectionQuality = .poor
        }
    }
    
    private func handleSessionRecoveryRequest(_ message: [String: Any]) {
        // Determine if watch should resume its session
        let response: [String: Any] = [
            "type": "sessionRecoveryResponse",
            "shouldResume": false, // For now, don't resume - start fresh
            "timestamp": Date().timeIntervalSince1970
        ]
        
        sendReliableMessage(response)
    }
}

// MARK: - WCSessionDelegate for iPhone Enhanced Connection Manager
extension EnhancedConnectionManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isConnected = activationState == .activated && session.isReachable
        }
        print("[iPhone DEBUG] Enhanced WCSession activation: \(activationState.rawValue)")
    }
    
    func sessionDidBecomeInactive(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isConnected = false
            self.connectionQuality = .unknown
        }
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isConnected = false
            self.connectionQuality = .unknown
        }
        // Reactivate session
        session.activate()
    }
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isConnected = session.isReachable && session.activationState == .activated
        }
    }
    
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any]) {
        print("[iPhone] Received message from watch: \(userInfo)")
        
        // Handle heartbeats - just update connection status
        if let type = userInfo["type"] as? String, type == "heartbeat" {
            handleHeartbeatReceived(from: userInfo)
        }
        
        // Handle urgent keep-alive messages
        if let type = userInfo["type"] as? String, type == "urgentKeepAlive" {
            print("[iPhone] Received urgent keep-alive from watch")
            lastHeartbeatReceived = Date()
        }
    }
    
    // Receive file from watch
    func session(_ session: WCSession, didReceive file: WCSessionFile) {
        print("[DEBUG] Received file from Watch: \(file.fileURL.lastPathComponent)")
        // Move file to documents directory
        let fileManager = FileManager.default
        let docsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let destURL = docsURL.appendingPathComponent(file.fileURL.lastPathComponent)
        do {
            if fileManager.fileExists(atPath: destURL.path) {
                try fileManager.removeItem(at: destURL)
            }
            try fileManager.moveItem(at: file.fileURL, to: destURL)
            print("[DEBUG] Moved file to documents: \(destURL.path)")
        } catch {
            print("[ERROR] Could not move file: \(error)")
        }
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .didReceiveWatchFile, object: nil)
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    static var shared: AppDelegate!
    var enhancedConnectionManager = EnhancedConnectionManager()
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        AppDelegate.shared = self
        // Enhanced connection manager handles WCSession setup automatically
        return true
    }
}

extension Notification.Name {
    static let didReceiveWatchFile = Notification.Name("didReceiveWatchFile")
    static let watchConnectionChanged = Notification.Name("watchConnectionChanged")
}
