import SwiftUI
import os.log

/// A visual icon that animates to indicate mute status
struct AnimatedMuteIcon: View {
    // MARK: - Properties
    var isMuted: Bool
    @State private var animatePulse = false
    
    // Reduce logging overhead with static logger
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.taylorlabs.SoundSnooze", category: "AnimatedMuteIcon")
    
    // MARK: - Animation Constants
    private struct AnimationConstants {
        static let pulseScale: CGFloat = 1.18
        static let defaultScale: CGFloat = 1.0
        static let pulseDuration: Double = 0.7
        static let iconSize: CGFloat = 40
        static let circleSize: CGFloat = 54
        static let blurRadius: CGFloat = 1
    }
    
    var body: some View {
        ZStack {
            // Background circle with gradient
            Circle()
                .fill(LinearGradient(
                    gradient: Gradient(colors: [Color.accentColor.opacity(0.18), Color.clear]),
                    startPoint: .top,
                    endPoint: .bottom
                ))
                .frame(width: AnimationConstants.circleSize, height: AnimationConstants.circleSize)
                .blur(radius: AnimationConstants.blurRadius)
            
            // Icon with animation
            Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: AnimationConstants.iconSize, height: AnimationConstants.iconSize)
                .foregroundColor(isMuted ? .red : .accentColor)
                .shadow(color: isMuted ? Color.red.opacity(0.2) : Color.accentColor.opacity(0.4), radius: 7, x: 0, y: 2)
                .scaleEffect(animatePulse && isMuted ? AnimationConstants.pulseScale : AnimationConstants.defaultScale)
                .animation(
                    isMuted ? 
                        .easeInOut(duration: AnimationConstants.pulseDuration)
                        .repeatForever(autoreverses: true) : 
                        .default,
                    value: animatePulse
                )
        }
        .frame(width: AnimationConstants.circleSize, height: AnimationConstants.circleSize)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isMuted ? "Sound is muted" : "Sound is on")
        .accessibilityAddTraits(isMuted ? .updatesFrequently : [])
        .onAppear {
            if isMuted { 
                Self.logger.debug("Starting pulse animation")
                animatePulse = true 
            }
        }
        .onChange(of: isMuted) { newValue, _ in
            Self.logger.debug("Mute state changed to: \(newValue)")
            animatePulse = newValue
        }
    }
}
