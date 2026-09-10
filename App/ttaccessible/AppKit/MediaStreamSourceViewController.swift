//
//  MediaStreamSourceViewController.swift
//  ttaccessible
//
//  "Choose what to stream" sheet: a source button whose menu lists all system
//  audio and the input devices and VoiceOver at the top level, with the
//  applications in an "Application" submenu, plus the monitor and mute-source
//  options.
//
//  The menu items are CHECKABLE and applications cumulate: both capture
//  backends mix several processes themselves (see DeviceStreamCaptureSpec.merging),
//  so ticking Music and then VoiceOver streams both. Devices don't cumulate — a
//  device is captured by an entirely different backend — so picking one clears
//  the applications, and vice versa; the same goes for all-system audio, which
//  already contains everything. Every choice is announced, clearings included:
//  an item unticking itself inside a closed menu is invisible.
//
//  This is a SHEET hosting a plain view controller, not an NSAlert. That is
//  what makes the menu work: the dialog used to be an NSAlert run app-modally,
//  and in a modal session AppKit never delivers an NSMenuItem's action, so no
//  source could be selected at all — the menu opened, highlighted and dismissed
//  while the choice was silently dropped. Outside a modal session the menu, its
//  submenu and their actions all behave normally.
//

import AppKit
import UniformTypeIdentifiers

final class MediaStreamSourceViewController: NSViewController {

    /// Confirmed with the chosen source, whether to monitor it locally, and
    /// whether to mute it on this Mac while streaming.
    var onStream: ((DeviceStreamCaptureSpec, Bool, Bool) -> Void)?

    private let devices: [InputAudioDeviceInfo]
    private var applicationSources: [DeviceStreamCaptureSpec]
    private let voiceOverAvailable: Bool
    private let allowsApplicationBrowsing: Bool
    private let allowsSystemAudio: Bool
    private let preselectedToken: String?
    private let fallbackDeviceUID: String?

    /// At most one device, any number of applications (VoiceOver counts as
    /// one), or all system audio — the three are mutually exclusive.
    private var selectedDevice: InputAudioDeviceInfo?
    private var selectedApplications: [DeviceStreamCaptureSpec] = []
    private var systemAudioSelected = false

    private var sourceButton: NSButton!
    private var monitorCheckbox: NSButton!
    private var muteSourceCheckbox: NSButton?
    private var streamButton: NSButton!

    /// - Parameters:
    ///   - allowsApplicationBrowsing: browsing for a not-yet-running app needs
    ///     the process-tap backend's wait-and-attach (macOS 14.2+); the
    ///     ScreenCaptureKit tier can only capture apps that are already running.
    ///   - allowsSystemAudio: capturing everything the Mac plays needs one of
    ///     the two process backends, so macOS 13 or later.
    init(devices: [InputAudioDeviceInfo],
         applicationSources: [DeviceStreamCaptureSpec],
         voiceOverAvailable: Bool,
         allowsApplicationBrowsing: Bool,
         allowsSystemAudio: Bool,
         preselectedToken: String?,
         fallbackDeviceUID: String?) {
        self.devices = devices
        self.applicationSources = applicationSources
        self.voiceOverAvailable = voiceOverAvailable
        self.allowsApplicationBrowsing = allowsApplicationBrowsing
        self.allowsSystemAudio = allowsSystemAudio
        self.preselectedToken = preselectedToken
        self.fallbackDeviceUID = fallbackDeviceUID
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 440, height: 210))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupLayout()
        selectPreferredSource()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        view.window?.initialFirstResponder = sourceButton
        view.window?.makeFirstResponder(sourceButton)
        // Return confirms even while the source button holds focus; a key
        // equivalent alone doesn't carry in a sheet.
        view.window?.defaultButtonCell = streamButton.cell as? NSButtonCell
    }

    // MARK: - Sources

    /// Every selectable source, flat, in menu order — used for preselection and
    /// for restoring a remembered choice.
    private var orderedSources: [DeviceStreamCaptureSpec] {
        var specs: [DeviceStreamCaptureSpec] = []
        if allowsSystemAudio { specs.append(.systemAudio()) }
        specs.append(contentsOf: devices.map { DeviceStreamCaptureSpec.inputDevice($0) })
        if voiceOverAvailable { specs.append(.voiceOver()) }
        specs.append(contentsOf: applicationSources)
        return specs
    }

    private func isSelected(_ spec: DeviceStreamCaptureSpec) -> Bool {
        switch spec {
        case .inputDevice(let device):
            return selectedDevice == device
        case .processes(let selection):
            if selection.capturesEntireSystem { return systemAudioSelected }
            return selectedApplications.contains(spec)
        }
    }

    // MARK: - Setup

    private func setupLayout() {
        let header = NSTextField(wrappingLabelWithString: L10n.text("mediaStream.device.prompt.title"))
        header.font = .boldSystemFont(ofSize: NSFont.systemFontSize)
        header.translatesAutoresizingMaskIntoConstraints = false
        // AXHeading by raw value: the typed constant is macOS 26+, this app
        // targets 12. Same approach as MoveUsersViewController.
        header.setAccessibilityRole(NSAccessibility.Role(rawValue: "AXHeading"))

        let message = NSTextField(wrappingLabelWithString: L10n.text("mediaStream.device.prompt.message"))
        message.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        message.textColor = .secondaryLabelColor
        message.translatesAutoresizingMaskIntoConstraints = false

        sourceButton = NSButton(title: "", target: self, action: #selector(showSourceMenu))
        sourceButton.bezelStyle = .rounded
        sourceButton.translatesAutoresizingMaskIntoConstraints = false
        // Reads as a pop-up button rather than a plain button: the role can be
        // overridden here, unlike the VALUE, which is why the title carries the
        // selection summary.
        sourceButton.setAccessibilityRole(.popUpButton)
        sourceButton.setAccessibilityLabel(L10n.text("mediaStream.device.prompt.sourceLabel"))

        // Off by default on purpose: the source is usually audible locally
        // already, and hearing it back a second time reads as an echo.
        monitorCheckbox = NSButton(checkboxWithTitle: L10n.text("mediaStream.device.prompt.monitor"),
                                   target: nil, action: nil)
        monitorCheckbox.state = .off
        monitorCheckbox.translatesAutoresizingMaskIntoConstraints = false

        let optionsStack = NSStackView(views: [monitorCheckbox])
        optionsStack.orientation = .vertical
        optionsStack.alignment = .leading
        optionsStack.spacing = 6
        optionsStack.translatesAutoresizingMaskIntoConstraints = false

        // Mute-while-streaming (process taps only, macOS 14.2+): silence the
        // captured app/VoiceOver on this Mac so only the channel hears it.
        // Deliberately never persisted and off by default — an accidentally
        // muted VoiceOver would be catastrophic for a VoiceOver user.
        if #available(macOS 14.2, *) {
            let checkbox = NSButton(checkboxWithTitle: L10n.text("mediaStream.device.prompt.muteSource"),
                                    target: nil, action: nil)
            checkbox.state = .off
            checkbox.translatesAutoresizingMaskIntoConstraints = false
            muteSourceCheckbox = checkbox
            optionsStack.addArrangedSubview(checkbox)
        }

        let cancelButton = NSButton(title: L10n.text("common.cancel"), target: self, action: #selector(cancel))
        cancelButton.bezelStyle = .rounded
        cancelButton.keyEquivalent = "\u{1B}"
        cancelButton.translatesAutoresizingMaskIntoConstraints = false

        streamButton = NSButton(title: L10n.text("mediaStream.device.prompt.start"),
                                target: self, action: #selector(confirm))
        streamButton.bezelStyle = .rounded
        streamButton.keyEquivalent = "\r"
        streamButton.translatesAutoresizingMaskIntoConstraints = false

        [header, message, sourceButton, optionsStack, cancelButton, streamButton]
            .forEach { view.addSubview($0) }

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: view.topAnchor, constant: 14),
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 14),
            header.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -14),

            message.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 6),
            message.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 14),
            message.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -14),

            sourceButton.topAnchor.constraint(equalTo: message.bottomAnchor, constant: 12),
            sourceButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 14),
            sourceButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -14),

            optionsStack.topAnchor.constraint(equalTo: sourceButton.bottomAnchor, constant: 12),
            optionsStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 14),
            optionsStack.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -14),

            streamButton.topAnchor.constraint(greaterThanOrEqualTo: optionsStack.bottomAnchor, constant: 14),
            streamButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -14),
            streamButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -14),
            cancelButton.trailingAnchor.constraint(equalTo: streamButton.leadingAnchor, constant: -8),
            cancelButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -14),
        ])
    }

    // MARK: - Menu

    @objc private func showSourceMenu() {
        let menu = NSMenu()
        if allowsSystemAudio {
            menu.addItem(makeSourceItem(for: .systemAudio()))
            menu.addItem(.separator())
        }
        for device in devices {
            menu.addItem(makeSourceItem(for: .inputDevice(device)))
        }

        let hasApplicationMenu = applicationSources.isEmpty == false || allowsApplicationBrowsing
        if voiceOverAvailable || hasApplicationMenu {
            if devices.isEmpty == false { menu.addItem(.separator()) }
            if voiceOverAvailable {
                menu.addItem(makeSourceItem(for: .voiceOver()))
            }
            if hasApplicationMenu {
                let submenu = NSMenu(title: L10n.text("mediaStream.device.group.applications"))
                for source in applicationSources {
                    submenu.addItem(makeSourceItem(for: source))
                }
                if allowsApplicationBrowsing {
                    // Browse for ANY installed app, running or not: the tap
                    // backend waits for it and attaches when it plays audio.
                    if applicationSources.isEmpty == false { submenu.addItem(.separator()) }
                    let browse = NSMenuItem(title: L10n.text("mediaStream.device.source.chooseApplication"),
                                            action: #selector(browseForApplication),
                                            keyEquivalent: "")
                    browse.target = self
                    submenu.addItem(browse)
                }
                let parent = NSMenuItem(title: L10n.text("mediaStream.device.group.applications"),
                                        action: nil, keyEquivalent: "")
                parent.submenu = submenu
                menu.addItem(parent)
            }
        }

        menu.popUp(positioning: nil,
                   at: NSPoint(x: 0, y: sourceButton.bounds.height + 2),
                   in: sourceButton)
    }

    private func makeSourceItem(for spec: DeviceStreamCaptureSpec) -> NSMenuItem {
        let item = NSMenuItem(title: spec.displayName, action: #selector(selectSource(_:)), keyEquivalent: "")
        item.target = self
        item.representedObject = spec
        item.state = isSelected(spec) ? .on : .off
        return item
    }

    @objc private func selectSource(_ sender: NSMenuItem) {
        guard let spec = sender.representedObject as? DeviceStreamCaptureSpec else { return }
        switch spec {
        case .inputDevice:
            // Devices don't toggle: exactly one at a time, picked afresh — the
            // menu behaves like the plain pop-up it always was for them.
            let cleared = apply(spec, selected: true)
            announce(([spec.displayName + "."] + cleared).joined(separator: " "))
        case .processes:
            // Applications (VoiceOver and all-system audio included) TOGGLE, so
            // several can cumulate; say the new state, then what it cleared.
            let selected = !isSelected(spec)
            let cleared = apply(spec, selected: selected)
            let stateText = L10n.format(selected ? "mediaStream.device.source.checked"
                                                 : "mediaStream.device.source.unchecked",
                                        spec.displayName)
            announce(([stateText] + cleared).joined(separator: " "))
        }
    }

    // MARK: - Selection

    /// Applies a tick, enforcing the exclusions, and returns what the tick took
    /// away for the caller to say out loud — an item unticking itself inside a
    /// closed menu is invisible to anyone not looking at it.
    @discardableResult
    private func apply(_ spec: DeviceStreamCaptureSpec, selected: Bool) -> [String] {
        var clearedMessages: [String] = []

        switch spec {
        case .inputDevice(let device):
            if selected {
                if selectedApplications.isEmpty == false {
                    clearedMessages.append(L10n.text("mediaStream.device.cleared.applications"))
                    selectedApplications.removeAll()
                }
                if systemAudioSelected {
                    clearedMessages.append(L10n.text("mediaStream.device.cleared.systemAudio"))
                    systemAudioSelected = false
                }
                if let previous = selectedDevice, previous != device {
                    clearedMessages.append(L10n.format("mediaStream.device.cleared.device", previous.name))
                }
                selectedDevice = device
            } else if selectedDevice == device {
                selectedDevice = nil
            }

        case .processes(let selection) where selection.capturesEntireSystem:
            if selected {
                if let previous = selectedDevice {
                    clearedMessages.append(L10n.format("mediaStream.device.cleared.device", previous.name))
                    selectedDevice = nil
                }
                if selectedApplications.isEmpty == false {
                    clearedMessages.append(L10n.text("mediaStream.device.cleared.applications"))
                    selectedApplications.removeAll()
                }
            }
            systemAudioSelected = selected

        case .processes:
            if selected {
                if let previous = selectedDevice {
                    clearedMessages.append(L10n.format("mediaStream.device.cleared.device", previous.name))
                    selectedDevice = nil
                }
                if systemAudioSelected {
                    clearedMessages.append(L10n.text("mediaStream.device.cleared.systemAudio"))
                    systemAudioSelected = false
                }
                if selectedApplications.contains(spec) == false {
                    selectedApplications.append(spec)
                }
            } else {
                selectedApplications.removeAll { $0 == spec }
            }
        }

        refreshSelectionUI()
        return clearedMessages
    }

    private func refreshSelectionUI() {
        sourceButton.title = selectionSummary()
        updateMuteAvailability()
        streamButton.isEnabled = resolvedSpec != nil
    }

    /// The button title: the one selected source's name, or a count of the
    /// selected applications.
    private func selectionSummary() -> String {
        if systemAudioSelected {
            return L10n.text("mediaStream.device.source.systemAudio")
        }
        if let selectedDevice {
            return selectedDevice.name
        }
        if selectedApplications.count == 1 {
            return selectedApplications[0].displayName
        }
        if selectedApplications.isEmpty == false {
            return L10n.format("mediaStream.device.summary.applications", selectedApplications.count)
        }
        return L10n.text("mediaStream.device.summary.none")
    }

    /// Restores the last streamed selection, falling back to the default input
    /// device and then to whatever comes first.
    private func selectPreferredSource() {
        if let preselectedToken {
            let tokens = DeviceStreamCaptureSpec.componentTokens(of: preselectedToken)
            let sources = orderedSources
            let restored = tokens.compactMap { token in
                sources.first(where: { $0.persistenceToken == token })
            }
            if restored.isEmpty == false {
                restored.forEach { apply($0, selected: true) }
                return
            }
        }
        if let fallbackDeviceUID,
           let device = devices.first(where: { $0.uid == fallbackDeviceUID }) {
            apply(.inputDevice(device), selected: true)
            return
        }
        if let first = orderedSources.first {
            apply(first, selected: true)
        }
    }

    private func updateMuteAvailability() {
        guard let muteSourceCheckbox else { return }
        // Never offered for all-system audio: muting the tap there would
        // silence the whole Mac, VoiceOver included.
        let isMutableSource = systemAudioSelected == false && selectedApplications.isEmpty == false
        muteSourceCheckbox.isEnabled = isMutableSource
        if isMutableSource == false { muteSourceCheckbox.state = .off }
    }

    /// The single spec the capture backends consume, or nil when nothing is ticked.
    private var resolvedSpec: DeviceStreamCaptureSpec? {
        if systemAudioSelected { return .systemAudio() }
        if let selectedDevice { return .inputDevice(selectedDevice) }
        return DeviceStreamCaptureSpec.merging(selectedApplications)
    }

    /// The button's VALUE can't be overridden, so selections are announced
    /// explicitly — otherwise a VoiceOver user gets no feedback that the
    /// choice took.
    private func announce(_ text: String) {
        // .priority must be the NSNumber rawValue, not the enum, or VoiceOver drops it.
        NSAccessibility.post(
            element: sourceButton as Any,
            notification: .announcementRequested,
            userInfo: [
                .announcement: text,
                .priority: NSAccessibilityPriorityLevel.high.rawValue
            ]
        )
    }

    // MARK: - Actions

    @objc private func browseForApplication() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.applicationBundle]
        panel.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard let bundleID = Bundle(url: url)?.bundleIdentifier, bundleID.isEmpty == false else {
            NSSound.beep()
            return
        }
        let name = FileManager.default.displayName(atPath: url.path)
            .replacingOccurrences(of: ".app", with: "")
        let spec = DeviceStreamCaptureSpec.application(bundleID: bundleID, displayName: name)
        // Kept in the list so it stays visible and checkable in the submenu.
        if applicationSources.contains(spec) == false {
            applicationSources.append(spec)
        }
        let cleared = apply(spec, selected: true)
        // One announcement: the addition, then anything the exclusions unticked.
        announce(([L10n.format("mediaStream.device.added.application", name)] + cleared)
            .joined(separator: " "))
    }

    @objc private func confirm() {
        guard let spec = resolvedSpec else {
            NSSound.beep()
            return
        }
        dismiss(nil)
        onStream?(spec, monitorCheckbox.state == .on, muteSourceCheckbox?.state == .on)
    }

    @objc private func cancel() {
        dismiss(nil)
    }
}
