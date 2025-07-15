import SwiftUI

struct ExportDataView: View {
    @ObservedObject var locationManager: LocationManager
    @Environment(\.dismiss) private var dismiss
    
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
    }
    
    private func exportData() {
        HapticManager.lightImpact()
        let exportData = locationManager.exportCorrectionData()
        
        // Create a temporary file
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("CrossStreets_Feedback_\(Date().timeIntervalSince1970).txt")
        
        do {
            try exportData.write(to: tempURL, atomically: true, encoding: .utf8)
            
            // Present share sheet
            let activityVC = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first {
                window.rootViewController?.present(activityVC, animated: true)
            }
        } catch {
            print("Error exporting data: \(error)")
        }
    }
} 