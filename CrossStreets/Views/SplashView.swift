import SwiftUI

struct SplashView: View {
    @State private var animateText = false
    @State private var animateSubtext = false
    @State private var animateCredit = false
    @State private var carOffset: CGFloat = -100
    @State private var showCircle = false
    
    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.8)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack {
                Spacer()
                
                VStack(spacing: 24) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.15))
                            .frame(width: 80, height: 80)
                            .scaleEffect(showCircle ? 1 : 0.5)
                            .opacity(showCircle ? 1 : 0)
                        
                        Image(systemName: "car.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.white)
                            .offset(x: carOffset)
                            .opacity(carOffset > -25 ? 1 : 0)
                    }
                    
                    VStack(spacing: 6) {
                        Text("CROSSSTREETS")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .tracking(2)
                            .opacity(animateText ? 1 : 0)
                            .offset(y: animateText ? 0 : 15)
                        
                        Text("BETA")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white.opacity(0.9))
                            .tracking(1)
                            .opacity(animateText ? 1 : 0)
                            .offset(y: animateText ? 0 : 15)
                        
                        Text("Never lose your car again")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                            .opacity(animateSubtext ? 1 : 0)
                            .offset(y: animateSubtext ? 0 : 8)
                    }
                }
                
                Spacer()
                Spacer()
                
                VStack(spacing: 3) {
                    Text("Built by")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .opacity(animateCredit ? 1 : 0)
                    
                    Text("VertexLabs")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .opacity(animateCredit ? 1 : 0)
                }
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            // Faster, more responsive animations
            withAnimation(.easeOut(duration: 0.3)) {
                showCircle = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeOut(duration: 0.5)) {
                    carOffset = 0
                }
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                withAnimation(.easeOut(duration: 0.6)) {
                    animateText = true
                }
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                withAnimation(.easeOut(duration: 0.6)) {
                    animateSubtext = true
                }
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation(.easeOut(duration: 0.5)) {
                    animateCredit = true
                }
            }
        }
    }
}

#Preview {
    SplashView()
}
