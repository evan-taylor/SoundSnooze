//
//  SoundSnoozeApp.swift
//  MuteMe
//
//  Created by Evan Taylor on 4/14/25.
//

import SwiftUI
import AppKit

@main
struct SoundSnoozeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    init() {
        // Use prohibited instead of accessory - this is the key to completely hiding from Dock
        NSApplication.shared.setActivationPolicy(.prohibited)
    }
    
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
        // Double-check activation policy is set to prohibited
        if NSApplication.shared.activationPolicy() != .prohibited {
            NSApplication.shared.setActivationPolicy(.prohibited)
        }
        
        // Set up the content view for the popover
        let contentView = ContentView()
            .frame(width: 320, height: 340)
        popover.contentSize = NSSize(width: 320, height: 340)
        popover.behavior = .transient
        popover.contentViewController = NSViewController()
        popover.contentViewController?.view = NSHostingView(rootView: contentView)
        
        // Close any windows that might have been created
        for window in NSApplication.shared.windows {
            window.close()
        }
        
        // Initialize the status bar controller
        statusBarController = StatusBarController(popover)
        
        // Start event detection and muting logic
        _ = MuteManager.shared
    }
    
    // Prevent app activation
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        return false
    }
}
