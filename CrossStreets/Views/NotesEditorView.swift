import SwiftUI

struct NotesEditorView: View {
    @Binding var showingNotesEditor: Bool
    @Binding var showingFloorPicker: Bool
    @Binding var detectedGarageName: String?
    @ObservedObject var locationManager: LocationManager
    @State private var notesText: String = ""
    @State private var showingFloorOption: Bool = false
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    showingNotesEditor = false
                }
            
            VStack {
                Spacer()
                
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "note.text")
                            .font(.system(size: 40))
                            .foregroundColor(.blue)
                        
                        Text("Add Parking Notes")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Add any details about your parking spot")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    // Notes Text Field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                        
                        TextField("e.g., Near elevator, Blue car, Level 2", text: $notesText, axis: .vertical)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .lineLimit(3...6)
                            .foregroundColor(.primary)
                    }
                    
                    // Floor Option (only show if no floor info exists)
                    if locationManager.parkedLocation?.floor == nil {
                        VStack(spacing: 12) {
                            Divider()
                            
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Add Floor Information")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.primary)
                                    
                                    Text("Optional: Add floor details if you're in a garage")
                                        .font(.system(size: 14))
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Button(action: {
                                    HapticManager.lightImpact()
                                    detectedGarageName = locationManager.parkedLocation?.garageName ?? "Custom Location"
                                    showingNotesEditor = false
                                    withAnimation {
                                        showingFloorPicker = true
                                    }
                                }) {
                                    Text("Add Floor")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.blue)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(Color.blue.opacity(0.1))
                                        .cornerRadius(8)
                                }
                            }
                        }
                    }
                    
                    // Action Buttons
                    HStack(spacing: 12) {
                        Button(action: {
                            HapticManager.lightImpact()
                            showingNotesEditor = false
                        }) {
                            Text("Cancel")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(14)
                        }
                        
                        Button(action: {
                            HapticManager.mediumImpact()
                            locationManager.updateNotes(notesText.isEmpty ? nil : notesText)
                            showingNotesEditor = false
                        }) {
                            Text("Save Notes")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(Color.blue)
                                        .shadow(color: .blue.opacity(0.3), radius: 8, y: 4)
                                )
                        }
                    }
                }
                .padding(28)
                .padding(.horizontal, 8)
                .background(
                    RoundedRectangle(cornerRadius: 28)
                        .fill(Color(.systemBackground))
                        .shadow(color: .black.opacity(0.25), radius: 40, y: -15)
                )
            }
        }
        .onAppear {
            // Load existing notes
            notesText = locationManager.parkedLocation?.notes ?? ""
        }
    }
} 