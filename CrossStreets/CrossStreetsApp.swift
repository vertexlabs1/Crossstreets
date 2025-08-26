import SwiftUI
import Network

@main
struct SpotsaverApp: App {
    @State private var showSplash = true
    @State private var isOnline = true
    @State private var showOfflineAlert = false
    @State private var deepLinkDestination: String?
    @State private var networkCheckDelay = false
    
    // Performance monitoring
    private let appLaunchTime = Date()
    
    // Network monitor
    private let networkMonitor = NWPathMonitor()
    private let networkQueue = DispatchQueue(label: "NetworkMonitor")
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                // Main ContentView - always present, never recreated
                ContentView(deepLinkDestination: $deepLinkDestination)
                
                // Splash overlay - always present but animated
                SplashView()
                    .opacity(showSplash ? 1 : 0)
                    .animation(.easeInOut(duration: 1.2), value: showSplash)
                    .zIndex(1)
                    .onAppear {
                        print("🎬 Splash screen appeared, will dismiss in 2 seconds")
                        print("⏰ Scheduling splash dismissal timer...")
                        // Start fade out after 2 seconds
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            print("⏰ Splash screen timer fired, dismissing...")
                            withAnimation(.easeInOut(duration: 1.2)) {
                                showSplash = false
                                print("✅ Splash screen dismissed (showSplash = false)")
                            }
                        }
                        print("⏰ Splash dismissal timer scheduled successfully")
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
                print("🏠 App onAppear - showSplash: \(showSplash)")
                startNetworkMonitoring()
                trackAppLaunch()
                
                // Test Supabase connection
                SupabaseManager.shared.testSupabaseConnection { success in
                    if success {
                        print("✅ Supabase: Connection verified")
                    } else {
                        print("❌ Supabase: Connection failed - check tables and API key")
                    }
                }
                
                // Fallback splash screen dismissal in case onAppear doesn't fire
                print("🔄 Scheduling fallback splash dismissal...")
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    print("🔄 Fallback timer fired, showSplash: \(showSplash)")
                    if showSplash {
                        print("🔄 Fallback splash dismissal triggered")
                        withAnimation(.easeInOut(duration: 1.2)) {
                            showSplash = false
                            print("✅ Fallback splash screen dismissed")
                        }
                    } else {
                        print("🔄 Fallback not needed - splash already dismissed")
                    }
                }
                print("🔄 Fallback splash dismissal scheduled successfully")
            }
            .onDisappear {
                stopNetworkMonitoring()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                print("🔄 App will enter foreground - location refresh will be handled by ContentView")
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                print("🔄 App did become active - location services will be refreshed by ContentView")
            }
            .onOpenURL { url in
                handleDeepLink(url: url)
            }
        }
    }
    
    private func handleDeepLink(url: URL) {
        guard url.scheme == "spotsaver" else { return }
        
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
                self.isOnline = path.status == .satisfied
                
                // Only log if status actually changed
                if wasOnline != self.isOnline {
                    print("🌐 Network status: \(self.isOnline ? "Online" : "Offline")")
                    
                    // Update shared managers
                    SupabaseManager.shared.isOnline = self.isOnline
                    
                    // Auto-sync queued data when coming back online
                    if self.isOnline && !wasOnline {
                        print("🔄 Auto-syncing queued data...")
                        SupabaseManager.shared.syncQueuedData()
                    }
                }
            }
        }
        networkMonitor.start(queue: networkQueue)
        
        // Reduce delay for better responsiveness
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.networkCheckDelay = true
        }
    }
    
    private func stopNetworkMonitoring() {
        networkMonitor.cancel()
    }
    
    private func trackAppLaunch() {
        let launchDuration = Date().timeIntervalSince(appLaunchTime)
        PerformanceMonitor.shared.logAppLaunchTime(launchDuration)
        
        // Log user action for app launch
        SupabaseManager.shared.logUserAction(
            action: "app_launch",
            screen: "splash",
            success: true,
            duration: launchDuration,
            context: ["splash_duration": 2.0]
        ) { _ in }
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
