import SwiftUI

struct SplashView: View {
    @State private var fadeIn = false
    @State private var fadeOut = false
    @State private var scale = 1.0
    
    var body: some View {
        ZStack {
            // Use the splash image as background
            Image("SplashImage")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .ignoresSafeArea()
                .scaleEffect(scale)
            
            // Optional overlay for additional branding
            VStack {
                Spacer()
                
                VStack(spacing: 8) {
                    Text("CROSSSTREETS")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .tracking(2)
                        .opacity(fadeIn ? 1 : 0)
                        .offset(y: fadeIn ? 0 : 10)
                    
                    Text("BETA")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))
                        .tracking(1)
                        .opacity(fadeIn ? 1 : 0)
                        .offset(y: fadeIn ? 0 : 10)
                }
                .padding(.bottom, 60)
            }
        }
        .opacity(fadeOut ? 0 : 1)
        .onAppear {
            // Fade in animation
            withAnimation(.easeInOut(duration: 0.8)) {
                fadeIn = true
            }
            
            // Subtle scale animation
            withAnimation(.easeInOut(duration: 2.0).delay(0.3)) {
                scale = 1.02
            }
        }
    }
    
    // Function to trigger fade out (called from parent)
    func fadeOutAnimation() {
        withAnimation(.easeInOut(duration: 0.6)) {
            fadeOut = true
            scale = 1.05
        }
    }
}

#Preview {
    SplashView()
}
