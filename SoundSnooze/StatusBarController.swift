import SwiftUI
import AppKit
import os.log

/// Controls the macOS menu bar status item and popover
class StatusBarController: NSObject {
    // Logger for debugging and monitoring
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.taylorlabs.SoundSnooze", category: "StatusBarController")
    
    // Strong reference to the status item to prevent it from being deallocated
    private var statusItem: NSStatusItem!
    private var popover: NSPopover
    private var notificationObserver: NSObjectProtocol?
    private var eventMonitor: EventMonitor?

    init(_ popover: NSPopover) {
        self.popover = popover
        super.init()
        
        // Create status item with fixed length
        statusItem = NSStatusBar.system.statusItem(withLength: 24)
        setupStatusItem()
        setupNotificationObservers()
        setupEventMonitor()
        
        logger.debug("StatusBarController initialized")
        print("StatusBarController initialized")
    }
    
    deinit {
        // Remove notification observer to prevent memory leaks
        if let observer = notificationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        
        // Stop the event monitor
        eventMonitor?.stop()
        
        logger.debug("StatusBarController deinitialized")
    }
    
    private func setupStatusItem() {
        guard let button = statusItem.button else {
            logger.error("Failed to access status item button")
            print("Failed to access status item button")
            return
        }
        
        // Fallback to simple text that always works
        button.title = "🔊"
        
        // Set up action for click to show/hide popover
        button.target = self
        button.action = #selector(togglePopover(_:))
        
        // Add accessibility
        button.setAccessibilityLabel("SoundSnooze")
        button.setAccessibilityHelp("Click to show/hide SoundSnooze controls")
        
        logger.debug("Status item setup completed")
        print("Status item setup completed")
    }
    
    /// Refreshes the status item to ensure it's visible in the menu bar
    func refreshStatusItem() {
        // Re-create the status item if needed
        if statusItem == nil {
            statusItem = NSStatusBar.system.statusItem(withLength: 24)
            setupStatusItem()
        }
        
        // Force update the icon
        guard let button = statusItem.button else { return }
        
        // Temporarily change the icon and then change it back to force a refresh
        let currentTitle = button.title
        button.title = ""
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            button.title = currentTitle
        }
        
        logger.debug("Status item refreshed")
        print("Status item refreshed")
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
            print("Failed to access status item button for icon update")
            return
        }
        
        // Use emoji icons which are more reliable than SF Symbols
        button.title = isMuted ? "🔇" : "🔊"
        
        // Update accessibility
        button.setAccessibilityLabel("SoundSnooze: \(isMuted ? "Muted" : "Listening")")
        
        logger.debug("Status bar icon updated to \(isMuted ? "muted" : "unmuted") state")
        print("Status bar icon updated to \(isMuted ? "muted" : "unmuted") state")
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
            print("Failed to access status item button for popover")
            return
        }
        
        logger.debug("Opening popover")
        print("Opening popover")
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        
        // Make sure the popover becomes key to receive keyboard events
        popover.contentViewController?.view.window?.becomeKey()
        
        // Add accessibility focus
        if let firstResponder = popover.contentViewController?.view.window?.initialFirstResponder {
            firstResponder.becomeFirstResponder()
        }
        
        // Start monitoring events when popover is shown
        eventMonitor?.start()
    }
    
    func closePopover(_ sender: AnyObject?) {
        logger.debug("Closing popover")
        print("Closing popover")
        popover.performClose(sender)
        
        // Stop monitoring events when popover is closed
        eventMonitor?.stop()
    }
    

    private func setupEventMonitor() {
        // Create event monitor to detect clicks outside the popover
        eventMonitor = EventMonitor(mask: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self, self.popover.isShown else { return }
            
            // Check if the click is outside the popover
            if event != nil {
                let mouseLocation = NSEvent.mouseLocation
                
                // Get the popover window
                guard let popoverWindow = self.popover.contentViewController?.view.window else { return }
                
                // Convert screen point to window coordinates
                let windowPoint = popoverWindow.convertPoint(fromScreen: mouseLocation)
                
                // Check if the click is outside the popover's content view
                if !NSPointInRect(windowPoint, popoverWindow.contentView?.frame ?? .zero) {
                    self.closePopover(nil)
                }
            }
        }
    }
}

// Helper class to monitor mouse events
class EventMonitor {
    private var monitor: Any?
    private let mask: NSEvent.EventTypeMask
    private let handler: (NSEvent?) -> Void
    
    init(mask: NSEvent.EventTypeMask, handler: @escaping (NSEvent?) -> Void) {
        self.mask = mask
        self.handler = handler
    }
    
    deinit {
        stop()
    }
    
    func start() {
        // Start monitoring global mouse events
        monitor = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: handler)
    }
    
    func stop() {
        // Stop monitoring if active
        if monitor != nil {
            NSEvent.removeMonitor(monitor!)
            monitor = nil
        }
    }
}
