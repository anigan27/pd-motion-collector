import SwiftUI
import QuickLook
import UIKit
import WatchConnectivity

// Identifiable wrapper for URL to use with .sheet(item:)
struct IdentifiablePreviewURL: Identifiable, Equatable {
    let id = UUID()
    let url: URL
}

struct ContentView: View {
    @StateObject private var sessionManager = PhoneSessionManager()
    @State private var renamingFile: MotionFile?
    @State private var newName: String = ""
    @State private var showRenameAlert = false
    
    @State private var previewURL: IdentifiablePreviewURL?
    @State private var showFileMissingAlert = false
    @State private var fileAlertMessage = ""
    @State private var showDeleteAlert = false
    @State private var fileToDelete: MotionFile?
    @State private var isSelecting = false
    @State private var selectedIDs = Set<UUID>()
    @State private var showShareSheet = false
    @State private var filesToShare: [URL] = []
    @State private var showBatchDeleteAlert = false
    @State private var selectedTest: TestType = .fingerTapping

    
    var body: some View {
        NavigationView {

                VStack(spacing: 20) {
                    VStack {
                        Picker("Select Test", selection: $selectedTest) {
                            ForEach(TestType.allCases) { test in
                                Text(test.rawValue).tag(test)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .padding(.vertical)
                        
                       
                    }
                    .onChange(of: selectedTest) { newTest in
                        if WCSession.default.isReachable {
                            WCSession.default.sendMessage(
                                ["testType": newTest.fileName, "needsTimer": newTest.needsTimer],
                                replyHandler: nil,
                                errorHandler: nil
                            )
                        }
                    }


                    VStack(alignment: .leading, spacing: 4) {
                            Text("Welcome to Motion Collector!")
                                .font(.title2).bold()
                            Text("• Collect data on your Watch.\n• Files will appear here to view, rename, or delete.\n• For tasks with duration of 10 seconds, toggle on the '10s timer'.")
                                .font(.body)
                                .foregroundColor(.black)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 8)
                        .padding(.leading, 14)
                    
                    List {
                        HStack {
                            if isSelecting {
                                Button("Done") {
                                    isSelecting = false
                                    selectedIDs.removeAll()
                                }
                                .buttonStyle(.borderless)
                                .padding(.leading, 14)
                            } else {
                                Button("Select") {
                                    isSelecting = true
                                }
                                .buttonStyle(.borderless)
                                .padding(.leading, 14)
                            }
                            Spacer()
                        }
                        ForEach(sessionManager.files) { file in
                            HStack {
                                // Show checkmark button only in selection mode
                                if isSelecting {
                                    Button(action: {
                                        if selectedIDs.contains(file.id) {
                                            selectedIDs.remove(file.id)
                                        } else {
                                            selectedIDs.insert(file.id)
                                        }
                                    }) {
                                        Image(systemName: selectedIDs.contains(file.id) ? "checkmark.circle.fill" : "circle")
                                            .foregroundColor(.blue)
                                    }
                                    .buttonStyle(.borderless)
                                }

                                Text(file.name)
                                Spacer()

                                // Existing buttons only visible when NOT selecting
                                if !isSelecting {
                                    Button("View") {
                                        let path = file.url.path
                                        let exists = FileManager.default.fileExists(atPath: path)
                                        if exists {
                                            do {
                                                let data = try Data(contentsOf: file.url)
                                                if data.count > 0 {
                                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                                        previewURL = IdentifiablePreviewURL(url: file.url)
                                                    }
                                                } else {
                                                    fileAlertMessage = "File is empty!"
                                                    showFileMissingAlert = true
                                                }
                                            } catch {
                                                fileAlertMessage = "Error reading file: \(error)"
                                                showFileMissingAlert = true
                                            }
                                        } else {
                                            fileAlertMessage = "File does not exist at \(path)"
                                            showFileMissingAlert = true
                                        }
                                    }
                                    .buttonStyle(.borderless)

                                    Button("Rename") {
                                        renamingFile = file
                                        newName = file.name.replacingOccurrences(of: ".csv", with: "")
                                        showRenameAlert = true
                                    }
                                    .buttonStyle(.borderless)
                                    .foregroundColor(.green)

                                    Button(action: {
                                        fileToDelete = file
                                        showDeleteAlert = true
                                    }) {
                                        Text("Delete")
                                            .foregroundColor(.red)
                                    }
                                    .buttonStyle(.borderless)
                                    .accessibilityLabel("Delete file")
                                }
                            }
                            .contentShape(Rectangle()) // make entire row tappable
                            .onTapGesture {
                                if isSelecting {
                                    if selectedIDs.contains(file.id) {
                                        selectedIDs.remove(file.id)
                                    } else {
                                        selectedIDs.insert(file.id)
                                    }
                                }
                            }

                        }
                    }
                    .frame(maxHeight: 300)
                }
                .navigationTitle("Motion Collector")
                .toolbar {
                    
                    ToolbarItemGroup(placement: .navigationBarTrailing) {
                        if isSelecting {
                            Button {
                                let urlsToShare = sessionManager.files.filter { selectedIDs.contains($0.id) }.map { $0.url }
                                presentShareSheet(urls: urlsToShare)
                            } label: {
                                Image(systemName: "square.and.arrow.up")
                            }
                            .disabled(selectedIDs.isEmpty)







                            Button(role: .destructive) {
                                showBatchDeleteAlert = true
                            } label: {
                                Image(systemName: "trash")
                            }
                            .disabled(selectedIDs.isEmpty)
                        }
                    }
                }

                .alert("Delete Selected Files?", isPresented: $showBatchDeleteAlert) {
                    Button("Delete", role: .destructive) {
                        // Perform batch delete here
                        for file in sessionManager.files.filter({ selectedIDs.contains($0.id) }) {
                            sessionManager.delete(file: file)
                        }
                        selectedIDs.removeAll()
                        isSelecting = false  // Optionally exit selection mode after deleting
                    }
                    Button("Cancel", role: .cancel) {
                        // Just dismiss the alert
                        showBatchDeleteAlert = false
                    }
                } message: {
                    Text("Are you sure you want to delete the selected files?")
                }

                .alert("Rename File", isPresented: $showRenameAlert) {
                    TextField("New name", text: $newName)
                    Button("Cancel", role: .cancel) {}
                    Button("OK") {
                        if let file = renamingFile {
                            sessionManager.rename(file: file, to: newName)
                        }
                    }
                }
                .alert("File Error", isPresented: $showFileMissingAlert) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text(fileAlertMessage)
                }
                // Use .sheet(item:) with UINavigationController embedding
               



                .sheet(item: $previewURL, onDismiss: {
                    previewURL = nil
                }) { identifiableURL in
                    QuickLookNavController(url: identifiableURL.url, isPresented: Binding(
                        get: { previewURL != nil },
                        set: { newValue in if !newValue { previewURL = nil } }
                    ))
                }
                .alert("Are you sure you want to delete this file?", isPresented: $showDeleteAlert, presenting: fileToDelete) { file in
                    Button("Delete", role: .destructive) {
                        sessionManager.delete(file: file)
                        fileToDelete = nil
                    }
                    Button("Cancel", role: .cancel) {
                        fileToDelete = nil
                    }
                } message: { file in
                    Text(file.name)
                }
            }
        }
    }
    
    // UIKit wrapper that embeds QLPreviewController in UINavigationController and wires up Done
    struct QuickLookNavController: UIViewControllerRepresentable {
        let url: URL
        @Binding var isPresented: Bool
        
        func makeUIViewController(context: Context) -> UINavigationController {
            let previewController = QLPreviewController()
            previewController.dataSource = context.coordinator
            
            // Add Done button that calls coordinator's dismiss method
            previewController.navigationItem.leftBarButtonItem = UIBarButtonItem(
                barButtonSystemItem: .done,
                target: context.coordinator,
                action: #selector(context.coordinator.dismiss)
            )
            
            let navController = UINavigationController(rootViewController: previewController)
            return navController
        }
        
        func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {}
        
        func makeCoordinator() -> Coordinator {
            Coordinator(self)
        }
        
        class Coordinator: NSObject, QLPreviewControllerDataSource {
            let parent: QuickLookNavController
            
            init(_ parent: QuickLookNavController) {
                self.parent = parent
            }
            
            func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }
            func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
                parent.url as NSURL
            }
            
            @objc func dismiss() {
                // This will dismiss the SwiftUI .sheet
                DispatchQueue.main.async {
                    self.parent.isPresented = false
                }
            }
        }
    } 
import UIKit

func presentShareSheet(urls: [URL]) {
    guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
          let rootVC = windowScene.windows.first?.rootViewController else {
        return
    }

    let activityVC = UIActivityViewController(activityItems: urls, applicationActivities: nil)

    // iPad popover fix
    if let popover = activityVC.popoverPresentationController {
        popover.sourceView = rootVC.view
        popover.sourceRect = CGRect(x: rootVC.view.bounds.midX,
                                    y: rootVC.view.bounds.midY,
                                    width: 0,
                                    height: 0)
        popover.permittedArrowDirections = []
    }

    rootVC.present(activityVC, animated: true, completion: nil)
}
