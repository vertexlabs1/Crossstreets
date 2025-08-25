import SwiftUI

struct SplashView: View {
    var body: some View {
        ZStack {
            // Use the splash image as background
            Image("SplashImage")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .ignoresSafeArea()
            
            // Optional overlay for additional branding
            VStack {
                Spacer()
                
                VStack(spacing: 8) {
                    Text("CROSSSTREETS")
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
        }
    }
}

#Preview {
    SplashView()
}
