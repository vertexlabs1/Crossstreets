import SwiftUI

struct SplashView: View {
    @State private var animateText = false
    @State private var animateSubtext = false
    @State private var animateCredit = false
    @State private var carOffset: CGFloat = -200
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
                
                VStack(spacing: 30) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.15))
                            .frame(width: 100, height: 100)
                            .scaleEffect(showCircle ? 1 : 0.3)
                            .opacity(showCircle ? 1 : 0)
                        
                        Image(systemName: "car.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.white)
                            .offset(x: carOffset)
                            .opacity(carOffset > -50 ? 1 : 0)
                    }
                    
                    VStack(spacing: 8) {
                        Text("CROSSSTREETS")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .tracking(3)
                            .opacity(animateText ? 1 : 0)
                            .offset(y: animateText ? 0 : 20)
                        
                        Text("Never lose your car again")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                            .opacity(animateSubtext ? 1 : 0)
                            .offset(y: animateSubtext ? 0 : 10)
                    }
                }
                
                Spacer()
                Spacer()
                
                VStack(spacing: 4) {
                    Text("Built by")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .opacity(animateCredit ? 1 : 0)
                    
                    Text("VertexLabs")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .opacity(animateCredit ? 1 : 0)
                }
                .padding(.bottom, 50)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) {
                showCircle = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.easeOut(duration: 0.8)) {
                    carOffset = 0
                }
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                withAnimation(.easeOut(duration: 1.0)) {
                    animateText = true
                }
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                withAnimation(.easeOut(duration: 1.0)) {
                    animateSubtext = true
                }
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation(.easeOut(duration: 0.8)) {
                    animateCredit = true
                }
            }
        }
    }
}

#Preview {
    SplashView()
}
