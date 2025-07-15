import SwiftUI
import Network

@main
struct CrossStreetsApp: App {
    @State private var showSplash = true
    @State private var isOnline = true
    @State private var showOfflineAlert = false
    @State private var deepLinkDestination: String?
    @State private var networkCheckDelay = false
    
    // Network monitor
    private let networkMonitor = NWPathMonitor()
    private let networkQueue = DispatchQueue(label: "NetworkMonitor")
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView(deepLinkDestination: $deepLinkDestination)
                    .opacity(showSplash ? 0 : 1)
                    .animation(.easeIn(duration: 0.5), value: showSplash)
                    .environment(\.isOnline, isOnline)
                
                if showSplash {
                    SplashView()
                        .transition(.opacity.combined(with: .scale(scale: 1.1)))
                        .zIndex(1)
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                withAnimation(.easeOut(duration: 0.8)) {
                                    showSplash = false
                                }
                            }
                        }
                }
                
                // Offline indicator - only show after delay and when actually offline
                if !isOnline && !showSplash && networkCheckDelay {
                    VStack {
                        HStack {
                            Image(systemName: "wifi.slash")
                                .foregroundColor(.white)
                            Text("Offline Mode")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(Color.red.opacity(0.8))
                        )
                        .padding(.top, 8)
                        
                        Spacer()
                    }
                    .zIndex(2)
                }
            }
            .onAppear {
                startNetworkMonitoring()
            }
            .onDisappear {
                stopNetworkMonitoring()
            }
            .onOpenURL { url in
                handleDeepLink(url: url)
            }
        }
    }
    
    private func handleDeepLink(url: URL) {
        guard url.scheme == "crossstreets" else { return }
        
        // Handle widget deep link
        if url.host == nil || url.host == "" {
            // Widget tapped - show main parking view
            deepLinkDestination = "parking"
        }
    }
    
    private func startNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { path in
            DispatchQueue.main.async {
                let wasOnline = self.isOnline
                let newOnlineStatus = path.status == .satisfied
                
                // Only update if status actually changed
                if self.isOnline != newOnlineStatus {
                    self.isOnline = newOnlineStatus
                    
                    // Add delay before showing offline indicator to prevent false positives
                    if !newOnlineStatus {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            if !self.isOnline {
                                self.networkCheckDelay = true
                            }
                        }
                    } else {
                        // Immediately hide offline indicator when back online
                        self.networkCheckDelay = false
                    }
                    
                    // Show offline alert when connection is lost
                    if wasOnline && !newOnlineStatus {
                        self.showOfflineAlert = true
                        
                        // Auto-hide after 3 seconds
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                            self.showOfflineAlert = false
                        }
                    }
                }
            }
        }
        networkMonitor.start(queue: networkQueue)
    }
    
    private func stopNetworkMonitoring() {
        networkMonitor.cancel()
    }
}

// Environment key for online status
private struct IsOnlineKey: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {
    var isOnline: Bool {
        get { self[IsOnlineKey.self] }
        set { self[IsOnlineKey.self] = newValue }
    }
}
