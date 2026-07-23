import SwiftUI

struct ActivityView: View {
    @EnvironmentObject private var store: SRLDataStore

    private var auditPasses: Int {
        store.snapshot.audit.history.filter { $0.result == "pass" }.count
    }

    private var auditFailures: Int {
        store.snapshot.audit.history.filter { $0.result == "fail" }.count
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    MetricTile(
                        value: "\(store.totalAttempts)",
                        label: "Total attempts",
                        color: .cyan
                    )
                    MetricTile(
                        value: "\(store.snapshot.mastered.count)",
                        label: "Mastered",
                        color: .green
                    )
                    MetricTile(
                        value: "\(store.snapshot.inProgress.count)",
                        label: "In progress",
                        color: .orange
                    )
                }

                SectionCard("Past 52 weeks", systemImage: "calendar") {
                    ActivityHeatmap(counts: store.activityCounts, weeks: 52, cellSize: 11)
                    Text("Each square counts completed attempts. Darker green means more practice.")
                        .font(.caption)
                        .foregroundColor(Color.white.opacity(0.58))
                }

                SectionCard("Audit stats", systemImage: "checkmark.shield") {
                    if auditPasses + auditFailures == 0 {
                        Text("No audits yet.")
                            .font(.subheadline)
                            .foregroundColor(Color.white.opacity(0.58))
                    } else {
                        HStack(spacing: 16) {
                            Label("\(auditPasses) passed", systemImage: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Label("\(auditFailures) failed", systemImage: "xmark.circle.fill")
                                .foregroundColor(.red)
                        }
                        .font(.subheadline)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
    }
}
