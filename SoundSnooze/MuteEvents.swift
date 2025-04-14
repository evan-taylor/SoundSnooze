import Foundation
import Combine
import CoreAudio
import AppKit
import os.log
import ServiceManagement

/// Types of mute events
enum MuteEventType: String, Codable, CaseIterable {
    case lock = "Screen Locked"
    case sleep = "Sleep"
    case shutdown = "Shutdown"
    case headphonesDisconnected = "Headphones Disconnected"
    case headphonesReconnected = "Headphones Connected"
    case headphonesSwapped = "Headphones Swapped"
}

/// Event record
struct MuteEvent: Identifiable, Codable {
    let id: UUID
    let type: MuteEventType
    let date: Date

    init(id: UUID = UUID(), type: MuteEventType, date: Date) {
        self.id = id
        self.type = type
        self.date = date
    }
}

/// Observable manager for UI binding
class MuteManagerObservable: ObservableObject {
    // Logger for debugging and monitoring
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.taylorlabs.SoundSnooze", category: "MuteManagerObservable")
    
    // Singleton instance
    static let shared = MuteManagerObservable()
    
    // Events tracking
    @Published var lastEvent: MuteEvent?
    @Published var events: [MuteEvent] = []
    
    // Open at login setting
    @Published var openAtLogin: Bool = false {
        didSet {
            // Use the appropriate ServiceManagement API based on macOS version
            if #available(macOS 13.0, *) {
                do {
                    // For macOS 13+ use the modern API
                    if self.openAtLogin {
                        try SMAppService.mainApp.register()
                    } else {
                        try SMAppService.mainApp.unregister()
                    }
                    logger.debug("Login item set to: \(self.openAtLogin)")
                } catch {
                    logger.error("Failed to set login item status: \(error.localizedDescription)")
                }
            } else {
                // For older macOS versions, use the older API
                let success = SMLoginItemSetEnabled(Bundle.main.bundleIdentifier! as CFString, self.openAtLogin)
                logger.debug("Login item (legacy API) set to: \(self.openAtLogin), success: \(success)")
            }
        }
    }
    
    // Mute state with notification
    @Published var isMuted: Bool = false {
        didSet {
            // Notify status bar controller and other observers of mute state changes
            NotificationCenter.default.post(
                name: Notification.Name("SoundSnoozeMuteChanged"),
                object: nil,
                userInfo: ["isMuted": isMuted]
            )
            logger.debug("Mute state changed to: \(self.isMuted)")
        }
    }
    
    // Settings with notifications and validation
    @Published var restoreVolume: Float32? = nil {
        didSet { 
            // Ensure volume is within valid range
            if let volume = restoreVolume {
                let validVolume = min(max(volume, 0), 1)
                if validVolume != volume {
                    DispatchQueue.main.async {
                        self.restoreVolume = validVolume
                        return
                    }
                }
            }
            notifySettingsChanged() 
        }
    }
    
    @Published var autoRestore: Bool = false {
        didSet { notifySettingsChanged() }
    }
    
    // Event toggles
    @Published var muteOnScreenLock: Bool = true {
        didSet { notifySettingsChanged() }
    }
    
    @Published var muteOnSleep: Bool = true {
        didSet { notifySettingsChanged() }
    }
    
    @Published var muteOnShutdown: Bool = true {
        didSet { notifySettingsChanged() }
    }
    
    @Published var muteOnHeadphonesDisconnect: Bool = true {
        didSet { notifySettingsChanged() }
    }
    
    // Private init to ensure singleton usage
    private init() {
        logger.debug("MuteManagerObservable initialized")
        
        // Max number of events to keep in memory
        events.reserveCapacity(20)
    }

    // Event management
    private var lastEventTimestamp: Date? = nil
    private var debounceWindow: TimeInterval { 2.0 } // seconds
    
    // Limit for stored events to prevent memory issues
    private let maxStoredEvents = 20
    
    /// Records a new mute event with debouncing to prevent duplicates
    func recordEvent(_ type: MuteEventType) {
        let now = Date()
        
        // Debounce to prevent duplicate events
        if let last = lastEventTimestamp, now.timeIntervalSince(last) < debounceWindow {
            logger.debug("Event \(type.rawValue) ignored due to debouncing")
            return
        }
        
        lastEventTimestamp = now
        let event = MuteEvent(type: type, date: now)
        lastEvent = event
        
        // Insert at beginning and maintain max count
        events.insert(event, at: 0)
        if events.count > maxStoredEvents {
            events = Array(events.prefix(maxStoredEvents))
        }
        
        logger.info("Recorded mute event: \(type.rawValue)")
        isMuted = true
    }
    
    /// Clears all recorded events
    func clearEvents() {
        events.removeAll()
        lastEvent = nil
        logger.debug("All events cleared")
    }
    
    // Notifications
    private func notifySettingsChanged() {
        NotificationCenter.default.post(name: Notification.Name("SoundSnoozeSettingsChanged"), object: nil)
        logger.debug("Settings changed notification posted")
    }
}
