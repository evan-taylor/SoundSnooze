//
//  ContentView.swift
//  SoundSnooze
//
//  Created by Evan Taylor on 4/14/25.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var manager = MuteManagerObservable.shared
    @State private var showSettings = false

    var body: some View {
        if showSettings {
            ZStack {
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(spacing: 0) {
                        HStack {
                            Button(action: { showSettings = false }) {
                                Image(systemName: "chevron.left")
                                    .imageScale(.large)
                                    .foregroundColor(.accentColor)
                                    .padding(8)
                            }
.buttonStyle(PlainButtonStyle())
                            Text("Settings")
                                .font(.headline)
                            Spacer()
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 12)
                        Divider()
                        SettingsView(showSettings: $showSettings)
                    }
                }
            }
            .frame(width: 320, height: 340)
        } else {
        VStack(spacing: 0) {
            Spacer().frame(height: 8)
            HStack {
                AnimatedMuteIcon(isMuted: manager.isMuted)
                    .padding(.top, 6)
                Spacer()
                Button(action: { showSettings = true }) {
                    Image(systemName: "gearshape")
                        .imageScale(.large)
                        .foregroundColor(.secondary)
                        .padding(10)
                        .background(Color(nsColor: .systemGray).opacity(0.7))
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 18)

        VStack(alignment: .leading, spacing: 4) {
            Text(manager.isMuted ? "Muted" : "Sound On")
                .font(.headline)
                .foregroundColor(manager.isMuted ? .red : .accentColor)
            if let last = manager.lastEvent {
                Text("Last event: \(last.type.rawValue)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text(last.date, style: .time)
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text("No mute events yet.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 4)

        Divider().padding(.vertical, 4)

        Text("Recent Events")
            .font(.caption)
            .foregroundColor(.secondary)
            .padding(.horizontal, 18)
            .padding(.bottom, 2)
            .frame(maxWidth: .infinity, alignment: .leading)

        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(manager.events.prefix(5)) { event in
                    HStack {
                        Text(event.type.rawValue)
                            .font(.caption)
                            .foregroundColor(.primary)
                        Spacer()
                        Text(event.date, style: .time)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 18)
                }
                if manager.events.isEmpty {
                    Text("No events yet.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 18)
                }
            }
        }
        .frame(height: 70)

        Spacer(minLength: 8)
    }
    .frame(width: 320, height: 340)
}
    }
}

struct SettingsView: View {
    @ObservedObject var manager = MuteManagerObservable.shared
    @Binding var showSettings: Bool
    @State private var restoreVolume: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // --- Settings Toggles ---
            VStack(spacing: 12) {
    // Add top padding so first toggle isn't so close to the divider
    Spacer().frame(height: 8)
                HStack {
                    Text("Mute on Screen Lock")
                    Spacer()
                    Toggle("", isOn: $manager.muteOnScreenLock)
                        .labelsHidden()
                }
                HStack {
                    Text("Mute on Sleep")
                    Spacer()
                    Toggle("", isOn: $manager.muteOnSleep)
                        .labelsHidden()
                }
                HStack {
                    Text("Mute on Shutdown")
                    Spacer()
                    Toggle("", isOn: $manager.muteOnShutdown)
                        .labelsHidden()
                }
                HStack {
                    Text("Mute on Headphones Disconnect")
                    Spacer()
                    Toggle("", isOn: $manager.muteOnHeadphonesDisconnect)
                        .labelsHidden()
                }
                
                HStack {
                    Text("Open at Login")
                    Spacer()
                    Toggle("", isOn: $manager.openAtLogin)
                        .labelsHidden()
                }
            }

            Divider()

            // --- Restore Volume Section ---
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Auto Restore Volume on Unmute")
                    Spacer()
                    Toggle("", isOn: $manager.autoRestore)
                        .labelsHidden()
                }
                HStack(alignment: .center, spacing: 12) {
                    Text("Restore Volume: ")
                        .font(.subheadline)
                    Slider(value: Binding(
                        get: { manager.restoreVolume ?? 0.5 },
                        set: { manager.restoreVolume = min(max($0, 0), 1) }
                    ), in: 0...1, step: 0.01)
                        .frame(width: 120)
                    Text("\(Int((manager.restoreVolume ?? 0.5) * 100))%")
                        .font(.body)
                        .frame(width: 40, alignment: .trailing)
                }
                if let v = manager.restoreVolume {
                    Text("Will restore to \(Int(v * 100))% when unmuted")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Divider()
                .padding(.vertical, 4)

            // --- Feedback Button ---
            HStack {
                Spacer()
                Button(action: {
                    if let url = URL(string: "mailto:evan@taylorlabs.co?subject=SoundSnooze%20Feedback") {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "envelope")
                        Text("Send Feedback")
                    }
                }
                .buttonStyle(BorderlessButtonStyle())
                .foregroundColor(.accentColor)
                Spacer()
            }
            .padding(.vertical, 4)

            // --- Done Button ---
            HStack {
                Spacer()
                Button("Done") {
                    showSettings = false
                }
                .keyboardShortcut(.defaultAction)
                .padding(.vertical, 8)
                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
}

