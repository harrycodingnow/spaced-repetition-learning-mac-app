import AppKit
import SwiftUI

private enum AppTab: String, CaseIterable, Identifiable {
    case today = "Today"
    case calendar = "Calendar"
    case activity = "Activity"
    case route = "Route"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .today: return "checkmark.circle"
        case .calendar: return "calendar"
        case .activity: return "chart.xyaxis.line"
        case .route: return "point.topleft.down.curvedto.point.bottomright.up"
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var store: SRLDataStore
    @State private var selectedTab: AppTab = .today
    @Namespace private var tabSelection

    var body: some View {
        ZStack {
            LiquidBackdrop()

            VStack(spacing: 0) {
                header

                if let error = store.errorMessage {
                    StatusBanner(text: error, isError: true) {
                        store.errorMessage = nil
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 8)
                }

                Group {
                    switch selectedTab {
                    case .today:
                        TodayView()
                    case .calendar:
                        ScheduleCalendarView()
                    case .activity:
                        ActivityView()
                    case .route:
                        RouteView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                footer
            }
        }
        .frame(width: IslandMetrics.expandedWidth, height: IslandMetrics.expandedHeight)
        .clipped()
        .foregroundColor(.white)
        .colorScheme(.dark)
        .task {
            await store.refresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            Task { await store.refresh() }
        }
        .onChange(of: store.notice) { notice in
            guard let notice else { return }
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 2_200_000_000)
                guard store.notice == notice else { return }
                withAnimation(.easeOut(duration: 0.18)) {
                    store.notice = nil
                }
            }
        }
    }

    private var header: some View {
        VStack(spacing: 5) {
            HStack(spacing: 8) {
                Image(systemName: "brain.head.profile")
                    .font(.subheadline.weight(.semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundColor(LiquidTheme.accent)
                    .frame(width: 24, height: 24)
                    .background(
                        Circle()
                            .fill(LiquidTheme.accent.opacity(0.12))
                    )

                Text("Spaced Repetition")
                    .font(.subheadline.weight(.semibold))

                Spacer()

                Text("\(store.dueToday.count) due · \(store.routeCompletedCount)/\(store.route.count)")
                    .font(.caption2)
                    .foregroundColor(LiquidTheme.secondaryText)

                if store.isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: 24)
                } else {
                    Button {
                        Task { await store.refresh() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption.weight(.semibold))
                            .frame(width: 16, height: 16)
                    }
                    .liquidButtonStyle()
                    .controlSize(.mini)
                    .help("Reload ~/.srl data")
                }
            }
            .frame(height: 34)

            HStack(spacing: 2) {
                ForEach(AppTab.allCases) { tab in
                    Button {
                        withAnimation(.easeInOut(duration: 0.20)) {
                            selectedTab = tab
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: tab.systemImage)
                                .font(.system(size: 10, weight: .semibold))
                            Text(tab.rawValue)
                                .font(.caption.weight(.medium))
                        }
                        .foregroundColor(
                            selectedTab == tab ? .white : LiquidTheme.secondaryText
                        )
                        .frame(maxWidth: .infinity)
                        .frame(height: 24)
                        .background {
                            if selectedTab == tab {
                                Capsule(style: .continuous)
                                    .fill(LiquidTheme.accent.opacity(0.18))
                                    .overlay {
                                        Capsule(style: .continuous)
                                            .stroke(Color.white.opacity(0.12), lineWidth: 0.6)
                                    }
                                    .matchedGeometryEffect(id: "selected-tab", in: tabSelection)
                            }
                        }
                        .contentShape(Capsule(style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selectedTab == tab ? .isSelected : [])
                }
            }
            .padding(3)
            .liquidGlassSurface(cornerRadius: 14, tint: Color.white.opacity(0.025))
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 8)
    }

    private var footer: some View {
        ZStack {
            Text("Uses ~/.srl")
                .font(.caption2)
                .foregroundColor(LiquidTheme.tertiaryText)

            HStack {
                Button {
                    NSWorkspace.shared.open(store.dataDirectory)
                } label: {
                    Label("Open data", systemImage: "folder")
                }
                .buttonStyle(.plain)
                .foregroundColor(LiquidTheme.secondaryText)

                Spacer()

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.plain)
                .foregroundColor(LiquidTheme.secondaryText)
            }
        }
        .font(.caption)
        .padding(.horizontal, 14)
        .frame(height: 30)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.white.opacity(0.10))
                .frame(height: 0.5)
        }
    }
}

private struct StatusBanner: View {
    let text: String
    let isError: Bool
    let dismiss: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
            Text(text)
                .font(.caption)
                .lineLimit(2)
            Spacer()
            Button(action: dismiss) {
                Image(systemName: "xmark")
            }
            .buttonStyle(.borderless)
        }
        .foregroundColor(isError ? .red : LiquidTheme.accent)
        .padding(10)
        .liquidGlassSurface(
            cornerRadius: 12,
            tint: (isError ? Color.red : LiquidTheme.accent).opacity(0.08)
        )
    }
}
