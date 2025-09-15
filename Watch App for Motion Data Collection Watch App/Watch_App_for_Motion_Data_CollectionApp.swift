//
//  Watch_App_for_Motion_Data_CollectionApp.swift
//  Watch App for Motion Data Collection Watch App
//
//  Created by Anika Ganu on 6/4/25.
//

import SwiftUI
import WatchConnectivity

@main
struct Watch_App_for_Motion_Data_Collection_Watch_AppApp: App {
    // Add WCSession activation and debug logs
    init() {
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = WatchSessionDelegate.shared
            session.activate()
            print("[WatchApp] WCSession activated and delegate set.")
        } else {
            print("[WatchApp] WCSession is not supported on this device.")
        }
    }
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

class WatchSessionDelegate: NSObject, WCSessionDelegate {
    static let shared = WatchSessionDelegate()
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        print("[WatchApp] session activationDidComplete: state=\(activationState.rawValue), error=\(String(describing: error))")
    }
    func sessionReachabilityDidChange(_ session: WCSession) {
        print("[WatchApp] sessionReachabilityDidChange: reachable=\(session.isReachable)")
    }
    // Add other delegate methods as needed
}
