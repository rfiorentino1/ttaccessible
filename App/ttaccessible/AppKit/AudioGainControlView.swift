//
//  AudioGainControlView.swift
//  ttaccessible
//
//  Created by Mathieu Martin on 17/03/2026.
//

import AppKit

final class AudioGainControlView: NSView {
    let titleLabel = NSTextField(labelWithString: "")
    let valueLabel = NSTextField(labelWithString: "")
    let slider = AccessibleSlider(value: 50, minValue: 0, maxValue: 100, target: nil, action: nil)
    var valueDB: Double = 0
    var onChange: ((Double) -> Void)?

    init(title: String, accessibilityLabel: String, onChange: @escaping (Double) -> Void) {
        self.onChange = onChange
        super.init(frame: .zero)

        titleLabel.stringValue = title
        titleLabel.font = .preferredFont(forTextStyle: .subheadline)
        titleLabel.setContentHuggingPriority(.required, for: .horizontal)

        valueLabel.font = .monospacedDigitSystemFont(ofSize: NSFont.preferredFont(forTextStyle: .body).pointSize, weight: .regular)
        valueLabel.alignment = .right
        valueLabel.setContentHuggingPriority(.required, for: .horizontal)
        valueLabel.setAccessibilityElement(false)

        slider.numberOfTickMarks = 0
        slider.allowsTickMarkValuesOnly = false
        slider.isContinuous = true
        slider.target = self
        slider.action = #selector(handleSliderChanged(_:))
        slider.setAccessibilityElement(false)

        let stack = NSStackView(views: [titleLabel, slider, valueLabel])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        setAccessibilityElement(true)
        setAccessibilityRole(.slider)
        setAccessibilityLabel(accessibilityLabel)
        setAccessibilityMinValue(0)
        setAccessibilityMaxValue(100)
        setAccessibilityCustomActions([
            NSAccessibilityCustomAction(
                name: L10n.text("connectedServer.audio.gain.resetAccessibilityAction"),
                target: self,
                selector: #selector(resetToZeroAccessibilityAction)
            )
        ])

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            titleLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 110),
            valueLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 44)
        ])

        setValue(0)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    func setValue(_ value: Double) {
        valueDB = AppPreferences.clampGainDB(value)
        slider.doubleValue = Self.percent(forGainDB: valueDB)
        let text = Self.format(percent: slider.doubleValue)
        valueLabel.stringValue = text
        setAccessibilityValue(slider.doubleValue)
        setAccessibilityValueDescription(text)
        NSAccessibility.post(element: self, notification: .valueChanged)
    }

    override var acceptsFirstResponder: Bool {
        true
    }

    override func keyDown(with event: NSEvent) {
        guard let move = Self.levelMove(for: event.specialKey) else {
            super.keyDown(with: event)
            return
        }
        apply(move)
    }

    /// The same key→distance table the mixer uses, so a level moves by the same amount
    /// whichever route reaches it. Home was jumping to 0 % here and to 100 % in the mixer.
    private static func levelMove(for key: NSEvent.SpecialKey?) -> MixerLevelMove? {
        switch key {
        case .leftArrow, .downArrow: return .step(up: false)
        case .rightArrow, .upArrow: return .step(up: true)
        case .pageUp: return .page(up: true)
        case .pageDown: return .page(up: false)
        case .home: return .toMax
        case .end: return .toMin
        default: return nil
        }
    }

    override func accessibilityPerformIncrement() -> Bool {
        apply(.step(up: true))
        return true
    }

    override func accessibilityPerformDecrement() -> Bool {
        apply(.step(up: false))
        return true
    }

    override func accessibilityPerformPress() -> Bool {
        // VoiceOver double-tap resets the gain to unity (0 dB = 50% on the slider),
        // matching the channel mixer's reset-on-press.
        resetToZeroAccessibilityAction()
    }

    override func accessibilityChildren() -> [Any]? {
        []
    }

    override func accessibilityHitTest(_ point: NSPoint) -> Any? {
        self
    }

    @objc
    func resetToZeroAccessibilityAction() -> Bool {
        setValue(0)
        onChange?(0)
        return true
    }

    @objc
    func handleSliderChanged(_ sender: NSSlider) {
        let gainDB = Self.gainDB(forPercent: sender.doubleValue)
        setValue(gainDB)
        onChange?(valueDB)
    }

    /// Move this level and return the value to speak.
    @discardableResult
    func apply(_ move: MixerLevelMove) -> String {
        setAndNotify(Self.gainDB(forPercent: move.apply(to: slider.doubleValue)))
        return Self.format(percent: slider.doubleValue)
    }

    /// Move and describe, for the window-wide Cmd+arrow / Cmd+Shift+arrow shortcuts.
    func adjustAndDescribe(move: MixerLevelMove) -> String { apply(move) }

    func setAndNotify(_ value: Double) {
        guard value != valueDB else {
            return
        }
        setValue(value)
        onChange?(valueDB)
    }

    static func percent(forGainDB value: Double) -> Double {
        ((AppPreferences.clampGainDB(value) + 24) / 48 * 100).rounded()
    }

    static func gainDB(forPercent value: Double) -> Double {
        let clamped = min(max(value.rounded(), 0), 100)
        return AppPreferences.clampGainDB((clamped / 100 * 48) - 24)
    }

    static func format(percent value: Double) -> String {
        String(format: "%.0f%%", min(max(value.rounded(), 0), 100))
    }
}
