import SwiftUI

struct ExportDataView: View {
    @ObservedObject var locationManager: LocationManager
    @Environment(\.dismiss) private var dismiss
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 40))
                        .foregroundColor(.blue)
                    
                    Text("Export Feedback Data")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Share your feedback data to help improve CrossStreets.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top)
                
                // Data Summary
                VStack(spacing: 12) {
                    let stats = locationManager.getCorrectionStats()
                    
                    HStack {
                        VStack {
                            Text("\(stats.totalGarages)")
                                .font(.title2)
                                .fontWeight(.bold)
                            Text("Garages")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        
                        Divider()
                        
                        VStack {
                            Text("\(stats.totalCorrections)")
                                .font(.title2)
                                .fontWeight(.bold)
                            Text("Corrections")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        
                        Divider()
                        
                        VStack {
                            Text("\(locationManager.getUserIssuesCount())")
                                .font(.title2)
                                .fontWeight(.bold)
                            Text("Issues")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
                }
                
                // Export Button
                Button(action: exportData) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 16))
                        Text("Export Data")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .cornerRadius(10)
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Export Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .alert("Export Error", isPresented: $showErrorAlert) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func exportData() {
        print("🔄 Starting export process...")
        HapticManager.lightImpact()
        
        // Generate export data
        let exportData = locationManager.exportCorrectionData()
        print("📊 Generated export data: \(exportData.count) characters")
        
        // Create a temporary file with a unique name
        let timestamp = Int(Date().timeIntervalSince1970)
        let filename = "CrossStreets_Feedback_\(timestamp).txt"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        
        print("📁 Creating file at: \(tempURL)")
        
        do {
            // Write data to file
            try exportData.write(to: tempURL, atomically: true, encoding: .utf8)
            print("✅ Successfully wrote data to file")
            
            // Verify file exists and has content
            let fileAttributes = try FileManager.default.attributesOfItem(atPath: tempURL.path)
            let fileSize = fileAttributes[.size] as? Int64 ?? 0
            print("📏 File size: \(fileSize) bytes")
            
            // Present share sheet
            let activityVC = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
            
            // Configure for iPad
            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = UIApplication.shared.windows.first?.rootViewController?.view
                popover.sourceRect = CGRect(x: UIScreen.main.bounds.width / 2, y: UIScreen.main.bounds.height / 2, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
            
            // Present the share sheet
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let rootViewController = window.rootViewController {
                
                // Find the topmost view controller
                var topController = rootViewController
                while let presentedController = topController.presentedViewController {
                    topController = presentedController
                }
                
                print("📱 Presenting share sheet from: \(type(of: topController))")
                topController.present(activityVC, animated: true) {
                    print("✅ Share sheet presented successfully")
                }
            } else {
                print("❌ Could not find root view controller")
                errorMessage = "Could not present share sheet. Please try again."
                showErrorAlert = true
            }
            
        } catch {
            print("❌ Error exporting data: \(error)")
            errorMessage = "Failed to create export file: \(error.localizedDescription)"
            showErrorAlert = true
        }
    }
} 