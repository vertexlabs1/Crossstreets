import SwiftUI

struct LogIssueView: View {
    @ObservedObject var locationManager: LocationManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var notes: String = ""
    @State private var selectedIssueType: String = "general_issue"
    @State private var isSubmitting = false
    
    let issueTypes = [
        ("general_issue", "General Issue"),
        ("floor_correction", "Floor Detection Issue"),
        ("feature_request", "Feature Request"),
        ("bug_report", "Bug Report"),
        ("improvement", "Improvement Suggestion")
    ]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.orange)
                    
                    Text("Log an Issue or Update")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Help us improve CrossStreets by reporting issues or suggesting improvements.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top)
                
                // Current Location Info
                if let location = locationManager.currentLocation {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "location.fill")
                                .foregroundColor(.blue)
                            Text("Current Location")
                                .font(.headline)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Coordinates: \(location.coordinate.latitude, specifier: "%.5f"), \(location.coordinate.longitude, specifier: "%.5f")")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            if let address = getCurrentAddress() {
                                Text("Address: \(address)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
                }
                
                // Issue Type Selection
                VStack(alignment: .leading, spacing: 8) {
                    Text("Issue Type")
                        .font(.headline)
                    
                    Picker("Issue Type", selection: $selectedIssueType) {
                        ForEach(issueTypes, id: \.0) { type in
                            Text(type.1).tag(type.0)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                
                // Notes Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Description")
                        .font(.headline)
                    
                    TextEditor(text: $notes)
                        .frame(minHeight: 120)
                        .padding(8)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                }
                
                Spacer()
                
                // Submit Button
                Button(action: submitIssue) {
                    HStack {
                        if isSubmitting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "paperplane.fill")
                        }
                        Text(isSubmitting ? "Submitting..." : "Submit Issue")
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray : Color.blue)
                    .cornerRadius(10)
                }
                .disabled(notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting)
                .padding(.bottom)
            }
            .padding()
            .navigationTitle("Log Issue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func getCurrentAddress() -> String? {
        // This would ideally use the same geocoding as the main app
        // For now, return nil to keep it simple
        return nil
    }
    
    private func submitIssue() {
        guard !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        isSubmitting = true
        
        locationManager.logUserIssue(notes: notes.trimmingCharacters(in: .whitespacesAndNewlines), issueType: selectedIssueType)
        
        // Simulate network delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            isSubmitting = false
            dismiss()
        }
    }
} 