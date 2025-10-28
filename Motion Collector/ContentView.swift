import SwiftUI
import QuickLook
import WatchConnectivity
import CryptoKit
import Foundation
import SwiftyRSA
import ZIPFoundation

struct IdentifiableURL: Identifiable { let url: URL; var id: URL { url } }
struct AlertMessage: Identifiable { var id: String { message }; let message: String }
struct ResultsActionAlert: Identifiable {
    let id = UUID()
    let action: String
}

final class SessionState: ObservableObject {
    @Published var completedTests: Set<Int> = []
    @Published var filesForSession: [String] = []
    @Published var sessionID: String = UUID().uuidString
    @Published var step: Int = 1
    @Published var idx: Int = 0
    func markComplete(_ idx: Int) { completedTests.insert(idx) }
    func addFileForSession(_ fname: String) { filesForSession.append(fname) }
    func resetSession() {
        step = 1
        idx = 0
        completedTests = []
        sessionID = UUID().uuidString
        filesForSession = []
    }
}

struct ContentView: View {
    @StateObject private var state = SessionState()
    @StateObject private var filesMgr = PhoneSessionManager()
    @StateObject private var connectionManager = ContentViewConnectionManager()
    @State private var fileToPreview: URL? = nil
    @State private var fileToShare: URL? = nil
    @State private var showFileShare: Bool = false
    @State private var fileToDelete: IdentifiableURL? = nil
    @State private var showDeleteAlert: Bool = false
    @State private var showFilePreview: Bool = false
    @State private var showRestartConfirm: Bool = false
    @State private var sendFileResult: AlertMessage? = nil
    @State private var showTablePreview: Bool = false
    @State private var previewError: String? = nil
    @State private var tablePreviewTitle: String = ""
    @State private var csvPreviewHeaders: [String] = []
    @State private var csvPreviewRows: [[String]] = []
    @State private var showWelcome: Bool = true
    @State private var showResults: Bool = false
    @State private var resultsActionAlert: ResultsActionAlert? = nil
    @State private var isWatchConnected: Bool = false
    
    static let allTests = TestType.allCases
    static let timedTests = TestType.timed
    static let untimedTests = TestType.untimed
    
    let allTests = ContentView.allTests
    let timedTests = ContentView.timedTests
    let untimedTests = ContentView.untimedTests
    private let userDefaultsKey = "MotionAppSession"
    var isSessionComplete: Bool { state.completedTests.count == allTests.count }
    var nextTestIndex: Int { state.completedTests.count }
    var nextTest: TestType? { nextTestIndex < allTests.count ? allTests[nextTestIndex] : nil }
    var curTest: TestType? { state.idx < allTests.count ? allTests[state.idx] : nil }
    var isTimedTest: Bool { curTest.map { timedTests.contains($0) } ?? false }
    func testIsComplete(_ idx: Int) -> Bool { state.completedTests.contains(idx) }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 36) {
                        if showWelcome {
                            WelcomeScreen(showWelcome: $showWelcome)
                                .frame(maxWidth: 440)
                                .padding(.top, 2)
                        }
                        if !showWelcome {
                            // Connection status indicator
                            ConnectionStatusView(
                                isConnected: connectionManager.isConnected,
                                connectionQuality: connectionManager.connectionQuality
                            )
                                .padding(.horizontal, 20)
                                .padding(.bottom, 10)
                            
                            if isSessionComplete {
                                SessionCompleteScreen(
                                    onRestart: { showRestartConfirm = true },
                                    uploadAllCSVFiles: uploadAllCSVFiles,
                                    closeWatchApp: closeWatchApp,
                                    filesMgr: filesMgr,
                                    resultsActionAlert: $resultsActionAlert
                                )
                                    .frame(maxWidth: 420)
                                    .padding(.vertical, 8)
                            } else if state.step == 1 {
                                MainTestCards(
                                    state: state,
                                    timedTests: timedTests,
                                    untimedTests: untimedTests,
                                    nextTestIndex: nextTestIndex,
                                    testIsComplete: testIsComplete,
                                    sendWatchTestCommand: sendWatchTestCommand
                                )
                                .frame(maxWidth: 440)
                                .padding(.vertical, 8)
                            } else if state.step == 2, let test = curTest {
                                HowToScreen(
                                    test: test,
                                    onBegin: { state.step = 3 },
                                    sendWatchTestCommand: sendWatchTestCommand
                                )
                                .frame(maxWidth: 420)
                                .padding(.top, 8)
                            } else if state.step == 3, let test = curTest {
                                if isTimedTest {
                                    TimedCollectScreen(
                                        test: test,
                                        onDone: { state.markComplete(state.idx); state.step = 4 },
                                        sendWatchTestCommand: sendWatchTestCommand
                                    )
                                    .frame(maxWidth: 420)
                                    .padding(.top, 8)
                                } else {
                                    UntimedCollectScreen(
                                        test: test,
                                        onDone: { state.markComplete(state.idx); state.step = 4 },
                                        sendWatchTestCommand: sendWatchTestCommand
                                    )
                                    .frame(maxWidth: 420)
                                    .padding(.top, 8)
                                }
                            } else if state.step == 4, let test = curTest {
                                DoneTestScreen(
                                    test: test, 
                                    onNext: {
                                        // Always go back to test selection if there are incomplete tests
                                        if state.completedTests.count < allTests.count {
                                            state.step = 1 // Go back to test selection screen
                                        }
                                        // If all tests are complete, stay on completion screen (step 4)
                                    },
                                    remainingTests: allTests.count - state.completedTests.count
                                )
                                .frame(maxWidth: 420)
                                .padding(.top, 9)
                            }
                            HandheldResultsDropdown(
                                filesMgr: filesMgr,
                                showResults: $showResults,
                                fileToPreview: $fileToPreview,
                                showFilePreview: $showFilePreview, // <-- Pass the binding here
                                fileToShare: $fileToShare,
                                showFileShare: $showFileShare,
                                fileToDelete: $fileToDelete,
                                sendFileResult: $sendFileResult,
                                resultsActionAlert: $resultsActionAlert,
                                uploadAllCSVFiles: uploadAllCSVFiles,
                                closeWatchApp: closeWatchApp,
                                isSessionComplete: isSessionComplete
                            )
                            .frame(maxWidth: 440)
                            .padding(.bottom, 22)
                        }
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showTablePreview) {
            NavigationView {
                if let error = previewError {
                    ScrollView(.vertical) {
                        Text(error).foregroundColor(.red).font(.system(.callout, design: .monospaced)).padding()
                    }
                    .navigationTitle(tablePreviewTitle)
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { showTablePreview = false } } }
                } else {
                    CSVTableView(headers: csvPreviewHeaders, rows: csvPreviewRows)
                        .navigationTitle(tablePreviewTitle)
                        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { showTablePreview = false } } }
                }
            }
        }
        .sheet(isPresented: $showFilePreview) {
            if let url = fileToPreview {
                QLPreviewControllerWrapper(fileURL: url)
            }
        }
        .sheet(isPresented: $showFileShare) {
            if let url = fileToShare {
                ActivityView(fileURL: url, isPresented: $showFileShare)
            }
        }
        .alert(item: $fileToDelete) { idUrl in
            Alert(
                title: Text("Delete File?"),
                message: Text("Are you sure you want to delete \(idUrl.url.lastPathComponent)? This cannot be undone."),
                primaryButton: .destructive(Text("Delete")) {
                    filesMgr.deleteFile(idUrl.url)
                    filesMgr.reloadFiles()
                    state.filesForSession.removeAll { $0 == idUrl.url.lastPathComponent }
                    showResults.toggle()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { showResults.toggle() }
                },
                secondaryButton: .cancel { }
            )
        }
        .alert(item: $sendFileResult) { msg in
            Alert(title: Text("Transfer"), message: Text(msg.message), dismissButton: .default(Text("OK")))
        }
        .confirmationDialog("Restart Session?", isPresented: $showRestartConfirm) {
            Button("Restart Session") {
                restartSession()
                showWelcome = true
            }
            Button("Cancel", role: .cancel) { showRestartConfirm = false }
        }
        //.onAppear { loadSessionState(); filesMgr.reloadFiles() }
        .onAppear {
            //loadSessionState()
            state.resetSession() // Always start fresh for now
            filesMgr.reloadFiles()
            // Ensure filesForSession is in sync with actual files
            let allFnames = filesMgr.allFiles.map { $0.lastPathComponent }
            state.filesForSession = state.filesForSession.filter { allFnames.contains($0) }
            saveSessionState()
            
            // Use enhanced connection manager for connection state
            isWatchConnected = connectionManager.isConnected
            
            // Start watch session with enhanced reliability
            startWatchSession()
        }
        .onReceive(NotificationCenter.default.publisher(for: .didReceiveWatchFile)) { _ in
            filesMgr.reloadFiles()
            let allFnames = filesMgr.allFiles.map { $0.lastPathComponent }
            let newArrivals = allFnames.filter { !state.filesForSession.contains($0) }
            if let latest = newArrivals.sorted(by: >).first {
                state.filesForSession.append(latest)
                saveSessionState()
                // No automatic preview; user must tap to preview
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .watchConnectionChanged)) { notification in
            if let connected = notification.object as? Bool {
                // Update both old and new connection status for compatibility
                isWatchConnected = connected
                if connected {
                    print("[DEBUG] iPhone: Watch connection restored - using enhanced session restart")
                    startWatchSession() 
                }
            }
        }
    }
    
    // MARK: - Session Management Methods
    
    func startWatchSession() {
        sendWatchTestCommand("startSession", allTests[0]) // Use first test as placeholder
        print("[MotionCollector] Started watch session")
    }

    func endWatchSession() {
        sendWatchTestCommand("endSession", allTests[0]) // Use first test as placeholder
        print("[MotionCollector] Ended watch session")
    }

    func restartSession() {
        endWatchSession() // End current watch session
        state.resetSession()
        saveSessionState()
        startWatchSession() // Start new watch session
    }
    
    func closeWatchApp() {
        sendWatchTestCommand("closeApp", allTests[0]) // Use first test as placeholder
        print("[MotionCollector] Sent close command to watch app")
    }
    
    // MARK: - Helper Structs for UI Components
    
    struct ActivityView: UIViewControllerRepresentable {
        let fileURL: URL
        @Binding var isPresented: Bool
        func makeUIViewController(context: Context) -> UIActivityViewController {
            let controller = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
            controller.completionWithItemsHandler = { _, _, _, _ in
                isPresented = false
            }
            return controller
        }
        func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
    }
    
    struct QLPreviewControllerWrapper: UIViewControllerRepresentable {
        let fileURL: URL
        typealias UIViewControllerType = QLPreviewController
        func makeUIViewController(context: Context) -> QLPreviewController {
            let controller = QLPreviewController()
            controller.dataSource = context.coordinator
            return controller
        }
        func updateUIViewController(_ uiViewController: QLPreviewController, context: Context) {}
        func makeCoordinator() -> Coordinator { Coordinator(fileURL: fileURL) }
        class Coordinator: NSObject, QLPreviewControllerDataSource {
            let fileURL: URL
            init(fileURL: URL) { self.fileURL = fileURL }
            func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }
            func previewController(_ c: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem { fileURL as NSURL }
        }
    }
    
    
    struct WelcomeScreen: View {
        @Binding var showWelcome: Bool
        var body: some View {
            VStack(spacing: 15) {
                Spacer().frame(height: 10) // Minimal top spacer
                Image("Pd-icon") // Custom image from Assets.xcassets
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 220, height: 220) // Slightly smaller than original
                Text("Welcome to ParkinSpot")
                    .font(.system(size: 30, weight: .heavy)) // Slightly smaller font
                    .foregroundColor(.accentColor)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20) // Add horizontal padding
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Before beginning the tests:")
                        .font(.title3)
                        .foregroundColor(.primary)
                        .fontWeight(.medium)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top, spacing: 8) {
                            Text("•")
                                .font(.title3)
                                .foregroundColor(.accentColor)
                            Text("Wear the watch on your dominant hand")
                                .font(.body) // Slightly smaller font
                                .foregroundColor(.primary)
                        }
                        
                        HStack(alignment: .top, spacing: 8) {
                            Text("•")
                                .font(.title3)
                                .foregroundColor(.accentColor)
                            Text("Grab an empty plastic bottle, a button-down shirt, and a piece of printer paper")
                                .font(.body) // Slightly smaller font
                                .foregroundColor(.primary)
                        }
                        
                        HStack(alignment: .top, spacing: 8) {
                            Text("•")
                                .font(.title3)
                                .foregroundColor(.accentColor)
                            Text("You'll be guided step by step")
                                .font(.body) // Slightly smaller font
                                .foregroundColor(.primary)
                        }
                        
                        HStack(alignment: .top, spacing: 8) {
                            Text("•")
                                .font(.title3)
                                .foregroundColor(.accentColor)
                            Text("Every test auto-saves and appears under 'Your Results'")
                                .font(.body) // Slightly smaller font
                                .foregroundColor(.primary)
                        }
                    }
                }
                .padding(.horizontal, 32)
                
                Spacer().frame(height: 15) // Controlled spacing before button
                
                Button(action: { showWelcome = false }) {
                    Text("Get Started")
                        .font(.title2.bold())
                        .padding(.vertical, 16)
                        .padding(.horizontal, 58)
                        .background(Capsule().fill(Color.accentColor))
                        .foregroundColor(.white)
                }
                
                Spacer().frame(height: 20) // Small bottom spacer
            }
            .background(Color(.systemBackground).edgesIgnoringSafeArea(.all))
        }
    }
    
    struct MainTestCards: View {
        @ObservedObject var state: SessionState
        let timedTests: [TestType]
        let untimedTests: [TestType]
        let nextTestIndex: Int
        let testIsComplete: (Int) -> Bool
        let sendWatchTestCommand: (String, TestType) -> Void
        var body: some View {
            ScrollViewReader { proxy in
                VStack(spacing: 20) {
                    Section(header:
                                Text("Timed Tests").font(.title2.weight(.bold)).foregroundColor(.accentColor).frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 4)
                    ) {
                        ForEach(Array(timedTests.enumerated()), id: \.offset) { i, test in
                            // Use the index in allTests, not just timedTests
                            let mainIdx = ContentView.allTests.firstIndex(of: test) ?? i
                            TestCard(
                                test: test,
                                isComplete: testIsComplete(mainIdx),
                                selected: mainIdx == nextTestIndex,
                                onStart: {
                                    sendWatchTestCommand("wait", test)
                                    state.idx = mainIdx; state.step = 2
                                }
                            )
                            .id("test_\(mainIdx)") // Add ID for scrolling
                        }
                    }
                    Section(header:
                                Text("Untimed Tests").font(.title2.weight(.bold)).foregroundColor(.accentColor).frame(maxWidth:.infinity, alignment:.center)
                        .padding(.top, 14)
                    ) {
                        ForEach(Array(untimedTests.enumerated()), id: \.offset) { j, test in
                            // Use the actual index in allTests to ensure correct test numbering
                            let mainIdx = ContentView.allTests.firstIndex(of: test) ?? j
                            TestCard(
                                test: test,
                                isComplete: testIsComplete(mainIdx),
                                selected: mainIdx == nextTestIndex,
                                onStart: {
                                    sendWatchTestCommand("wait", test)
                                    state.idx = mainIdx; state.step = 2
                                }
                            )
                            .id("test_\(mainIdx)") // Add ID for scrolling
                        }
                    }
                }
                .onAppear {
                    // Auto-scroll to the selected test when view appears
                    if nextTestIndex < ContentView.allTests.count {
                        withAnimation(.easeInOut(duration: 0.6)) {
                            proxy.scrollTo("test_\(nextTestIndex)", anchor: .center)
                        }
                    }
                }
                .onChange(of: nextTestIndex) { oldValue, newIndex in
                    // Auto-scroll when the selected test changes
                    if newIndex < ContentView.allTests.count {
                        withAnimation(.easeInOut(duration: 0.6)) {
                            proxy.scrollTo("test_\(newIndex)", anchor: .center)
                        }
                    }
                }
            }
        }
    }
    
    struct TestCard: View {
        let test: TestType
        let isComplete: Bool
        let selected: Bool
        let onStart: () -> Void
        
        // Get test number from all tests array
        var testNumber: Int {
            if let index = ContentView.allTests.firstIndex(of: test) {
                return index + 1
            }
            return 0
        }
        var body: some View {
            VStack(spacing: 12) {
                Image(systemName:"rectangle.and.pencil.and.ellipsis")
                    .font(.system(size:42))
                    .foregroundColor(selected ? .accentColor : (isComplete ? .green : .blue))
                    .padding(.top,6)
                Text("Test \(testNumber): \(test.rawValue)")
                    .font(.title3.weight(selected ? .bold : .regular))
                    .foregroundColor(isComplete ? .green : .accentColor)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                if isComplete {
                    Image(systemName:"checkmark.circle.fill")
                        .font(.title2).foregroundColor(.green)
                }
                Text(test.instructions)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                Button(action: onStart) {
                    Text(isComplete ? "Redo Test" : "Begin Test")
                        .font(.body.bold())
                        .padding(.vertical,8)
                        .padding(.horizontal,38)
                        .background(Capsule().fill(selected ? Color.accentColor : Color.blue.opacity(0.15)))
                        .foregroundColor(selected ? .white : .accentColor)
                }.padding(.bottom,7)
            }
            .frame(maxWidth:.infinity)
            .padding()
            .background(RoundedRectangle(cornerRadius:21).fill(Color.white).shadow(color:.black.opacity(0.06),radius:6))
            .overlay(
                RoundedRectangle(cornerRadius:21).stroke(selected ? Color.accentColor : Color(.systemGray5), lineWidth: selected ? 2 : 1)
            )
            .padding(.horizontal,18).padding(.vertical,6)
        }
    }
    
    struct HowToScreen: View {
        let test: TestType
        let onBegin: () -> Void
        let sendWatchTestCommand: (String, TestType) -> Void
        var isTimed: Bool { ContentView.timedTests.contains(test) }
        var body: some View {
            VStack(spacing:29) {
                Spacer()
                Text("How to do this test").font(.title2.bold()).foregroundColor(.accentColor).multilineTextAlignment(.center)
                Image(systemName:"questionmark.circle.fill").font(.system(size:58)).foregroundColor(.blue)
                Text(test.instructions)
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal,22)
                Button("Begin Test") {
                    if isTimed {
                        sendWatchTestCommand("start", test) // Only send 'start' for timed tests
                    }
                    onBegin()
                }
                .font(.title3.bold())
                .padding(.horizontal, 40).padding(.vertical, 14)
                .background(Capsule().fill(Color.accentColor))
                .foregroundColor(.white)
                Spacer()
            }
            .background(Color(.systemBackground).edgesIgnoringSafeArea(.all))
        }
    }
    
    struct TimedCollectScreen: View {
        let test: TestType
        let onDone: () -> Void
        let sendWatchTestCommand: (String, TestType) -> Void
        @State private var timeLeft: Int = 10
        @State private var collecting: Bool = true
        
        // Get test number from all tests array
        var testNumber: Int {
            if let index = ContentView.allTests.firstIndex(of: test) {
                return index + 1
            }
            return 0
        }
        
        var body: some View {
            VStack(spacing:33) {
                Spacer()
                Text("Collecting Data").font(.title.bold()).foregroundColor(.accentColor)
                Image(systemName:"clock.arrow.circlepath").font(.system(size:66)).foregroundColor(.accentColor)
                Text("Test \(testNumber): \(test.rawValue)").font(.title2.bold()).foregroundColor(.accentColor)
                Text("Time left: \(timeLeft)s").font(.largeTitle.bold())
                ProgressView(value:Double(10-timeLeft),total:10).progressViewStyle(LinearProgressViewStyle(tint:.accentColor)).scaleEffect(y:1.3).padding(.horizontal,60)
                Spacer()
                Spacer()
            }
            .onAppear {
                Timer.scheduledTimer(withTimeInterval:1,repeats:true){t in
                    if collecting {
                        timeLeft -= 1
                        if timeLeft <= 0 {
                            collecting = false
                            t.invalidate()
                            sendWatchTestCommand("stop", test)
                            onDone()
                        }
                    } else {
                        // Stop was already called, just invalidate timer
                        t.invalidate()
                    }
                }
            }
        }
    }
    
    struct UntimedCollectScreen: View {
        let test: TestType
        let onDone: () -> Void
        let sendWatchTestCommand: (String, TestType) -> Void
        @State private var collecting: Bool = false
        
        // Get test number from all tests array
        var testNumber: Int {
            if let index = ContentView.allTests.firstIndex(of: test) {
                return index + 1
            }
            return 0
        }
        var body: some View {
            VStack(spacing:37){
                Spacer()
                Text("Manual Data Collection").font(.title.bold()).foregroundColor(.accentColor)
                Image(systemName:"stopwatch.fill").font(.system(size:64)).foregroundColor(.accentColor)
                Text("Test \(testNumber): \(test.rawValue)").font(.title2.bold()).foregroundColor(.accentColor)
                Text(collecting ? "Press Stop when ready!" : "Press Start to begin").font(.body).foregroundColor(.secondary).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                Spacer()
                if !collecting {
                    Button("Start") {
                        collecting = true
                        sendWatchTestCommand("start", test)
                    }
                    .font(.title2.bold()).padding(.vertical,12).padding(.horizontal,44)
                    .background(Capsule().fill(Color.accentColor)).foregroundColor(.white)
                } else {
                    Button("Stop") {
                        collecting = false
                        sendWatchTestCommand("stop", test)
                        onDone()
                    }
                    .font(.title2.bold()).padding(.vertical,12).padding(.horizontal,44)
                    .background(Capsule().fill(Color.red)).foregroundColor(.white)
                }
                Spacer()
            }
        }
    }
    
    struct DoneTestScreen: View {
        let test: TestType
        let onNext: () -> Void
        let remainingTests: Int
        var body: some View {
            VStack(spacing:32){
                Spacer()
                Image(systemName:"checkmark.seal.fill").font(.system(size:76)).foregroundColor(.green)
                Text("Test Complete!").font(.title.bold())
                    .foregroundColor(.accentColor)
                
                if remainingTests > 0 {
                    Text("\(remainingTests) test\(remainingTests == 1 ? "" : "s") remaining").font(.title2).foregroundColor(.secondary).padding(.bottom, 8)
                } else {
                    Text("All tests completed!").font(.title2).foregroundColor(.green).padding(.bottom, 8)
                }
                
                Text("Press Next to continue. Your CSV file for this test is in Recent Files.").font(.title3).multilineTextAlignment(.center).fixedSize(horizontal:false,vertical:true).padding(.horizontal,26)
                
                Button(remainingTests > 0 ? "Continue Testing" : "View Results", action: onNext)
                    .font(.title2.bold()).padding(.vertical,12).padding(.horizontal,48).background(Capsule().fill(Color.green)).foregroundColor(.white)
                Spacer()
            }
        }
    }
    
    struct SessionCompleteScreen: View {
        let onRestart: () -> Void
        let uploadAllCSVFiles: () -> Void
        let closeWatchApp: () -> Void
        @ObservedObject var filesMgr: PhoneSessionManager
        @Binding var resultsActionAlert: ResultsActionAlert?
        
        var body: some View {
            VStack(spacing:36){
                Spacer()
                Image(systemName:"checkmark.circle.fill").font(.system(size:90)).foregroundColor(.green)
                Text("Session Complete!").font(.system(size:34).bold()).foregroundColor(.accentColor)
                Text("Every test is finished and your data is saved.").font(.title2).multilineTextAlignment(.center).fixedSize(horizontal:false,vertical:true).padding(.horizontal,28)
                
                VStack(spacing: 18) {
                    Button("Restart Session", action: onRestart)
                        .font(.title2.bold()).foregroundColor(.white).padding(.vertical,15).padding(.horizontal,62).background(Capsule().fill(Color.accentColor))
                    
                    Button(action: { closeWatchApp() }) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Close Watch App")
                                .font(.body.bold())
                                .foregroundColor(.green)
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 22)
                        .background(Capsule().fill(Color.green.opacity(0.15)))
                    }
                }
                
                Spacer()
            }
        }
    }
    
    struct HandheldResultsDropdown: View {
        @ObservedObject var filesMgr: PhoneSessionManager
        @Binding var showResults: Bool
        @Binding var fileToPreview: URL?
        @Binding var showFilePreview: Bool
        @Binding var fileToShare: URL?
        @Binding var showFileShare: Bool
        @Binding var fileToDelete: IdentifiableURL?
        @Binding var sendFileResult: AlertMessage?
        @Binding var resultsActionAlert: ResultsActionAlert?
        let uploadAllCSVFiles: () -> Void
        let closeWatchApp: () -> Void
        let isSessionComplete: Bool
        @State private var showClearConfirm: Bool = false
        var body: some View {
            VStack(alignment: .center, spacing: 8) {
                Button(action: { withAnimation { showResults.toggle() } }) {
                    HStack {
                        Text("Your Results")
                            .font(.headline)
                            .foregroundColor(.accentColor)
                        Spacer()
                        Image(systemName: showResults ? "chevron.down" : "chevron.right")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.accentColor)
                    }
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                }
                if showResults {
                    if filesMgr.files.isEmpty {
                        Text("No files yet. (Connect your Watch to collect data.)")
                            .font(.footnote)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.top, 10)
                            .padding(.bottom, 8)
                    } else {
                        ForEach(filesMgr.files.filter { $0.lastPathComponent.lowercased() != "inbox" }
                            .sorted { (a, b) in
                                let aDate = (try? a.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                                let bDate = (try? b.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                                return aDate > bDate
                            }
                            .prefix(20), id: \ .self) { url in
                            HStack(spacing: 16) {
                                Text(url.lastPathComponent)
                                    .font(.callout)
                                    .foregroundColor(.primary)
                                    .lineLimit(nil)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                                Text(ContentView.formattedFileSize(for: url))
                                    .font(.subheadline.weight(.medium))
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 4)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(Color(.systemGray5))
                                    )
                                
                                // Preview, Share, and Delete buttons hidden per user request
                            }
                            .padding(.vertical, 7)
                            .background(RoundedRectangle(cornerRadius: 11).fill(Color(.systemGray6)))
                            .overlay(
                                RoundedRectangle(cornerRadius: 11)
                                    .stroke(Color(.systemGray4), lineWidth: 1)
                            )
                            .padding(.vertical, 2)
                        }
                    }
                    
                    // Action buttons for results management
                    if !filesMgr.files.isEmpty {
                        VStack(spacing: 12) {
                            HStack(spacing: 18) {
                                Button(action: { uploadAllCSVFiles() }) {
                                    Text("Upload results")
                                        .font(.body.bold())
                                        .padding(.vertical, 10)
                                        .padding(.horizontal, 22)
                                        .background(Capsule().fill(Color.blue.opacity(0.15)))
                                        .foregroundColor(.accentColor)
                                }
                                Button(action: { showClearConfirm = true }) {
                                    Text("Clear Results")
                                        .font(.body.bold())
                                        .padding(.vertical, 10)
                                        .padding(.horizontal, 22)
                                        .background(Capsule().fill(Color.red.opacity(0.15)))
                                        .foregroundColor(.red)
                                }
                            }
                        }
                        .padding(.top, 12)
                    }
                }
            }
            .padding(.vertical, 12).padding(.horizontal, 17)
            .alert(item: $resultsActionAlert) { alert in
                Alert(title: Text(alert.action), message: Text("Button pressed: \(alert.action)"), dismissButton: .default(Text("OK")))
            }
            .alert("Clear All Results", isPresented: $showClearConfirm) {
                Button("Cancel", role: .cancel) { }
                Button("Clear All", role: .destructive) {
                    filesMgr.clearAllFiles()
                    resultsActionAlert = ResultsActionAlert(action: "Results cleared!")
                }
            } message: {
                Text("This will permanently delete all collected data files. This action cannot be undone.")
            }
        }
    }
    
    struct CSVTableView: View {
        let headers: [String]
        let rows: [[String]]
        var body: some View {
            ScrollView([.horizontal, .vertical]) {
                LazyVStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 0) {
                        ForEach(headers, id: \.self) { header in
                            Text(header)
                                .font(.headline)
                                .padding(6)
                                .frame(minWidth: 110, alignment: .leading)
                                .background(Color(.systemGray5))
                                .border(Color(.systemGray4))
                        }
                    }
                    ForEach(rows.indices, id: \.self) { rowIdx in
                        HStack(spacing: 0) {
                            ForEach(rows[rowIdx], id: \.self) { cell in
                                Text(cell)
                                    .font(.system(.footnote, design: .monospaced))
                                    .padding(5)
                                    .frame(minWidth: 110, alignment: .leading)
                                    .border(Color(.systemGray6))
                            }
                        }
                        .background(rowIdx % 2 == 0 ? Color(.systemBackground) : Color(.systemGray6))
                    }
                }
                .padding(.vertical, 6)
            }
        }
    }
    
    
    
    func saveSessionState() {
        let dict: [String: Any] = [
            "completion": Array(state.completedTests),
            "idx": state.idx,
            "step": state.step,
            "files": state.filesForSession,
            "sessionID": state.sessionID
        ]
        UserDefaults.standard.setValue(dict, forKey: userDefaultsKey)
    }
    
    func loadSessionState() {
        guard let dict = UserDefaults.standard.dictionary(forKey: userDefaultsKey) else { return }
        if let arr = dict["completion"] as? [Int] { state.completedTests = Set(arr) }
        if let idx = dict["idx"] as? Int { state.idx = idx }
        if let step = dict["step"] as? Int { state.step = step }
        if let fnames = dict["files"] as? [String] { state.filesForSession = fnames }
        if let sessionID = dict["sessionID"] as? String { state.sessionID = sessionID }
    }
    
    func sendWatchTestCommand(_ cmd: String, _ test: TestType) {
        let message: [String: Any] = [
            "cmd": cmd,
            "testType": test.fileName,
            "sessionID": state.sessionID,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        // Use the enhanced connection manager for reliable delivery
        connectionManager.sendReliableMessage(message)
        print("[MotionCollector] Sent enhanced command: \(cmd) for test: \(test.rawValue)")
    }
    
    func shortenFileName(_ name: String) -> String {
        name.replacingOccurrences(of: "_", with: " ").split(separator: " ").prefix(3).joined(separator: " ")
    }
    
    func uploadAllCSVFiles() {
        guard let uploader = GoogleCloudUploader() else {
            sendFileResult = AlertMessage(message: "Could not initialize Google Cloud uploader.")
            return
        }
        let csvFiles = filesMgr.files.filter { $0.lastPathComponent.lowercased() != "inbox" && $0.pathExtension.lowercased() == "csv" }
        if csvFiles.isEmpty {
            sendFileResult = AlertMessage(message: "No CSV files to upload.")
            return
        }
        
        // Create ZIP file with date/time and random string
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let dateString = dateFormatter.string(from: Date())
        let randomString = String((0..<5).map { _ in "ABCDEFGHIJKLMNOPQRSTUVWXYZ".randomElement()! })
        let zipFileName = "motion_data_\(dateString)_\(randomString).zip"
        
        // Create temporary directory for ZIP file
        let tempDir = FileManager.default.temporaryDirectory
        let zipFileURL = tempDir.appendingPathComponent(zipFileName)
        
        // Remove existing ZIP file if it exists
        try? FileManager.default.removeItem(at: zipFileURL)
        
        // Create ZIP archive using ZIPFoundation (throwing initializer)
        do {
            let archive = try Archive(url: zipFileURL, accessMode: .create)
            
            for csvURL in csvFiles {
                try archive.addEntry(with: csvURL.lastPathComponent, fileURL: csvURL)
            }
            
            // Upload the ZIP file
            uploader.uploadZipFile(fileURL: zipFileURL) { success, errorMsg in
                DispatchQueue.main.async {
                    // Clean up temp file
                    try? FileManager.default.removeItem(at: zipFileURL)
                    
                    if success {
                        self.sendFileResult = AlertMessage(message: "Successfully uploaded \(csvFiles.count) CSV files as \(zipFileName)")
                    } else {
                        self.sendFileResult = AlertMessage(message: "Failed to upload ZIP file: \(errorMsg ?? "Unknown error")")
                    }
                }
            }
            
        } catch {
            DispatchQueue.main.async {
                self.sendFileResult = AlertMessage(message: "Failed to create ZIP archive: \(error.localizedDescription)")
            }
        }
    }
    
    func previewCSVorFile(_ url: URL) {
        previewError = nil
        tablePreviewTitle = url.lastPathComponent
        if url.pathExtension.lowercased() == "csv" || url.pathExtension.lowercased() == "txt" {
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let fileStr = try String(contentsOf: url, encoding: .utf8)
                    let lines = fileStr.components(separatedBy: .newlines).filter { !$0.isEmpty }
                    guard !lines.isEmpty else {
                        DispatchQueue.main.async {
                            self.previewError = "(File is empty)"
                            self.csvPreviewHeaders = []
                            self.csvPreviewRows = []
                            self.showTablePreview = true
                        }
                        return
                    }
                    var table: [[String]] = []
                    for line in lines {
                        let fields = line.split(separator: ",", omittingEmptySubsequences: false).map { String($0) }
                        table.append(fields)
                    }
                    let headers = table.first ?? []
                    let rows = Array(table.dropFirst())
                    DispatchQueue.main.async {
                        self.csvPreviewHeaders = headers
                        self.csvPreviewRows = rows
                        self.showTablePreview = true
                    }
                } catch {
                    DispatchQueue.main.async {
                        self.previewError = "Error loading file: \(error.localizedDescription)"
                        self.csvPreviewHeaders = []
                        self.csvPreviewRows = []
                        self.showTablePreview = true
                    }
                }
            }
        } else {
            fileToPreview = url
            showFilePreview = true
        }
    }
    
    static func formattedFileSize(for url: URL) -> String {
        do {
            let attr = try FileManager.default.attributesOfItem(atPath: url.path)
            if let size = attr[.size] as? UInt64 {
                let formatter = ByteCountFormatter()
                formatter.countStyle = .file
                return formatter.string(fromByteCount: Int64(size))
            }
        } catch {}
        return "--"
    }


} // End of ContentView struct

class GoogleCloudUploader {
    private let keyFileName = "pd-data-store-08658f0645c0" // without .json
    private let keyFileExt = "json"
    private var serviceAccount: [String: Any] = [:]
    private var accessToken: String?
    private var tokenExpiry: Date?
    private let bucketName = "pd-training-dataset" // <-- Set your bucket name here

    init?() {
        guard let url = Bundle.main.url(forResource: keyFileName, withExtension: keyFileExt),
              let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            print("Could not load Google Cloud JSON key file.")
            return nil
        }
        self.serviceAccount = json
    }

    // MARK: - JWT Generation
    private func generateJWT() -> String? {
        guard let clientEmail = serviceAccount["client_email"] as? String,
              let privateKey = serviceAccount["private_key"] as? String,
              let tokenURI = serviceAccount["token_uri"] as? String else { return nil }
        let header = ["alg": "RS256", "typ": "JWT"]
        let iat = Int(Date().timeIntervalSince1970)
        let exp = iat + 3600
        let payload: [String: Any] = [
            "iss": clientEmail,
            "scope": "https://www.googleapis.com/auth/devstorage.read_write",
            "aud": tokenURI,
            "exp": exp,
            "iat": iat
        ]
        func base64url(_ data: Data) -> String {
            return data.base64EncodedString().replacingOccurrences(of: "+", with: "-")
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: "=", with: "")
        }
        guard let headerData = try? JSONSerialization.data(withJSONObject: header),
              let payloadData = try? JSONSerialization.data(withJSONObject: payload) else { return nil }
        let headerB64 = base64url(headerData)
        let payloadB64 = base64url(payloadData)
        let signingInput = "\(headerB64).\(payloadB64)"
        // Extract private key from PEM
        let keyLines = privateKey.components(separatedBy: "\n").filter { !$0.contains("PRIVATE KEY") && !$0.isEmpty }
        let keyBase64 = keyLines.joined()
        guard let keyData = Data(base64Encoded: keyBase64) else { return nil }
        // Sign with CryptoKit
        guard let signature = try? RSASigner.sign(data: signingInput.data(using: .utf8)!, privateKey: keyData) else { return nil }
        let signatureB64 = base64url(signature)
        return "\(signingInput).\(signatureB64)"
    }

    // MARK: - Get Access Token
    func fetchAccessToken(completion: @escaping (String?) -> Void) {
        if let token = accessToken, let expiry = tokenExpiry, expiry > Date() {
            completion(token)
            return
        }
        guard let tokenURI = serviceAccount["token_uri"] as? String,
              let jwt = generateJWT() else { completion(nil); return }
        var req = URLRequest(url: URL(string: tokenURI)!)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body = "grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=\(jwt)"
        req.httpBody = body.data(using: .utf8)
        URLSession.shared.dataTask(with: req) { data, resp, err in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let token = json["access_token"] as? String,
                  let expiresIn = json["expires_in"] as? Double else { completion(nil); return }
            self.accessToken = token
            self.tokenExpiry = Date().addingTimeInterval(expiresIn)
            completion(token)
        }.resume()
    }

    // MARK: - Upload CSV File
    func uploadCSVFile(fileURL: URL, completion: @escaping (Bool, String?) -> Void) {
        fetchAccessToken { token in
            guard let token = token else { completion(false, "Could not get access token"); return }
            let fileName = fileURL.lastPathComponent
            let uploadURL = "https://storage.googleapis.com/upload/storage/v1/b/\(self.bucketName)/o?uploadType=media&name=\(fileName)"
            var req = URLRequest(url: URL(string: uploadURL)!)
            req.httpMethod = "POST"
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            req.setValue("text/csv", forHTTPHeaderField: "Content-Type")
            guard let fileData = try? Data(contentsOf: fileURL) else { completion(false, "Could not read file"); return }
            req.httpBody = fileData
            URLSession.shared.dataTask(with: req) { data, resp, err in
                if let err = err { completion(false, err.localizedDescription); return }
                guard let httpResp = resp as? HTTPURLResponse else { completion(false, "No response"); return }
                if httpResp.statusCode == 200 {
                    completion(true, nil)
                } else {
                    let msg = String(data: data ?? Data(), encoding: .utf8)
                    completion(false, "Upload failed: \(msg ?? "Unknown error")")
                }
            }.resume()
        }
    }
    
    // MARK: - Upload ZIP File
    func uploadZipFile(fileURL: URL, completion: @escaping (Bool, String?) -> Void) {
        fetchAccessToken { token in
            guard let token = token else { completion(false, "Could not get access token"); return }
            let fileName = fileURL.lastPathComponent
            let uploadURL = "https://storage.googleapis.com/upload/storage/v1/b/\(self.bucketName)/o?uploadType=media&name=\(fileName)"
            var req = URLRequest(url: URL(string: uploadURL)!)
            req.httpMethod = "POST"
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            req.setValue("application/zip", forHTTPHeaderField: "Content-Type")
            guard let fileData = try? Data(contentsOf: fileURL) else { completion(false, "Could not read ZIP file"); return }
            req.httpBody = fileData
            URLSession.shared.dataTask(with: req) { data, resp, err in
                if let err = err { completion(false, err.localizedDescription); return }
                guard let httpResp = resp as? HTTPURLResponse else { completion(false, "No response"); return }
                if httpResp.statusCode == 200 {
                    completion(true, nil)
                } else {
                    let msg = String(data: data ?? Data(), encoding: .utf8)
                    completion(false, "Upload failed: \(msg ?? "Unknown error")")
                }
            }.resume()
        }
    }
}

// Helper for RSA signing (CryptoKit does not support RSA private key signing directly)
struct RSASigner {
    static func sign(data: Data, privateKey: Data) throws -> Data {
        // Convert privateKey Data to PEM string
        let pemString = "-----BEGIN PRIVATE KEY-----\n" + privateKey.base64EncodedString(options: [.lineLength64Characters, .endLineWithLineFeed]) + "\n-----END PRIVATE KEY-----"
        let key = try PrivateKey(pemEncoded: pemString)
        let clear = ClearMessage(data: data)
        let signature = try clear.signed(with: key, digestType: .sha256)
        return signature.data
    }
}

// MARK: - Connection Status View

struct ConnectionStatusView: View {
    let isConnected: Bool
    let connectionQuality: ContentViewConnectionManager.ConnectionQuality
    
    var body: some View {
        HStack {
            Image(systemName: isConnected ? "applewatch" : "applewatch.slash")
                .foregroundColor(isConnected ? connectionQuality.color : .red)
                .font(.system(size: 16, weight: .semibold))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(isConnected ? "Watch Connected" : "Watch Disconnected")
                    .font(.caption)
                    .foregroundColor(isConnected ? connectionQuality.color : .red)
                    .fontWeight(.medium)
                
                if isConnected {
                    Text("Quality: \(connectionQuality.description)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isConnected ? connectionQuality.color.opacity(0.1) : Color.red.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isConnected ? connectionQuality.color.opacity(0.3) : Color.red.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Enhanced Connection Manager for ContentView
class ContentViewConnectionManager: ObservableObject {
    @Published var isConnected = false
    @Published var connectionQuality: ConnectionQuality = .unknown
    
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
        
        var color: Color {
            switch self {
            case .excellent: return .green
            case .good: return .blue
            case .poor: return .orange
            case .unknown: return .gray
            }
        }
    }
    
    private var updateTimer: Timer?
    
    init() {
        // Sync with the AppDelegate's enhanced connection manager
        startSyncTimer()
    }
    
    private func startSyncTimer() {
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if let appDelegate = AppDelegate.shared {
                DispatchQueue.main.async {
                    self.isConnected = appDelegate.enhancedConnectionManager.isConnected
                    
                    // Map UIColor to SwiftUI Color
                    switch appDelegate.enhancedConnectionManager.connectionQuality {
                    case .excellent:
                        self.connectionQuality = .excellent
                    case .good:
                        self.connectionQuality = .good
                    case .poor:
                        self.connectionQuality = .poor
                    case .unknown:
                        self.connectionQuality = .unknown
                    }
                }
            }
        }
    }
    
    func sendReliableMessage(_ message: [String: Any]) {
        AppDelegate.shared?.enhancedConnectionManager.sendReliableMessage(message)
    }
    
    deinit {
        updateTimer?.invalidate()
    }
}
