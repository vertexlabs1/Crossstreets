import SwiftUI

struct SplashView: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Use a solid background color that matches the splash image
                Color.blue
                    .ignoresSafeArea()
                
                // Use the splash image with proper scaling
                Image("SplashImage")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: geometry.size.width, maxHeight: geometry.size.height)
                    .clipped()
                
                // Overlay text positioned properly within safe area
                VStack {
                    Spacer()
                    
                    VStack(spacing: 8) {
                        Text("SPOTSAVER")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .tracking(2)
                        
                        Text("BETA")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.white.opacity(0.9))
                            .tracking(1)
                    }
                    .padding(.bottom, 60)
                }
                .padding(.horizontal, 20)
            }
        }
    }
}

#Preview {
    SplashView()
}
