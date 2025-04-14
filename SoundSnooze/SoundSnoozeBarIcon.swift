import SwiftUI

struct SoundSnoozeBarIcon: View {
    var isMuted: Bool
    var body: some View {
        ZStack {
            Circle()
                .fill(isMuted ? Color.red.opacity(0.18) : Color.accentColor.opacity(0.15))
                .frame(width: 18, height: 18)
            Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 13, height: 13)
                .foregroundColor(isMuted ? .red : .accentColor)
        }
    }
}
