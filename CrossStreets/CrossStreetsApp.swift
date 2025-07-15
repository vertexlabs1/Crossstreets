import SwiftUI
import Network

@main
struct CrossStreetsApp: App {
    @State private var showSplash = true
    @State private var isOnline = true
    @State private var showOfflineAlert = false
    
    // Network monitor
    private let networkMonitor = NWPathMonitor()
    private let networkQueue = DispatchQueue(label: "NetworkMonitor")
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
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
                
                // Offline indicator
                if !isOnline && !showSplash {
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
        }
    }
    
    private func startNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { path in
            DispatchQueue.main.async {
                let wasOnline = self.isOnline
                self.isOnline = path.status == .satisfied
                
                // Show offline alert when connection is lost
                if wasOnline && !self.isOnline {
                    self.showOfflineAlert = true
                    
                    // Auto-hide after 3 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                        self.showOfflineAlert = false
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
