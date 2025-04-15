# SoundSnooze

[![Buy Me a Coffee](https://img.shields.io/badge/Buy%20Me%20a%20Coffee-☕-ffdd00?style=flat-square)](https://buymeacoffee.com/evan.taylor)

**SoundSnooze** is a free, lightweight macOS utility that automatically mutes your Mac when you lock the screen, put it to sleep, shut down, or disconnect your headphones — and restores your volume when you return.

If you find it useful, consider [supporting development with a small donation](https://buymeacoffee.com/evan.taylor) — every coffee helps!

## Features

- **Smart Muting**: Automatically mutes your Mac on:
  - Screen lock
  - Sleep
  - Shutdown
  - Headphone disconnection (including Bluetooth devices)
- **Volume Restoration**: Optionally restores your previous volume level when you return
- **Customizable**: Enable/disable each trigger individually
- **Event Tracking**: See recent mute events in the menu bar
- **Zero Privacy Impact**: Works without microphone access or data collection
- **Minimal Resource Usage**: Lightweight menu bar app with minimal CPU/memory footprint
- **Auto-Launch**: Optional setting to open at login

## Installation

1. Download the latest [SoundSnooze.dmg](https://github.com/evantaylor/soundsnooze/releases/latest) from the releases page
2. Open the DMG file
3. Drag SoundSnooze to your Applications folder
4. Launch SoundSnooze from your Applications folder

## Usage

- **Left-click** the menu bar icon to open the main interface
- **Right-click** the menu bar icon for quick access to quit
- Use the toggles in Settings to customize which events trigger muting
- Set "Auto Restore Volume" to automatically return to your preferred volume level

## System Requirements

- macOS Monterey (12.0) or later
- Compatible with both Intel and Apple Silicon Macs

## Technical Details

SoundSnooze is built with:
- SwiftUI for the user interface
- AppKit for system integration
- CoreAudio for audio device monitoring
- ServiceManagement for login item management

## Privacy

SoundSnooze respects your privacy:
- No analytics or tracking
- No network access
- No microphone access required
- All functionality happens locally on your Mac

## License

Copyright © 2025 Taylor Labs. All rights reserved.

## Contact

For feedback or support, contact: [evan@taylorlabs.co](mailto:evan@taylorlabs.co)
