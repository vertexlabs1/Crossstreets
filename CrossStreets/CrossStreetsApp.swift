import SwiftUI

@main
struct CrossStreetsApp: App {
    @State private var showSplash = true
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                    .opacity(showSplash ? 0 : 1)
                    .animation(.easeIn(duration: 0.5), value: showSplash)
                
                if showSplash {
                    SplashView()
                        .transition(.opacity.combined(with: .scale(scale: 1.1)))
                        .zIndex(1)
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                                withAnimation(.easeOut(duration: 0.8)) {
                                    showSplash = false
                                }
                            }
                        }
                }
            }
        }
    }
}
