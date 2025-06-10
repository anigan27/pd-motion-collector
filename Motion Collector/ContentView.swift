import SwiftUI
import QuickLook
import UIKit

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
    
    var body: some View {
        NavigationView {

                VStack(spacing: 20) {
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
                        ForEach(sessionManager.files) { file in
                            HStack {
                                Text(file.name)
                                Spacer()
                                Button("View") {
                                    let path = file.url.path
                                    let exists = FileManager.default.fileExists(atPath: path)
                                    if exists {
                                        do {
                                            let data = try Data(contentsOf: file.url)
                                            if data.count > 0 {
                                                // Add a slight delay to ensure file is ready and avoid blank screen bug
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
                    }
                    .frame(maxHeight: 300)
                }
                .navigationTitle("Motion Collector")
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

