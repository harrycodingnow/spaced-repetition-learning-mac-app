import AppKit
import Combine
import QuartzCore
import SwiftUI

enum IslandMetrics {
    static let expandedWidth: CGFloat = 560
    static let expandedHeight: CGFloat = 360
    static let notchCornerRadius: CGFloat = 10
}

@MainActor
final class IslandAppDelegate: NSObject, NSApplicationDelegate {
    private let store = SRLDataStore()
    private var panel: IslandPanel?
    private var islandContainer: NSView?
    private var hostingView: NSView?
    private var hoverTimer: Timer?
    private var closeTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    private var pointerWasInside = false
    private var isExpanded = false
    private var isAnimating = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureIsland()
        startHoverMonitoring()

        Task { await store.refresh() }
    }

    func applicationWillTerminate(_ notification: Notification) {
        closeTask?.cancel()
        hoverTimer?.invalidate()
    }

    private func configureIsland() {
        let screen = targetScreen()
        let collapsedFrame = collapsedFrame(on: screen)
        let panel = IslandPanel(
            contentRect: collapsedFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.level = .popUpMenu
        panel.appearance = NSAppearance(named: .darkAqua)
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.animationBehavior = .none

        let container = NSView(frame: NSRect(origin: .zero, size: collapsedFrame.size))
        container.autoresizingMask = [.width, .height]
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.clear.cgColor
        container.layer?.cornerRadius = IslandMetrics.notchCornerRadius
        container.layer?.cornerCurve = .continuous
        container.layer?.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        container.layer?.masksToBounds = true

        let rootView = RootView()
            .environmentObject(store)
            .environment(\.colorScheme, .dark)
            .preferredColorScheme(.dark)
        let hostingView = NSHostingView(rootView: rootView)
        hostingView.appearance = NSAppearance(named: .darkAqua)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        hostingView.alphaValue = 0
        hostingView.isHidden = true
        container.addSubview(hostingView)
        NSLayoutConstraint.activate([
            hostingView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            hostingView.topAnchor.constraint(equalTo: container.topAnchor),
            hostingView.widthAnchor.constraint(equalToConstant: IslandMetrics.expandedWidth),
            hostingView.heightAnchor.constraint(equalToConstant: IslandMetrics.expandedHeight),
        ])

        panel.contentView = container
        panel.setFrame(collapsedFrame, display: true)
        panel.orderFrontRegardless()

        self.panel = panel
        self.islandContainer = container
        self.hostingView = hostingView

        NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification, object: panel)
            .sink { [weak self] _ in self?.scheduleCollapse() }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .sink { [weak self] _ in self?.repositionIsland() }
            .store(in: &cancellables)
    }

    private func startHoverMonitoring() {
        let timer = Timer(
            timeInterval: 0.06,
            target: self,
            selector: #selector(pollPointerLocation),
            userInfo: nil,
            repeats: true
        )
        RunLoop.main.add(timer, forMode: .common)
        hoverTimer = timer
    }

    @objc
    private func pollPointerLocation() {
        guard let panel else { return }
        let pointerIsInside = panel.frame.insetBy(dx: -3, dy: -3).contains(NSEvent.mouseLocation)

        if pointerIsInside {
            cancelCollapse()
            if !isExpanded && !isAnimating {
                expandIsland()
            }
        } else if pointerWasInside && isExpanded {
            scheduleCollapse()
        }

        pointerWasInside = pointerIsInside
    }

    private func expandIsland() {
        guard let panel, let hostingView, let container = islandContainer else { return }
        let screen = screenContaining(panel.frame.center) ?? targetScreen()
        let anticipationFrame = notchBreathFrame(on: screen)
        let overshootFrame = expandedOvershootFrame(on: screen)
        let finalFrame = expandedFrame(on: screen)

        isExpanded = true
        isAnimating = true
        panel.hasShadow = true
        container.layer?.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        hostingView.isHidden = false
        hostingView.alphaValue = 0
        animateBackgroundColor(of: container, to: .black, duration: 0.18)
        animateCornerRadius(of: container, to: 24, duration: 0.42)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.10
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().setFrame(anticipationFrame, display: true)
        } completionHandler: { [weak self, weak panel, weak hostingView] in
            Task { @MainActor in
                guard let self, let panel, self.isExpanded else { return }
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.24
                    context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                    panel.animator().setFrame(overshootFrame, display: true)
                    hostingView?.animator().alphaValue = 0.92
                } completionHandler: { [weak self, weak panel, weak hostingView] in
                    Task { @MainActor in
                        guard let self, let panel, self.isExpanded else { return }
                        NSAnimationContext.runAnimationGroup { context in
                            context.duration = 0.11
                            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                            panel.animator().setFrame(finalFrame, display: true)
                            hostingView?.animator().alphaValue = 1
                        } completionHandler: { [weak self] in
                            Task { @MainActor in self?.isAnimating = false }
                        }
                    }
                }
            }
        }

        Task { await store.refresh() }
    }

    private func scheduleCollapse() {
        closeTask?.cancel()
        closeTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 320_000_000)
            guard !Task.isCancelled,
                  let self,
                  self.panel?.isKeyWindow != true,
                  self.isExpanded
            else {
                return
            }
            self.collapseIsland()
        }
    }

    private func cancelCollapse() {
        closeTask?.cancel()
        closeTask = nil
    }

    private func collapseIsland() {
        guard let panel, let hostingView, let container = islandContainer else { return }
        guard !isAnimating else {
            scheduleCollapse()
            return
        }
        cancelCollapse()
        let screen = screenContaining(panel.frame.center) ?? targetScreen()
        let breathFrame = notchBreathFrame(on: screen)
        let notchFrame = visibleNotchFrame(on: screen)
        let hoverFrame = collapsedFrame(on: screen)

        isExpanded = false
        isAnimating = true

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.22
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            hostingView.animator().alphaValue = 0
            panel.animator().setFrame(breathFrame, display: true)
        } completionHandler: { [weak self, weak panel, weak hostingView, weak container] in
            Task { @MainActor in
                guard let self, let panel, let container else { return }
                panel.hasShadow = false
                container.layer?.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
                self.animateCornerRadius(
                    of: container,
                    to: IslandMetrics.notchCornerRadius,
                    duration: 0.12
                )

                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.12
                    context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                    panel.animator().setFrame(notchFrame, display: true)
                } completionHandler: { [weak self, weak panel, weak hostingView, weak container] in
                    Task { @MainActor in
                        guard let self, let panel, let container else { return }
                        hostingView?.isHidden = true
                        self.animateBackgroundColor(of: container, to: .clear, duration: 0.08)
                        try? await Task.sleep(nanoseconds: 90_000_000)
                        guard !self.isExpanded else { return }
                        panel.setFrame(hoverFrame, display: true)
                        self.isAnimating = false
                    }
                }
            }
        }
    }

    private func repositionIsland() {
        guard let panel else { return }
        let screen = targetScreen()
        panel.setFrame(isExpanded ? expandedFrame(on: screen) : collapsedFrame(on: screen), display: true)
    }

    private func targetScreen() -> NSScreen {
        NSScreen.screens.first(where: { notchWidth(on: $0) != nil })
            ?? NSScreen.main
            ?? NSScreen.screens[0]
    }

    private func notchWidth(on screen: NSScreen) -> CGFloat? {
        guard let left = screen.auxiliaryTopLeftArea,
              let right = screen.auxiliaryTopRightArea
        else {
            return nil
        }
        let width = right.minX - left.maxX
        return width > 80 ? width : nil
    }

    private func collapsedFrame(on screen: NSScreen) -> NSRect {
        let width = notchWidth(on: screen) ?? 185
        let height = max(screen.safeAreaInsets.top + 10, 40)
        return NSRect(
            x: screen.frame.midX - width / 2,
            y: screen.frame.maxY - height,
            width: width,
            height: height
        )
    }

    private func visibleNotchFrame(on screen: NSScreen) -> NSRect {
        let width = notchWidth(on: screen) ?? 185
        let height = max(screen.safeAreaInsets.top, 30)
        return topAnchoredFrame(width: width, height: height, on: screen)
    }

    private func expandedFrame(on screen: NSScreen) -> NSRect {
        let width = IslandMetrics.expandedWidth
        let height = min(IslandMetrics.expandedHeight, screen.frame.height - 80)
        return NSRect(
            x: screen.frame.midX - width / 2,
            y: screen.frame.maxY - height,
            width: width,
            height: height
        )
    }

    private func notchBreathFrame(on screen: NSScreen) -> NSRect {
        let collapsed = collapsedFrame(on: screen)
        let width = collapsed.width + 42
        let height = collapsed.height + 12
        return topAnchoredFrame(width: width, height: height, on: screen)
    }

    private func expandedOvershootFrame(on screen: NSScreen) -> NSRect {
        let expanded = expandedFrame(on: screen)
        return topAnchoredFrame(
            width: expanded.width + 12,
            height: expanded.height + 6,
            on: screen
        )
    }

    private func topAnchoredFrame(width: CGFloat, height: CGFloat, on screen: NSScreen) -> NSRect {
        NSRect(
            x: screen.frame.midX - width / 2,
            y: screen.frame.maxY - height,
            width: width,
            height: height
        )
    }

    private func screenContaining(_ point: NSPoint) -> NSScreen? {
        NSScreen.screens.first { $0.frame.contains(point) }
    }

    private func animateCornerRadius(of view: NSView, to value: CGFloat, duration: TimeInterval) {
        guard let layer = view.layer else { return }
        let animation = CABasicAnimation(keyPath: "cornerRadius")
        animation.fromValue = layer.presentation()?.cornerRadius ?? layer.cornerRadius
        animation.toValue = value
        animation.duration = duration
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        layer.cornerRadius = value
        layer.add(animation, forKey: "cornerRadius")
    }

    private func animateBackgroundColor(
        of view: NSView,
        to color: NSColor,
        duration: TimeInterval
    ) {
        guard let layer = view.layer else { return }
        let targetColor = color.cgColor
        let animation = CABasicAnimation(keyPath: "backgroundColor")
        animation.fromValue = layer.presentation()?.backgroundColor ?? layer.backgroundColor
        animation.toValue = targetColor
        animation.duration = duration
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        layer.backgroundColor = targetColor
        layer.add(animation, forKey: "backgroundColor")
    }
}

private final class IslandPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

private extension NSRect {
    var center: NSPoint {
        NSPoint(x: midX, y: midY)
    }
}
