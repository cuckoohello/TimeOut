import SwiftUI

struct OverlayView: View {
    @ObservedObject var manager: BreakManager

    var body: some View {
        ZStack {
            // Background Dim
            Color.black.opacity(0.8)
                .edgesIgnoringSafeArea(.all)

            VStack(spacing: 40) {
                if case .inBreak(let config) = manager.state {
                    Text(config.name + " Break")
                        .font(.system(size: 60, weight: .bold))
                        .foregroundColor(.white)
                    
                    // Circular Progress
                    ZStack {
                        Circle()
                            .stroke(lineWidth: 20)
                            .opacity(0.3)
                            .foregroundColor(.gray)

                        Circle()
                            .trim(from: 0.0, to: CGFloat(manager.activeBreakProgress))
                            .stroke(style: StrokeStyle(lineWidth: 20, lineCap: .round, lineJoin: .round))
                            .foregroundColor(.green)
                            .rotationEffect(Angle(degrees: 270.0))
                            .animation(.linear, value: manager.activeBreakProgress)
                        
                        Text(manager.timeRemainingFormatted)
                            .font(.system(size: 80, weight: .medium, design: .monospaced))
                            .foregroundColor(.white)
                    }
                    .frame(width: 300, height: 300)

                    HStack(spacing: 50) {
                        Button(action: {
                            manager.postponeBreak(minutes: 5)
                        }) {
                            VStack {
                                Image(systemName: "clock.arrow.circlepath")
                                    .font(.system(size: 30))
                                Text("Postpone 5m")
                            }
                            .padding()
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.white)

                        Button(action: {
                            manager.skipBreak()
                        }) {
                            VStack {
                                Image(systemName: "forward.end.fill")
                                    .font(.system(size: 30))
                                Text("Skip")
                            }
                            .padding()
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.white)
                    }
                }
            }
        }
    }
}
