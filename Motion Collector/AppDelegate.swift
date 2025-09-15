//
//  AppDelegate.swift
//  Motion Collector
//
//  Created by Seema Sharma on 9/13/25.
//


import UIKit
import WatchConnectivity

class AppDelegate: NSObject, UIApplicationDelegate, WCSessionDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
        return true
    }

    // Required for WCSessionDelegate
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        print("[DEBUG] WCSession activationDidComplete: state=\(activationState.rawValue), error=\(String(describing: error))")
    }

    func sessionDidBecomeInactive(_ session: WCSession) {
        print("[DEBUG] WCSession didBecomeInactive")
    }

    func sessionDidDeactivate(_ session: WCSession) {
        print("[DEBUG] WCSession didDeactivate")
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

extension Notification.Name {
    static let didReceiveWatchFile = Notification.Name("didReceiveWatchFile")
}
