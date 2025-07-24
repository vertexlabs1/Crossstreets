import SwiftUI
import CoreLocation

struct LogIssueView: View {
    @ObservedObject var locationManager: LocationManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var notes: String = ""
    @State private var selectedIssueType: String = "general_issue"
    @State private var isSubmitting = false
    @State private var showSuccess = false
    @FocusState private var notesFieldFocused: Bool
    @State private var keyboardVisible: Bool = false
    
    let issueTypes = [
        ("general_issue", "General Issue"),
        ("floor_correction", "Floor Detection Issue"),
        ("feature_request", "Feature Request"),
        ("bug_report", "Bug Report"),
        ("improvement", "Improvement Suggestion")
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
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
                            .frame(minHeight: 120, maxHeight: 180)
                            .frame(maxWidth: .infinity)
                            .padding(8)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                            .focused($notesFieldFocused)
                            .toolbar {
                                ToolbarItemGroup(placement: .keyboard) {
                                    Spacer()
                                    Button("Done") { notesFieldFocused = false }
                                }
                            }
                    }
                    
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
                        .padding(.vertical, 14)
                        .background(notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray : Color.blue)
                        .cornerRadius(12)
                    }
                    .disabled(notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting)
                    .padding(.bottom, 8)
                }
                .padding(.horizontal)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .background(Color(.systemBackground))
            .overlay(
                // Success overlay
                Group {
                    if showSuccess {
                        VStack(spacing: 16) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.green)
                            
                            Text("Thank You!")
                                .font(.title2)
                                .fontWeight(.semibold)
                            
                            Text("Your feedback has been submitted successfully.")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(32)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color(.systemBackground))
                                .shadow(radius: 10)
                        )
                        .transition(.scale.combined(with: .opacity))
                    }
                }
            )
            .onTapGesture {
                notesFieldFocused = false
            }
            .navigationTitle("Log Issue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .interactiveDismissDisabled(notesFieldFocused || !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }
    
    private func getCurrentAddress() -> String? {
        guard let currentLocation = locationManager.currentLocation else {
            return nil
        }
        
        // Return a simple address format without blocking the main thread
        return String(format: "%.4f, %.4f", currentLocation.coordinate.latitude, currentLocation.coordinate.longitude)
    }
    
    private func submitIssue() {
        guard !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        // Start performance monitoring
        PerformanceMonitor.shared.startAction("submit_issue")
        
        HapticManager.mediumImpact()
        isSubmitting = true
        
        // Don't block the UI with geocoding - just submit the issue
        locationManager.logUserIssue(notes: notes.trimmingCharacters(in: .whitespacesAndNewlines), issueType: selectedIssueType)
        
        // End performance monitoring
        PerformanceMonitor.shared.endAction("submit_issue", screen: "log_issue", success: true, context: ["issue_type": selectedIssueType])
        
        // Show success state immediately
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isSubmitting = false
            showSuccess = true
            
            // Show success feedback
            HapticManager.lightImpact()
            
            // Dismiss after showing success
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                dismiss()
            }
        }
    }
} 