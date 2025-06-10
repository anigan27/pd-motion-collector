//
//  ContentView.swift
//  Watch App for Motion Data Collection Watch App
//
//  Created by Anika Ganu on 6/4/25.
//

import SwiftUI
import CoreMotion
import WatchConnectivity

struct ContentView: View {
    @StateObject private var motionManager = MotionManager()
    @State private var isCollecting = false
    @State private var useTimer = false
    @State private var isCountingDown = false
    @State private var timer: Timer?
    @State private var countdown = 5
    @State private var timerCountdown = 10
    @State private var isTimerRunning = false
    @State private var showCollectedToast = false
    @State private var samples: [MotionSample] = []
    
    var body: some View {
        ScrollView {
            ZStack {
                VStack(spacing: 24) {
                    Spacer(minLength: 0)
                    Toggle("10s Timer", isOn: $useTimer)
                        .padding()
                    Button(action: {
                        if useTimer {
                            // Begin 5-second countdown
                            isCountingDown = true
                            countdown = 5
                            timer?.invalidate()
                            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { t in
                                if countdown > 1 {
                                    countdown -= 1
                                    WKInterfaceDevice.current().play(.click)
                                } else {
                                    t.invalidate()
                                    isCountingDown = false
                                    // Start collection and haptic
                                    isCollecting = true
                                    motionManager.startCollecting()
                                    WKInterfaceDevice.current().play(.start)
                                    // Start 10-second timer
                                    timerCountdown = 10
                                    isTimerRunning = true
                                    timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { t in
                                        if timerCountdown > 1 {
                                            timerCountdown -= 1
                                        } else {
                                            t.invalidate()
                                            isTimerRunning = false
                                            isCollecting = false
                                            motionManager.stopCollecting()
                                            WKInterfaceDevice.current().play(.stop)
                                            DispatchQueue.main.async {
                                                showCollectedToast = true
                                            }
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                                showCollectedToast = false
                                            }
                                        }
                                    }
                                }
                            }
                        } else {
                            // Normal manual start/stop
                            isCollecting.toggle()
                            if isCollecting {
                                motionManager.startCollecting()
                            } else {
                                motionManager.stopCollecting()
                                showCollectedToast = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    showCollectedToast = false
                                }
                                
                            }
                        }
                    }) {
                        Text(
                            isCountingDown
                            ? "\(countdown)"
                            : (isTimerRunning
                               ? "\(timerCountdown)"
                               : (isCollecting ? "Stop" : "Start"))
                        )
                        .font(.system(size: 40, weight: .bold))
                        .padding()
                        .foregroundColor(.white)
                        .background(isCollecting ? Color.red : Color.green)
                        .cornerRadius(16)
                    }
                    .disabled(isCountingDown)
                    
                    
                    
                    Button("Send to Phone") {
                        motionManager.exportAndSendCSV()
                        
                        
                    }
                    .font(.system(size: 22, weight: .bold))
                    //.frame(maxWidth: .infinity, minHeight: 50)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    //.cornerRadius(16)
                    
                    
                    //.padding(.vertical, 8)
                    
                    //Button("Delete Data") {
                    //motionManager.deleteData()
                    
                    //}
                    //.foregroundColor(.red)
                }
                if showCollectedToast {
                    Text("Data successfully collected!")
                        .font(.headline)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 20)
                        .background(Color.gray.opacity(0.9))
                        .foregroundColor(.white)
                        .cornerRadius(14)
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .padding()
            .onDisappear {
                timer?.invalidate()
            }
        }
        
    }
}
