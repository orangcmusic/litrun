import AppKit
import QuartzCore

enum InterfaceMotion {
    static let quickDuration: TimeInterval = 0.16
    static let standardDuration: TimeInterval = 0.22
    static let windowOffset: CGFloat = 6
    static var enabledOverrideForTesting: Bool?

    static var isEnabled: Bool {
        enabledOverrideForTesting
            ?? !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    static func animate(
        duration: TimeInterval = quickDuration,
        changes: @escaping () -> Void,
        completion: (() -> Void)? = nil
    ) {
        guard isEnabled else {
            changes()
            completion?()
            return
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            context.allowsImplicitAnimation = true
            changes()
        } completionHandler: {
            completion?()
        }
    }
}

enum MainWindowBehavior {
    enum CloseAction {
        case hide
    }

    static let terminatesAfterLastWindowClosed = false
    static let closeAction = CloseAction.hide
    static let activationPolicy = NSApplication.ActivationPolicy.regular
    static let windowStyleMask: NSWindow.StyleMask = [
        .titled,
        .closable,
        .miniaturizable,
        .fullSizeContentView
    ]

    static func show(_ window: NSWindow, animated: Bool = true) {
        if window.isMiniaturized {
            window.deminiaturize(nil)
            return
        }
        guard !window.isVisible else {
            window.makeKeyAndOrderFront(nil)
            return
        }
        let targetOrigin = window.frame.origin
        let shouldAnimate = animated && InterfaceMotion.isEnabled
        if shouldAnimate {
            window.alphaValue = 0
            window.setFrameOrigin(
                NSPoint(
                    x: targetOrigin.x,
                    y: targetOrigin.y - InterfaceMotion.windowOffset
                )
            )
        }
        window.makeKeyAndOrderFront(nil)
        guard shouldAnimate else {
            window.alphaValue = 1
            return
        }
        InterfaceMotion.animate(duration: InterfaceMotion.standardDuration) {
            window.animator().alphaValue = 1
            window.animator().setFrameOrigin(targetOrigin)
        } completion: {
            window.alphaValue = 1
            window.setFrameOrigin(targetOrigin)
        }
    }

    static func handleClose(_ window: NSWindow, animated: Bool = true) -> Bool {
        switch closeAction {
        case .hide:
            let targetOrigin = window.frame.origin
            guard animated && InterfaceMotion.isEnabled else {
                window.orderOut(nil)
                return false
            }
            InterfaceMotion.animate(duration: InterfaceMotion.quickDuration) {
                window.animator().alphaValue = 0
                window.animator().setFrameOrigin(
                    NSPoint(
                        x: targetOrigin.x,
                        y: targetOrigin.y - InterfaceMotion.windowOffset
                    )
                )
            } completion: {
                window.orderOut(nil)
                window.alphaValue = 1
                window.setFrameOrigin(targetOrigin)
            }
        }
        return false
    }
}
