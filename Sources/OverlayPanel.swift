import Cocoa

/// A non-activating floating pill overlay that shows the current dictation state.
/// Appears during recording and transcribing; invisible during idle and error.
final class OverlayPanel: NSPanel {

    // MARK: - Subviews

    private let blurView: NSVisualEffectView
    private let symbolView: NSImageView
    private let label: NSTextField

    // MARK: - Layout constants

    private enum Layout {
        static let pillHeight: CGFloat = 36
        static let horizontalPadding: CGFloat = 16
        static let symbolSize: CGFloat = 16
        static let symbolLabelGap: CGFloat = 6
        static let topMarginBelowMenuBar: CGFloat = 8
        static let cornerRadius: CGFloat = 18 // pillHeight / 2
    }

    // MARK: - Init

    init() {
        blurView = NSVisualEffectView()
        symbolView = NSImageView()
        label = NSTextField(labelWithString: "")

        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )

        configurePanel()
        buildViewHierarchy()
    }

    // MARK: - Public API

    enum DisplayState {
        case recording
        case transcribing
    }

    /// Show with the given state, fading in if currently hidden.
    func show(state: DisplayState) {
        let (symbolName, labelText) = content(for: state)
        updateContent(symbolName: symbolName, text: labelText)
        repositionAtTopCenter()

        if !isVisible {
            alphaValue = 0
            orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.18
                ctx.timingFunction = .init(name: .easeIn)
                self.animator().alphaValue = 1
            }
        }
    }

    /// Fade out and hide.
    func hide() {
        guard isVisible else { return }

        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.22
            ctx.timingFunction = .init(name: .easeOut)
            self.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            self?.orderOut(nil)
        })
    }

    // MARK: - NSWindow overrides

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    // MARK: - Private setup

    private func configurePanel() {
        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        collectionBehavior = [
            .canJoinAllSpaces,
            .stationary,
            .ignoresCycle,
            .fullScreenAuxiliary,
        ]
        isMovable = false
        isReleasedWhenClosed = false
    }

    private func buildViewHierarchy() {
        blurView.material = .hudWindow
        blurView.blendingMode = .behindWindow
        blurView.state = .active
        blurView.wantsLayer = true
        blurView.layer?.cornerRadius = Layout.cornerRadius
        blurView.layer?.masksToBounds = true

        symbolView.imageScaling = .scaleProportionallyDown
        symbolView.contentTintColor = .white
        symbolView.setContentHuggingPriority(.required, for: .horizontal)

        label.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        label.textColor = .white
        label.alignment = .left
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)

        let stack = NSStackView(views: [symbolView, label])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = Layout.symbolLabelGap
        stack.edgeInsets = NSEdgeInsets(
            top: 0,
            left: Layout.horizontalPadding,
            bottom: 0,
            right: Layout.horizontalPadding
        )
        stack.translatesAutoresizingMaskIntoConstraints = false

        blurView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: blurView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: blurView.trailingAnchor),
            stack.topAnchor.constraint(equalTo: blurView.topAnchor),
            stack.bottomAnchor.constraint(equalTo: blurView.bottomAnchor),
        ])

        contentView = blurView
    }

    // MARK: - Content helpers

    private func content(for state: DisplayState) -> (symbolName: String, text: String) {
        switch state {
        case .recording: return ("mic.fill", "Recording...")
        case .transcribing: return ("ellipsis.circle", "Transcribing...")
        }
    }

    private func updateContent(symbolName: String, text: String) {
        let config = NSImage.SymbolConfiguration(pointSize: Layout.symbolSize, weight: .medium)
        symbolView.image = NSImage(
            systemSymbolName: symbolName,
            accessibilityDescription: nil
        )?.withSymbolConfiguration(config)
        label.stringValue = text
        resizeToFitContent()
    }

    private func resizeToFitContent() {
        blurView.layoutSubtreeIfNeeded()
        let fittingWidth = blurView.fittingSize.width
        setContentSize(CGSize(width: fittingWidth, height: Layout.pillHeight))
    }

    private func repositionAtTopCenter() {
        guard let screen = NSScreen.main else { return }
        let visibleFrame = screen.visibleFrame
        let screenFrame = screen.frame

        let menuBarBottom = visibleFrame.maxY
        let overlayY = menuBarBottom - Layout.pillHeight - Layout.topMarginBelowMenuBar
        let centeredX = screenFrame.midX - frame.width / 2

        setFrameOrigin(NSPoint(x: centeredX, y: overlayY))
    }
}
