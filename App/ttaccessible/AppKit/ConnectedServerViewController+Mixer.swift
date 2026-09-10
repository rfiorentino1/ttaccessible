//
//  ConnectedServerViewController+Mixer.swift
//  ttaccessible
//
//  Embeds the Channel Mixer as an inline section in the main connected-server window.
//  The visible heading + (placeholder) area sit alongside the invisible virtual-
//  accessibility overlay (channelMixerCoordinator.overlay), which is what VoiceOver
//  navigates: Mixer → per-user strip → controls. Fed by update(session:).
//

#if os(macOS)
import AppKit
import SwiftUI

extension ConnectedServerViewController {
    func buildChannelMixerSection() -> NSView {
        // The visible (sighted/mouse) SwiftUI strips, with the invisible virtual-
        // accessibility overlay laid over them — VoiceOver navigates the overlay, mouse
        // users see/use the SwiftUI. The overlay supplies the "Mixer / area" label+role.
        let hosting = NSHostingView(rootView: ChannelMixerView(coordinator: channelMixerCoordinator))
        hosting.translatesAutoresizingMaskIntoConstraints = false
        // Without this the hosting view keeps the height it was first measured at, and the
        // mixer overflows onto its neighbours as strips appear (seen on screen: Mute/Solo
        // printed over the chat heading).
        if #available(macOS 13.0, *) { hosting.sizingOptions = [.intrinsicContentSize] }
        // mainStack is pinned to all four edges of a window that is often too short for
        // everything it holds, so the mixer gets compressed — and SwiftUI happily draws
        // outside its bounds, printing the strips over the channel tree and the chat
        // heading. Clip it: a squeezed mixer must lose its own bottom, never scribble on
        // its neighbours.
        hosting.wantsLayer = true
        hosting.layer?.masksToBounds = true
        // Lowest hugging in the stack, so the mixer is what absorbs any spare height —
        // between the floor and ceiling set on the section in the window's layout.
        hosting.setContentHuggingPriority(.init(rawValue: 1), for: .vertical)
        hosting.setContentCompressionResistancePriority(.init(rawValue: 1), for: .vertical)
        // SwiftUI's accessibilityHidden hides the CONTENT, but the hosting view itself
        // stayed in the AX tree as an empty group sharing the overlay's exact frame. Two
        // elements at one position: VoiceOver kept the empty one going forward and the
        // mixer going backward, so VO+Right skipped the mixer entirely. The visible
        // rendering must be invisible to VoiceOver, container included.
        hosting.setAccessibilityElement(false)

        let overlay = channelMixerCoordinator.overlay
        overlay.translatesAutoresizingMaskIntoConstraints = false

        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(hosting)
        container.addSubview(overlay)
        NSLayoutConstraint.activate([
            hosting.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            hosting.topAnchor.constraint(equalTo: container.topAnchor),
            hosting.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            overlay.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            overlay.topAnchor.constraint(equalTo: container.topAnchor),
            overlay.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        // Install the mixer keyboard model (Cmd+arrows master, arrows volume/pan, p/v/m/s).
        // The monitor only acts while VoiceOver is focused inside the mixer.
        channelMixerKeyboardController.start()
        return container
    }

}

#endif
