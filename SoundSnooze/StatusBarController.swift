import SwiftUI
import AppKit
import os.log

/// Controls the macOS menu bar status item and popover
class StatusBarController: NSObject {
    // Logger for debugging and monitoring
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.taylorlabs.SoundSnooze", category: "StatusBarController")
    private var statusBar: NSStatusBar
    private var statusItem: NSStatusItem
    private var popover: NSPopover
    private var notificationObserver: NSObjectProtocol?

    init(_ popover: NSPopover) {
        self.statusBar = NSStatusBar.system
        self.statusItem = statusBar.statusItem(withLength: NSStatusItem.variableLength)
        self.popover = popover
        
        super.init()
        
        setupStatusItem()
        setupNotificationObservers()
        
        logger.debug("StatusBarController initialized")
    }
    
    deinit {
        // Remove notification observer to prevent memory leaks
        if let observer = notificationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        logger.debug("StatusBarController deinitialized")
    }
    
    private func setupStatusItem() {
        guard let button = statusItem.button else {
            logger.error("Failed to access status item button")
            return
        }
        
        // Configure the status item button
        updateStatusBarIcon(isMuted: false)
        
        // Set up primary action for left-click
        button.target = self
        button.action = #selector(togglePopover(_:))
        
        // Create a menu for secondary (right) click
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Quit SoundSnooze", action: #selector(quitApp), keyEquivalent: "q"))
        
        // Set this controller as the menu delegate
        menu.delegate = self
        
        // Store the menu for later, but don't assign it to statusItem.menu yet
        // (we'll do that in menuWillOpen and remove it in menuDidClose)
        statusItem.button?.menu = menu
        
        // Add accessibility
        button.setAccessibilityLabel("SoundSnooze")
        button.setAccessibilityHelp("Click to show/hide SoundSnooze controls, right-click for menu")
    }
    
    private func setupNotificationObservers() {
        // Observe mute state changes using weak self to prevent retain cycles
        notificationObserver = NotificationCenter.default.addObserver(
            forName: Notification.Name("SoundSnoozeMuteChanged"),
            object: nil,
            queue: .main
        ) { [weak self] notification in 
            guard let self = self else { return }
            
            if let muted = notification.userInfo?["isMuted"] as? Bool {
                self.updateStatusBarIcon(isMuted: muted)
            }
        }
    }

    private func updateStatusBarIcon(isMuted: Bool) {
        guard let button = statusItem.button else {
            logger.error("Failed to access status item button for icon update")
            return
        }
        
        // Use appropriate SF Symbol based on mute state
        let symbolName = isMuted ? "speaker.slash.circle.fill" : "speaker.wave.2.circle.fill"
        let accessibilityLabel = isMuted ? "Sound is muted" : "Sound is active"
        
        // Create a properly configured image
        let config = NSImage.SymbolConfiguration(pointSize: 18, weight: .bold)
        if let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: accessibilityLabel)?.withSymbolConfiguration(config) {
            image.isTemplate = true // Ensures automatic adaptation for light/dark mode
            button.image = image
        } else {
            logger.error("Failed to create status bar icon image")
        }
        
        // Set appropriate color based on state with better contrast
        button.contentTintColor = isMuted ? NSColor.systemRed : NSColor.controlAccentColor
        
        // Update accessibility
        button.setAccessibilityLabel("SoundSnooze: \(isMuted ? "Muted" : "Listening")")
        
        logger.debug("Status bar icon updated to \(isMuted ? "muted" : "unmuted") state")
    }

    @objc func togglePopover(_ sender: AnyObject?) {
        // This method directly toggles the popover (for left-clicks)
        if popover.isShown {
            closePopover(sender)
        } else {
            showPopover(sender)
        }
    }
    
    func showPopover(_ sender: AnyObject?) {
        guard let button = statusItem.button else {
            logger.error("Failed to access status item button for popover")
            return
        }
        
        logger.debug("Opening popover")
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        
        // Make sure the popover becomes key to receive keyboard events
        popover.contentViewController?.view.window?.becomeKey()
        
        // Add accessibility focus
        if let firstResponder = popover.contentViewController?.view.window?.initialFirstResponder {
            firstResponder.becomeFirstResponder()
        }
    }
    
    func closePopover(_ sender: AnyObject?) {
        logger.debug("Closing popover")
        popover.performClose(sender)
    }
    

    
    @objc func quitApp() {
        logger.info("User initiated app quit")
        NSApp.terminate(nil)
    }
}

// MARK: - NSMenuDelegate
extension StatusBarController: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        // When the menu is about to open, we know it's a right-click
        // If popover is shown, close it
        if popover.isShown {
            closePopover(nil)
        }
    }
}
