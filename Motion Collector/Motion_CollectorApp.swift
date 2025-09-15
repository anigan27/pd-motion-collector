//
//  Motion_CollectorApp.swift
//  Motion Collector
//
//  Created by Anika Ganu on 6/4/25.
//

import SwiftUI

@main
struct Motion_CollectorApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var body: some Scene {
        WindowGroup {
            NavigationView {
                ContentView()
            }
            .navigationViewStyle(StackNavigationViewStyle())
        }
    }
}
