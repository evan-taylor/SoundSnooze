import Foundation
import AppKit
import CoreAudio
import os.log

// MARK: - Constants
fileprivate enum Constants {
    static let settingsKey = "SoundSnoozeSettings"
    static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.taylorlabs.SoundSnooze", category: "MuteManager")
}

class MuteManager: NSObject {
    // --- Robust headphone tracking ---
    private var lastConnectedHeadphoneIDs: Set<AudioObjectID> = []

    static let debounceInterval: TimeInterval = 1.5
    private var lastEventTimestamp: Date? = nil
    private var lastEventType: String? = nil // Use string for debounce event type tracking
    static let shared = MuteManager()
    private var deviceListener: AudioObjectID = AudioObjectID(0)
    private var previousVolume: Float32? = nil
    private let observable = MuteManagerObservable.shared
    private let volumeOperationQueue = DispatchQueue(label: "com.taylorlabs.SoundSnooze.VolumeQueue", qos: .userInteractive)

    override init() {
        super.init()
        // Initialize headphone tracking set to current state
        let currentHeadphoneIDs: Set<AudioObjectID> = Set(getAllOutputDeviceIDs().filter { id in
            if let name = getDeviceName(id: id)?.lowercased() {
                return name.contains("headphone") || name.contains("bluetooth") || name.contains("airpods") || name.contains("pods")
            }
            return false
        })
        lastConnectedHeadphoneIDs = currentHeadphoneIDs
        loadSettings()
        subscribeToEvents()
        startAudioDeviceListener()
    }
    
    deinit {
        // Clean up all listeners to prevent memory leaks
        unsubscribeFromEvents()
        stopAudioDeviceListener()
        Constants.logger.info("MuteManager deinitialized")
    }

    // MARK: - Event Subscriptions
    private func subscribeToEvents() {
        // Listen for screen lock via distributed notification
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleScreenLock),
            name: NSNotification.Name("com.apple.screenIsLocked"),
            object: nil
        )
        // Sleep and shutdown via NSWorkspace
        let workspace = NSWorkspace.shared.notificationCenter
        workspace.addObserver(self, selector: #selector(handleSleep), name: NSWorkspace.willSleepNotification, object: nil)
        workspace.addObserver(self, selector: #selector(handleShutdown), name: NSWorkspace.willPowerOffNotification, object: nil)
        
        // Listen for settings changes to save them
        NotificationCenter.default.addObserver(self, selector: #selector(saveSettings), name: Notification.Name("SoundSnoozeSettingsChanged"), object: nil)
    }
    
    private func unsubscribeFromEvents() {
        // Remove all observers to prevent memory leaks
        DistributedNotificationCenter.default().removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Notification Handlers
    @objc private func handleScreenLock(_ notification: Notification) {
        if observable.muteOnScreenLock {
            muteSystem(event: .lock)
        }
    }
    @objc private func handleSleep(_ notification: Notification) {
        if observable.muteOnSleep {
            muteSystem(event: .sleep)
        }
    }
    @objc private func handleShutdown(_ notification: Notification) {
        if observable.muteOnShutdown {
            muteSystem(event: .shutdown)
        }
    }

    // MARK: - Audio Device Listener
    private func startAudioDeviceListener() {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let systemObjectID = AudioObjectID(kAudioObjectSystemObject)
        let status = AudioObjectAddPropertyListenerBlock(systemObjectID, &address, DispatchQueue.main) { _, _ in
            self.handleAudioDeviceChange()
        }
        
        if status != noErr {
            Constants.logger.error("Failed to register audio device listener: \(OSStatus(status))")
        } else {
            deviceListener = systemObjectID
            Constants.logger.debug("Audio device listener registered successfully")
        }
    }
    
    private func stopAudioDeviceListener() {
        if deviceListener != 0 {
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioHardwarePropertyDevices,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            let status = AudioObjectRemovePropertyListenerBlock(deviceListener, &address, DispatchQueue.main, { _, _ in })
            if status != noErr {
                Constants.logger.error("Failed to remove audio device listener: \(OSStatus(status))")
            } else {
                Constants.logger.debug("Audio device listener removed successfully")
            }
            deviceListener = 0
        }
    }

    private func handleAudioDeviceChange() {
        // Debug: Log all output device IDs and names
        let allIDs = getAllOutputDeviceIDs()
        for id in allIDs {
            let name = getDeviceName(id: id) ?? "<unknown>"
            Constants.logger.info("Output device: ID=\(id), name=\(name)")
        }
        let now = Date()
        // Get current set of headphone device IDs
        let currentHeadphoneIDs: Set<AudioObjectID> = Set(getAllOutputDeviceIDs().filter { id in
            if let name = getDeviceName(id: id)?.lowercased() {
                return name.contains("headphone") || name.contains("bluetooth") || name.contains("airpods") || name.contains("pods")
            }
            return false
        })
        let prevHeadphoneIDs = lastConnectedHeadphoneIDs
        lastConnectedHeadphoneIDs = currentHeadphoneIDs

        // Detect disconnect (went from non-empty to empty)
        if !prevHeadphoneIDs.isEmpty && currentHeadphoneIDs.isEmpty && observable.muteOnHeadphonesDisconnect {
            // Debounce logic: only process if enough time has passed or event is different
            if let lastTime = lastEventTimestamp, let lastType = lastEventType, lastType == "headphonesDisconnected", now.timeIntervalSince(lastTime) < Self.debounceInterval {
                Constants.logger.info("Event Headphones Disconnected ignored due to debouncing")
                return
            }
            // Prevent duplicate event history
            if let last = observable.lastEvent, last.type == .headphonesDisconnected {
                Constants.logger.info("Duplicate Headphones Disconnected event ignored for event history")
            } else {
                muteSystem(event: .headphonesDisconnected)
                Constants.logger.info("Headphones disconnected - muting system")
            }
            lastEventTimestamp = now
            lastEventType = "headphonesDisconnected"
        }
        // Detect connect (went from empty to non-empty)
        else if prevHeadphoneIDs.isEmpty && !currentHeadphoneIDs.isEmpty {
            // Debounce logic for reconnect
            if let lastTime = lastEventTimestamp, let lastType = lastEventType, lastType == "headphonesReconnected", now.timeIntervalSince(lastTime) < Self.debounceInterval {
                Constants.logger.info("Event Headphones Reconnected ignored due to debouncing")
                return
            }
            unmuteSystem()
            Constants.logger.info("Headphones connected - unmuting system")
            lastEventTimestamp = now
            lastEventType = "headphonesReconnected"
            // Record reconnected event and update UI
            DispatchQueue.main.async {
                self.observable.isMuted = false
                self.observable.lastEvent = MuteEvent(type: .headphonesReconnected, date: now)
            }
        }
        // Handle hot-swapping: both sets non-empty and different
        else if !prevHeadphoneIDs.isEmpty && !currentHeadphoneIDs.isEmpty && prevHeadphoneIDs != currentHeadphoneIDs {
            // Debounce logic for swap
            if let lastTime = lastEventTimestamp, let lastType = lastEventType, lastType == "headphonesSwapped", now.timeIntervalSince(lastTime) < Self.debounceInterval {
                Constants.logger.info("Event Headphones Swapped ignored due to debouncing")
                return
            }
            // Optionally unmute if muted
            if observable.isMuted {
                unmuteSystem()
            }
            Constants.logger.info("Headphones swapped - updating event")
            lastEventTimestamp = now
            lastEventType = "headphonesSwapped"
            DispatchQueue.main.async {
                self.observable.lastEvent = MuteEvent(type: .headphonesSwapped, date: now)
            }
        }
        // Otherwise, do nothing (no change in connection state)
    }

    // (Removed obsolete isHeadphonesConnected. Now handled by robust set tracking.)


    private func getAllOutputDeviceIDs() -> [AudioObjectID] {
        var propertySize: UInt32 = 0
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &propertySize) == noErr else { return [] }
        let deviceCount = Int(propertySize) / MemoryLayout<AudioObjectID>.size
        var deviceIDs = [AudioObjectID](repeating: 0, count: deviceCount)
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &propertySize, &deviceIDs)
        // Filter for output devices
        return deviceIDs.filter { isOutputDevice(id: $0) }
    }

    private func isOutputDevice(id: AudioObjectID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var propertySize: UInt32 = 0
        if AudioObjectGetPropertyDataSize(id, &address, 0, nil, &propertySize) == noErr {
            return propertySize > 0
        }
        return false
    }

    private func getDeviceName(id: AudioObjectID) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var propertySize = UInt32(MemoryLayout<CFString>.size)
        var name: CFString = "" as CFString
        let status = withUnsafeMutablePointer(to: &name) { ptr -> OSStatus in
            return AudioObjectGetPropertyData(id, &address, 0, nil, &propertySize, ptr)
        }
        if status == noErr {
            return name as String
        }
        return nil
    }

    // MARK: - Mute Logic
    func muteSystem(event: MuteEventType? = nil) {
        volumeOperationQueue.async {
            // Save previous volume if not already muted
            if !self.observable.isMuted {
                self.previousVolume = self.getCurrentSystemVolume()
                Constants.logger.debug("Saved previous volume: \(String(describing: self.previousVolume))")
            }
            
            if self.observable.isMuted {
                Constants.logger.info("Mute requested, but system is already muted. No state change.")
                return
            }
            if self.setSystemVolume(0) {
                DispatchQueue.main.async {
                    self.observable.isMuted = true
                    if let eventType = event {
                        // Prevent duplicate event history
                        if self.observable.lastEvent?.type != eventType {
                            self.observable.recordEvent(eventType)
                        }
                        Constants.logger.info("System muted due to event: \(eventType.rawValue)")
                    } else {
                        // For manual mute, update lastEvent so UI always reflects the change
                        self.observable.lastEvent = MuteEvent(type: .shutdown, date: Date()) // Use .shutdown or define a .manual event if desired
                        Constants.logger.info("System muted manually")
                    }
                }
            } else {
                Constants.logger.error("Failed to mute system")
            }
        }
    }

    func unmuteSystem() {
        volumeOperationQueue.async {
            // Restore volume if requested
            let volume: Float32
            if self.observable.autoRestore, let restore = self.observable.restoreVolume {
                volume = min(max(restore, 0), 1) // Ensure volume is within bounds
                Constants.logger.debug("Restoring to saved volume: \(volume)")
            } else if let prev = self.previousVolume {
                volume = min(max(prev, 0), 1) // Ensure volume is within bounds
                Constants.logger.debug("Restoring to previous volume: \(volume)")
            } else {
                volume = 0.5 // Default
                Constants.logger.debug("Restoring to default volume: 0.5")
            }
            
            if self.setSystemVolume(volume) {
                DispatchQueue.main.async {
                    self.observable.isMuted = false
                    self.observable.lastEvent = MuteEvent(type: .headphonesReconnected, date: Date())
                    Constants.logger.info("System unmuted successfully")
                }
            } else {
                Constants.logger.error("Failed to unmute system")
            }
        }
    }

    private func getCurrentSystemVolume() -> Float32 {
        let deviceID = getDefaultOutputDeviceID()
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: 1
        )
        var volume = Float32(0)
        var size = UInt32(MemoryLayout<Float32>.size)
        let err = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &volume)
        if err == noErr {
            return volume
        }
        return 0.5
    }

    private func setSystemVolume(_ volume: Float32) -> Bool {
        // Ensure volume is within valid bounds (0.0 to 1.0)
        let safeVolume = min(max(volume, 0), 1)
        if safeVolume != volume {
            Constants.logger.warning("Volume value out of bounds (\(volume)), clamped to \(safeVolume)")
        }
        
        let deviceID = getDefaultOutputDeviceID()
        if deviceID == 0 {
            Constants.logger.error("Failed to get default output device")
            return tryAppleScriptVolume(safeVolume)
        }
        
        let channels: [UInt32] = [1, 2] // Left and right
        var success = true
        for channel in channels {
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: channel
            )
            
            // Check if volume property exists and is settable
            var isSettable: DarwinBoolean = false
            let status = AudioObjectIsPropertySettable(deviceID, &address, &isSettable)
            
            if status != noErr || !isSettable.boolValue {
                Constants.logger.debug("Volume property not settable for channel \(channel): \(OSStatus(status))")
                success = false
                continue
            }
            
            var newVolume = safeVolume
            let setStatus = AudioObjectSetPropertyData(deviceID, &address, 0, nil, UInt32(MemoryLayout<Float32>.size), &newVolume)
            
            if setStatus != noErr {
                Constants.logger.info("Failed to set volume for channel \(channel): \(OSStatus(setStatus))")
                success = false
            }
        }
        
        if !success {
            Constants.logger.info("CoreAudio volume setting failed, falling back to AppleScript")
            return tryAppleScriptVolume(safeVolume)
        }
        
        return true
    }
    
    private func tryAppleScriptVolume(_ volume: Float32) -> Bool {
        // Fallback to AppleScript when CoreAudio fails
        let script = "set volume output volume \(Int(volume*100))"
        let appleScript = NSAppleScript(source: script)
        var errorDict: NSDictionary? = nil
        appleScript?.executeAndReturnError(&errorDict)
        
        if let errorDict = errorDict {
            Constants.logger.error("AppleScript volume setting failed: \(errorDict)")
            return false
        }
        
        Constants.logger.info("Volume set successfully via AppleScript")
        return true
    }

    private func getDefaultOutputDeviceID() -> AudioObjectID {
        var deviceID = AudioObjectID(0)
        var propertySize = UInt32(MemoryLayout<AudioObjectID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &propertySize, &deviceID)
        if status != noErr {
            Constants.logger.error("Failed to get default output device: \(OSStatus(status))")
        }
        return deviceID
    }
}

// MARK: - Settings Management
extension MuteManager {
    @objc func saveSettings() {
        let settings: [String: Any] = [
            "muteOnScreenLock": observable.muteOnScreenLock,
            "muteOnSleep": observable.muteOnSleep,
            "muteOnShutdown": observable.muteOnShutdown,
            "muteOnHeadphonesDisconnect": observable.muteOnHeadphonesDisconnect,
            "autoRestore": observable.autoRestore,
            "restoreVolume": observable.restoreVolume ?? 0.5
        ]
        
        UserDefaults.standard.set(settings, forKey: Constants.settingsKey)
        Constants.logger.debug("Settings saved")
    }
    
    private func loadSettings() {
        guard let settings = UserDefaults.standard.dictionary(forKey: Constants.settingsKey) else {
            Constants.logger.info("No saved settings found, using defaults")
            return
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if let value = settings["muteOnScreenLock"] as? Bool {
                self.observable.muteOnScreenLock = value
            }
            if let value = settings["muteOnSleep"] as? Bool {
                self.observable.muteOnSleep = value
            }
            if let value = settings["muteOnShutdown"] as? Bool {
                self.observable.muteOnShutdown = value
            }
            if let value = settings["muteOnHeadphonesDisconnect"] as? Bool {
                self.observable.muteOnHeadphonesDisconnect = value
            }
            if let value = settings["autoRestore"] as? Bool {
                self.observable.autoRestore = value
            }
            if let value = settings["restoreVolume"] as? Float32 {
                self.observable.restoreVolume = min(max(value, 0), 1)
            }
            
            Constants.logger.info("Settings loaded successfully")
        }
    }
}
