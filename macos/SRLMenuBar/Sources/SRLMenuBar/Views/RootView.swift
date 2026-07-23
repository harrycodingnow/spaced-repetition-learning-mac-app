import AppKit
import SwiftUI

private enum AppTab: String, CaseIterable, Identifiable {
    case today = "Today"
    case calendar = "Calendar"
    case activity = "Activity"
    case route = "Route"

    var id: String { rawValue }
}

struct RootView: View {
    @EnvironmentObject private var store: SRLDataStore
    @State private var selectedTab: AppTab = .today

    var body: some View {
        VStack(spacing: 0) {
            header

            if let error = store.errorMessage {
                StatusBanner(text: error, isError: true) {
                    store.errorMessage = nil
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            } else if let notice = store.notice {
                StatusBanner(text: notice, isError: false) {
                    store.notice = nil
                }
                .padding(.horizontal, 16)
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
        .frame(width: IslandMetrics.expandedWidth, height: IslandMetrics.expandedHeight)
        .background(Color.black)
        .foregroundColor(.white)
        .colorScheme(.dark)
        .task {
            await store.refresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            Task { await store.refresh() }
        }
    }

    private var header: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "brain.head.profile")
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.green)

                Text("Spaced Repetition")
                    .font(.subheadline.weight(.semibold))

                Spacer()

                Text("\(store.dueToday.count) due · \(store.routeCompletedCount)/\(store.route.count)")
                    .font(.caption2)
                    .foregroundColor(Color.white.opacity(0.58))

                if store.isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: 18)
                } else {
                    Button {
                        Task { await store.refresh() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.borderless)
                    .frame(width: 18)
                    .help("Reload ~/.srl data")
                }
            }
            .frame(height: 38)

            Picker("View", selection: $selectedTab) {
                ForEach(AppTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private var footer: some View {
        HStack {
            Button {
                NSWorkspace.shared.open(store.dataDirectory)
            } label: {
                Label("Open data", systemImage: "folder")
            }
            .buttonStyle(.borderless)

            Spacer()

            Text("Uses ~/.srl")
                .font(.caption2)
                .foregroundColor(Color.white.opacity(0.58))

            Spacer()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.borderless)
        }
        .font(.caption)
        .padding(.horizontal, 16)
        .frame(height: 30)
        .background(Color.white.opacity(0.055))
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
        .foregroundColor(isError ? .red : .green)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill((isError ? Color.red : Color.green).opacity(0.10))
        )
    }
}
