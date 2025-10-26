////
////  ContentView.swift
////  Watch App for Motion Data Collection Watch App
////
////  Created by Anika Ganu on 6/4/25.
////
//
//import SwiftUI
//import CoreMotion
//import WatchConnectivity
//
//struct ContentView: View {
//    @StateObject private var motionManager = MotionManager()
//    @State private var isCollecting = false
//    //@State private var useTimer = false
//    @State private var isCountingDown = false
//    @State private var timer: Timer?
//    @State private var countdown = 5
//    @State private var timerCountdown = 10
//    @State private var isTimerRunning = false
//    @State private var showCollectedToast = false
//    @State private var samples: [MotionSample] = []
//    
//    var body: some View {
//        ScrollView {
//            ZStack {
//                VStack(spacing: 24) {
//                    Spacer(minLength: 0)
//                    if !motionManager.currentTestType.isEmpty {
//                        Text("Test: \(motionManager.currentTestType.replacingOccurrences(of: "_", with: " ").capitalized)")
//                            .font(.headline)
//                            .multilineTextAlignment(.center)
//                            .padding(.horizontal)
//                    }
//
//                    Toggle("10s Timer", isOn: $motionManager.useTimer)
//
//                        .padding()
//                    Button(action: {
////                        if useTimer {
////                            // Begin 5-second countdown
////                            isCountingDown = true
////                            countdown = 5
////                            timer?.invalidate()
////                            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { t in
////                                if countdown > 1 {
////                                    countdown -= 1
////                                    WKInterfaceDevice.current().play(.click)
////                                } else {
////                                    t.invalidate()
////                                    isCountingDown = false
////                                    // Start collection and haptic
////                                    isCollecting = true
////                                    motionManager.startCollecting()
////                                    WKInterfaceDevice.current().play(.start)
////                                    // Start 10-second timer
////                                    timerCountdown = 10
////                                    isTimerRunning = true
////                                    timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { t in
////                                        if timerCountdown > 1 {
////                                            timerCountdown -= 1
////                                        } else {
////                                            t.invalidate()
////                                            isTimerRunning = false
////                                            isCollecting = false
////                                            motionManager.stopCollecting()
////                                            WKInterfaceDevice.current().play(.stop)
////                                            DispatchQueue.main.async {
////                                                showCollectedToast = true
////                                            }
////                                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
////                                                showCollectedToast = false
////                                            }
////                                        }
////                                    }
////                                }
////                            }
////                        } else {
////                            // Normal manual start/stop
////                            isCollecting.toggle()
////                            if isCollecting {
////                                motionManager.startCollecting()
////                            } else {
////                                motionManager.stopCollecting()
////                                showCollectedToast = true
////                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
////                                    showCollectedToast = false
////                                }
////                                
////                            }
////                        }
//                        if motionManager.useTimer {
//                            // Begin 5-second countdown
//                            isCountingDown = true
//                            countdown = 5
//                            timer?.invalidate()
//                            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { t in
//                                if countdown > 1 {
//                                    countdown -= 1
//                                    WKInterfaceDevice.current().play(.click)
//                                } else {
//                                    t.invalidate()
//                                    isCountingDown = false
//                                    // Start collection and haptic
//                                    isCollecting = true
//                                    motionManager.startCollecting()
//                                    WKInterfaceDevice.current().play(.start)
//                                    // Start 10-second timer
//                                    timerCountdown = 10
//                                    isTimerRunning = true
//                                    timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { t in
//                                        if timerCountdown > 1 {
//                                            timerCountdown -= 1
//                                        } else {
//                                            t.invalidate()
//                                            isTimerRunning = false
//                                            isCollecting = false
//                                            motionManager.stopCollecting()
//                                            WKInterfaceDevice.current().play(.stop)
//                                            DispatchQueue.main.async {
//                                                showCollectedToast = true
//                                            }
//                                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
//                                                showCollectedToast = false
//                                            }
//                                        }
//                                    }
//                                }
//                            }
//                        } else {
//                            // Normal manual start/stop
//                            isCollecting.toggle()
//                            if isCollecting {
//                                motionManager.startCollecting()
//                            } else {
//                                motionManager.stopCollecting()
//                                showCollectedToast = true
//                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
//                                    showCollectedToast = false
//                                }
//                            }
//                        }
//
//                    }) {
//                        Text(
//                            isCountingDown
//                            ? "\(countdown)"
//                            : (isTimerRunning
//                               ? "\(timerCountdown)"
//                               : (isCollecting ? "Stop" : "Start"))
//                        )
//                        .font(.system(size: 40, weight: .bold))
//                        .padding()
//                        .foregroundColor(.white)
//                        .background(isCollecting ? Color.red : Color.green)
//                        .cornerRadius(16)
//                    }
//                    .disabled(isCountingDown)
//                    
//                    
//                    
//                    Button("Send to Phone") {
//                        motionManager.exportAndSendCSV()
//                        
//                        
//                    }
//                    .font(.system(size: 22, weight: .bold))
//                    //.frame(maxWidth: .infinity, minHeight: 50)
//                    .background(Color.blue)
//                    .foregroundColor(.white)
//                    //.cornerRadius(16)
//                    
//                    
//                    //.padding(.vertical, 8)
//                    
//                    //Button("Delete Data") {
//                    //motionManager.deleteData()
//                    
//                    //}
//                    //.foregroundColor(.red)
//                }
//                if showCollectedToast {
//                    Text("Data successfully collected!")
//                        .font(.headline)
//                        .padding(.vertical, 10)
//                        .padding(.horizontal, 20)
//                        .background(Color.gray.opacity(0.9))
//                        .foregroundColor(.white)
//                        .cornerRadius(14)
//                        .transition(.opacity)
//                        .zIndex(1)
//                    
//                
//                }
//                
//                if motionManager.showSentPopup {
//                    Text("Sent File!")
//                        .font(.headline)
//                        .padding(.vertical, 10)
//                        .padding(.horizontal, 20)
//                        .background(Color.gray.opacity(0.9))
//                        .foregroundColor(.white)
//                        .cornerRadius(14)
//                        .transition(.opacity)
//                        .zIndex(1)
//                }
//            }
//            .padding()
//            .onDisappear {
//                timer?.invalidate()
//            }
//        }
//        
//    }
//}



import SwiftUI

struct ContentView: View {
    @StateObject private var motionManager = MotionManager()
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 8) {
                Spacer(minLength: 4)
                
                // Connection status indicator
                HStack {
                    Image(systemName: motionManager.isConnected ? "iphone" : "iphone.slash")
                        .foregroundColor(motionManager.isConnected ? .green : .orange)
                        .font(.system(size: 14, weight: .semibold))
                    
                    Text(motionManager.isConnected ? "Connected" : "Disconnected")
                        .font(.caption2)
                        .foregroundColor(motionManager.isConnected ? .green : .orange)
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(motionManager.isConnected ? Color.green.opacity(0.2) : Color.orange.opacity(0.2))
                )
                
                Text(motionManager.currentTest.replacingOccurrences(of: "_", with: " ").capitalized)
                    .font(motionManager.currentTest == "App Closed" ? .headline.weight(.bold) : .title3.weight(.bold))
                    .foregroundColor(motionManager.currentTest == "App Closed" ? .red : .white)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 4)
                if motionManager.isCollecting {
                    Text("Collecting…")
                        .font(.title2).bold().foregroundColor(.green)
                        .padding(.top, 8)
                } else if motionManager.currentTest == "App Closed" {
                    VStack(spacing: 6) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.red)
                        
                        Text("App Closed")
                            .font(.headline.bold())
                            .foregroundColor(.red)
                        
                        VStack(spacing: 2) {
                            Text("To Exit:")
                                .font(.caption.weight(.medium))
                                .foregroundColor(.white)
                            
                            Text("Digital Crown 2x")
                                .font(.caption2.weight(.semibold))
                                .foregroundColor(.yellow)
                            
                            Text("OR")
                                .font(.system(size: 8))
                                .foregroundColor(.gray)
                            
                            Text("Swipe up")
                                .font(.caption2.weight(.semibold))
                                .foregroundColor(.yellow)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.black.opacity(0.8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.yellow, lineWidth: 0.5)
                                )
                        )
                    }
                    .padding(.top, 6)
                } else {
                    Text("Waiting for next test…")
                        .font(.body)
                        .foregroundColor(.yellow)
                        .padding(.top, 8)
                }
                if !motionManager.lastErrorMsg.isEmpty && motionManager.currentTest != "App Closed" {
                    Text(motionManager.lastErrorMsg)
                        .foregroundColor(motionManager.lastErrorMsg.contains("successfully") ? .green : .red)
                        .multilineTextAlignment(.center)
                        .padding(.top, 10)
                        .font(.caption)
                        .padding(.horizontal, 4)
                }
                Spacer(minLength: 8)
            }
        }
        .onAppear { motionManager.activateSession() }
    }
}
