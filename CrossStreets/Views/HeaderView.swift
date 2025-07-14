import SwiftUI

struct HeaderView: View {
    var body: some View {
        VStack {
            HStack {
                Spacer()
                
                Text("CROSSSTREETS")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .tracking(2)
                    .shadow(color: .black.opacity(0.6), radius: 4, x: 0, y: 2)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 25)
            
            Spacer()
        }
        .frame(height: 50)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.black.opacity(0.4),
                    Color.clear
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}

#Preview {
    HeaderView()
}
