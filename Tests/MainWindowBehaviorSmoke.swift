import AppKit

@main
enum MainWindowBehaviorSmoke {
    static func main() {
        _ = NSApplication.shared
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 456, height: 272),
            styleMask: MainWindowBehavior.windowStyleMask,
            backing: .buffered,
            defer: false
        )

        precondition(!MainWindowBehavior.terminatesAfterLastWindowClosed)
        precondition(MainWindowBehavior.windowStyleMask.contains(.miniaturizable))
        precondition(InterfaceMotion.quickDuration == 0.16)
        precondition(InterfaceMotion.standardDuration == 0.22)
        precondition(InterfaceMotion.windowOffset == 6)
        switch MainWindowBehavior.activationPolicy {
        case .regular:
            break
        case .accessory, .prohibited:
            preconditionFailure("Dock activation policy is unavailable")
        @unknown default:
            preconditionFailure("Unknown activation policy")
        }
        switch MainWindowBehavior.closeAction {
        case .hide:
            break
        }
        MainWindowBehavior.show(window, animated: false)
        precondition(window.isVisible)
        precondition(MainWindowBehavior.handleClose(window, animated: false) == false)
        precondition(!window.isVisible)
        print("OK window-motion=show-hide minimize=native dock=regular")
    }
}
