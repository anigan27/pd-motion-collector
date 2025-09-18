import SwiftUI
import QuickLook
import WatchConnectivity

struct IdentifiableURL: Identifiable { let url: URL; var id: URL { url } }
struct AlertMessage: Identifiable { var id: String { message }; let message: String }

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
                                .padding(.top, 12)
                        }
                        if !showWelcome {
                            if isSessionComplete {
                                SessionCompleteScreen(onRestart: { showRestartConfirm = true })
                                    .frame(maxWidth: 420)
                                    .padding(.vertical, 8)
                                RestartBar(onRestart: { showRestartConfirm = true })
                                    .padding(.bottom, 10)
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
                                DoneTestScreen(test: test, onNext: {
                                    state.idx += 1
                                    if state.idx < allTests.count { state.step = 1 }
                                })
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
                                sendFileResult: $sendFileResult
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
                    ScrollView {
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
            Button("Delete session files and restart", role: .destructive) {
                filesMgr.deleteSessionFiles(sessionFileList: state.filesForSession)
                state.resetSession()
                saveSessionState()
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
        .alert(isPresented: $showDeleteAlert) {
            Alert(title: Text("Delete File?"), message: Text("Are you sure you want to delete this file?"), primaryButton: .destructive(Text("Delete")) {
                // Handle file deletion
            }, secondaryButton: .cancel())
        }
    }
    
    
    struct WelcomeScreen: View {
        @Binding var showWelcome: Bool
        var body: some View {
            VStack(spacing: 38) {
                Spacer()
                Image(systemName: "figure.walk.motion")
                    .font(.system(size: 94)).foregroundColor(.blue)
                Text("Welcome to Motion Collector")
                    .font(.system(size: 34, weight: .heavy))
                    .foregroundColor(.accentColor)
                    .multilineTextAlignment(.center)
                Text("You'll be guided step by step. Every test auto-saves and appears under 'Your Results'.")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                Button(action: { showWelcome = false }) {
                    Text("Get Started")
                        .font(.title2.bold())
                        .padding(.vertical, 16)
                        .padding(.horizontal, 58)
                        .background(Capsule().fill(Color.accentColor))
                        .foregroundColor(.white)
                }
                Spacer()
            }
            .background(Color(.systemBackground).edgesIgnoringSafeArea(.all))
        }
    }
    
    struct RestartBar: View {
        let onRestart: () -> Void
        var body: some View {
            HStack {
                Spacer()
                Button(action: onRestart) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.title2)
                        .foregroundColor(.blue)
                    Text("Restart Session")
                        .font(.title3.bold())
                        .foregroundColor(.accentColor)
                }
                Spacer()
            }
            .padding(.top, 18)
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
                    }
                }
                Section(header:
                            Text("Untimed Tests").font(.title2.weight(.bold)).foregroundColor(.accentColor).frame(maxWidth:.infinity, alignment:.center)
                    .padding(.top, 14)
                ) {
                    ForEach(Array(untimedTests.enumerated()), id: \.offset) { j, test in
                        // Use the index in allTests, not just untimedTests
                        let mainIdx = ContentView.allTests.firstIndex(of: test) ?? (j + timedTests.count)
                        TestCard(
                            test: test,
                            isComplete: testIsComplete(mainIdx),
                            selected: mainIdx == nextTestIndex,
                            onStart: {
                                sendWatchTestCommand("wait", test)
                                state.idx = mainIdx; state.step = 2
                            }
                        )
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
        var body: some View {
            VStack(spacing: 12) {
                Image(systemName:"rectangle.and.pencil.and.ellipsis")
                    .font(.system(size:42))
                    .foregroundColor(selected ? .accentColor : (isComplete ? .green : .blue))
                    .padding(.top,6)
                Text(test.rawValue)
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
        var body: some View {
            VStack(spacing:33) {
                Spacer()
                Text("Collecting Data").font(.title.bold()).foregroundColor(.accentColor)
                Image(systemName:"clock.arrow.circlepath").font(.system(size:66)).foregroundColor(.accentColor)
                Text(test.rawValue).font(.title2.bold()).foregroundColor(.accentColor)
                Text("Time left: \(timeLeft)s").font(.largeTitle.bold())
                ProgressView(value:Double(10-timeLeft),total:10).progressViewStyle(LinearProgressViewStyle(tint:.accentColor)).scaleEffect(y:1.3).padding(.horizontal,60)
                Spacer()
                Button("Stop Early") {
                    collecting = false
                    sendWatchTestCommand("stop", test)
                    onDone()
                }
                .font(.title3.bold()).foregroundColor(.red)
                Spacer()
            }
            .onAppear {
                Timer.scheduledTimer(withTimeInterval:1,repeats:true){t in
                    timeLeft -= 1
                    if timeLeft <= 0 || !collecting {
                        t.invalidate()
                        sendWatchTestCommand("stop", test)
                        onDone()
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
        var body: some View {
            VStack(spacing:37){
                Spacer()
                Text("Manual Data Collection").font(.title.bold()).foregroundColor(.accentColor)
                Image(systemName:"stopwatch.fill").font(.system(size:64)).foregroundColor(.accentColor)
                Text(test.rawValue).font(.title2.bold()).foregroundColor(.accentColor)
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
        var body: some View {
            VStack(spacing:32){
                Spacer()
                Image(systemName:"checkmark.seal.fill").font(.system(size:76)).foregroundColor(.green)
                Text("Test Complete!").font(.title.bold())
                    .foregroundColor(.accentColor)
                Text("Press Next to continue. Your CSV file for this test is in Recent Files.").font(.title3).multilineTextAlignment(.center).fixedSize(horizontal:false,vertical:true).padding(.horizontal,26)
                Button("Next Test", action: onNext)
                    .font(.title2.bold()).padding(.vertical,12).padding(.horizontal,48).background(Capsule().fill(Color.green)).foregroundColor(.white)
                Spacer()
            }
        }
    }
    
    struct SessionCompleteScreen: View {
        let onRestart: () -> Void
        var body: some View {
            VStack(spacing:36){
                Spacer()
                Image(systemName:"checkmark.circle.fill").font(.system(size:90)).foregroundColor(.green)
                Text("Session Complete!").font(.system(size:34).bold()).foregroundColor(.accentColor)
                Text("Every test is finished and your data is saved.").font(.title2).multilineTextAlignment(.center).fixedSize(horizontal:false,vertical:true).padding(.horizontal,28)
                Button("Restart Session", action: onRestart)
                    .font(.title2.bold()).foregroundColor(.white).padding(.vertical,15).padding(.horizontal,62).background(Capsule().fill(Color.accentColor))
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
                        ForEach(filesMgr.files.filter { $0.lastPathComponent.lowercased() != "inbox" }.prefix(20), id: \.self) { url in
                            HStack(spacing: 12) {
                                Text(url.lastPathComponent)
                                    .font(.callout)
                                    .foregroundColor(.primary)
                                    .lineLimit(nil)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .frame(maxWidth: 150, alignment: .leading)
                                Text(ContentView.formattedFileSize(for: url))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .frame(minWidth: 50, alignment: .trailing)
                                Spacer()
                                Button(action: {
                                    fileToPreview = url
                                    showFilePreview = true
                                }) {
                                    Image(systemName: "doc.text.magnifyingglass")
                                        .foregroundColor(.blue)
                                        .frame(width: 32, height: 32)
                                        .background(Circle().fill(Color(.systemGray5)))
                                }
                                .buttonStyle(PlainButtonStyle())
                                Button(action: {
                                    if FileManager.default.fileExists(atPath: url.path) {
                                        fileToShare = url
                                        showFileShare = true
                                    } else {
                                        // Optionally, show an error or alert if file doesn't exist
                                    }
                                }) {
                                    Image(systemName: "square.and.arrow.up")
                                        .foregroundColor(.green)
                                        .frame(width: 32, height: 32)
                                        .background(Circle().fill(Color(.systemGray5)))
                                }
                                .buttonStyle(PlainButtonStyle())
                                Button(action: {
                                    // Ensure state change so alert triggers reliably
                                    fileToDelete = nil
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                        if FileManager.default.fileExists(atPath: url.path) {
                                            fileToDelete = IdentifiableURL(url: url)
                                        } else {
                                            sendFileResult = AlertMessage(message: "File does not exist or was already deleted.")
                                        }
                                    }
                                }) {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                        .frame(width: 32, height: 32)
                                        .background(Circle().fill(Color(.systemGray6)))
                                }
                                .buttonStyle(PlainButtonStyle())
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
                }
            }.padding(.vertical, 12).padding(.horizontal, 17)
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
            "sessionID": state.sessionID
        ]
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(message, replyHandler: nil, errorHandler: nil)
        } else {
            print("[MotionCollector] Watch is not reachable. Command not sent: \(message)")
            let notification = AlertMessage(message: "Apple Watch is not reachable. Please check your connection.")
            sendFileResult = notification
        }
    }
    
    func shortenFileName(_ name: String) -> String {
        name.replacingOccurrences(of: "_", with: " ").split(separator: " ").prefix(3).joined(separator: " ")
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
}
