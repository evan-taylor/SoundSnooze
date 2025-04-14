//
//  SoundSnoozeApp.swift
//  MuteMe
//
//  Created by Evan Taylor on 4/14/25.
//

import SwiftUI

@main
struct SoundSnoozeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView() // Hide default window
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarController: StatusBarController?
    var popover = NSPopover()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let contentView = ContentView()
            .frame(width: 320, height: 340)
        popover.contentSize = NSSize(width: 320, height: 340)
        popover.behavior = .transient
        popover.contentViewController = NSViewController()
        popover.contentViewController?.view = NSHostingView(rootView: contentView)

        statusBarController = StatusBarController(popover)
        _ = MuteManager.shared // Start event detection and muting logic
    }
}
