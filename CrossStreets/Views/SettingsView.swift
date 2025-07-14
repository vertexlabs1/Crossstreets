import SwiftUI

struct SettingsView: View {
    @ObservedObject var locationManager: LocationManager
    @Binding var selectedTab: Int
    
    var body: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2.5)
                .fill(Color.gray.opacity(0.15))
                .frame(width: 32, height: 4)
                .padding(.top, 6)
                .padding(.bottom, 14)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("SETTINGS")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                        .tracking(0.5)
                        .padding(.horizontal, 4)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("PARKING DETECTION")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)
                            .tracking(0.5)
                        
                        VStack(spacing: 12) {
                            SettingsRow(
                                icon: "building.fill",
                                title: "Garage Detection",
                                subtitle: "Automatically detects parking garages and structures",
                                iconColor: .purple
                            )
                            
                            SettingsRow(
                                icon: "location.circle.fill",
                                title: "Street Parking",
                                subtitle: "Smart outdoor parking with offline address caching",
                                iconColor: .green
                            )
                            
                            SettingsRow(
                                icon: "list.number",
                                title: "Floor Selection",
                                subtitle: "Choose your parking floor in multi-level garages",
                                iconColor: .orange
                            )
                        }
                        
                        Button(action: locationManager.enableTestMode) {
                            HStack {
                                Image(systemName: "testtube.2")
                                    .font(.system(size: 16))
                                Text("Test Garage Detection")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.purple)
                            .cornerRadius(10)
                        }
                        .padding(.top, 8)
                        
                        if locationManager.testModeEnabled {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Test mode enabled - Park Here will simulate garage detection")
                                    .font(.system(size: 13))
                                    .foregroundColor(.green)
                            }
                            .padding(.top, 4)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "externaldrive.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(.blue)
                                Text("Offline Cache: \(locationManager.cacheCount) locations saved")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.top, 12)
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("PERMISSIONS")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)
                            .tracking(0.5)
                        
                        VStack(spacing: 12) {
                            SettingsRow(
                                icon: "location.circle.fill",
                                title: "Location Services",
                                subtitle: "Required for parking detection and navigation",
                                iconColor: .green,
                                isActionable: true,
                                action: openLocationSettings
                            )
                            
                            SettingsRow(
                                icon: "bell.circle.fill",
                                title: "Notifications",
                                subtitle: "Allow parking notifications and alerts",
                                iconColor: .red,
                                isActionable: true,
                                action: openNotificationSettings
                            )
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("WIDGET")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)
                            .tracking(0.5)
                        
                        VStack(spacing: 12) {
                            SettingsRow(
                                icon: "rectangle.3.group.fill",
                                title: "Add Widget",
                                subtitle: "Long press home screen → Add Widget → CrossStreets",
                                iconColor: .blue,
                                isActionable: true,
                                action: showWidgetInstructions
                            )
                            
                            SettingsRow(
                                icon: "location.circle.fill",
                                title: "Widget Features",
                                subtitle: "Shows parking location, garage, floor, and time",
                                iconColor: .green
                            )
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("ABOUT")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)
                            .tracking(0.5)
                        
                        VStack(spacing: 12) {
                            SettingsRow(
                                icon: "map.circle.fill",
                                title: "Smart Detection",
                                subtitle: "AI-powered garage and street parking recognition",
                                iconColor: .purple
                            )
                            
                            SettingsRow(
                                icon: "wifi.slash",
                                title: "Offline Mode",
                                subtitle: "Works without internet - caches addresses locally",
                                iconColor: .orange
                            )
                            
                            SettingsRow(
                                icon: "iphone.circle.fill",
                                title: "CrossStreets v1.0",
                                subtitle: "Never lose your car again",
                                iconColor: .blue
                            )
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("SUPPORT")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)
                            .tracking(0.5)
                        
                        VStack(spacing: 12) {
                            Button(action: openVertexLabsWebsite) {
                                HStack(spacing: 12) {
                                    Image(systemName: "link.circle.fill")
                                        .font(.system(size: 18))
                                        .foregroundColor(.blue)
                                        .frame(width: 24, height: 24)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Built by VertexLabs")
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(.blue)
                                        
                                        Text("Visit our website to see more apps")
                                            .font(.system(size: 13))
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "arrow.up.right")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.blue)
                                }
                                .padding(12)
                                .background(RoundedRectangle(cornerRadius: 8).fill(Color(.systemGray6)))
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Free app, consider supporting the dev team")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.primary)
                                
                                Button(action: openBuyMeACoffee) {
                                    HStack {
                                        Image(systemName: "cup.and.saucer.fill")
                                            .font(.system(size: 16))
                                        Text("Buy me a coffee")
                                            .font(.system(size: 16, weight: .semibold))
                                    }
                                    .foregroundColor(.black)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color(red: 1.0, green: 0.87, blue: 0.0))
                                    .cornerRadius(8)
                                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.black, lineWidth: 1))
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            .padding(12)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color(.systemGray6)))
                        }
                    }
                    
                    VStack(spacing: 8) {
                        HStack {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary.opacity(0.5))
                            Text("Swipe down to return to parking")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary.opacity(0.7))
                            Image(systemName: "arrow.up")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary.opacity(0.5))
                        }
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
    }
    
    private func openVertexLabsWebsite() {
        if let url = URL(string: "https://www.vxlabs.co/apps") {
            UIApplication.shared.open(url)
        }
    }
    
    private func showWidgetInstructions() {
        let alert = UIAlertController(
            title: "Add CrossStreets Widget",
            message: "1. Long press on your home screen\n2. Tap the '+' button\n3. Search for 'CrossStreets'\n4. Choose widget size and add",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(alert, animated: true)
        }
    }
    
    private func openBuyMeACoffee() {
        if let url = URL(string: "https://www.buymeacoffee.com/tyler2") {
            UIApplication.shared.open(url)
        }
    }
    
    private func openLocationSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
    
    private func openNotificationSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

#Preview {
    SettingsView(locationManager: LocationManager(), selectedTab: .constant(2))
}
