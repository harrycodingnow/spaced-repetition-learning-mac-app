import SwiftUI

struct ActivityHeatmap: View {
    let counts: [Date: Int]
    let weeks: Int
    var cellSize: CGFloat = 11

    private var calendar: Calendar {
        var calendar = Calendar.current
        calendar.firstWeekday = 1
        return calendar
    }

    private var today: Date {
        calendar.startOfDay(for: Date())
    }

    private var firstDay: Date {
        let weekday = calendar.component(.weekday, from: today)
        let currentSunday = calendar.date(byAdding: .day, value: -(weekday - 1), to: today) ?? today
        return calendar.date(byAdding: .weekOfYear, value: -(weeks - 1), to: currentSunday) ?? currentSunday
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 7) {
                VStack(spacing: 3) {
                    ForEach(0..<7, id: \.self) { day in
                        Text(weekdayLabel(day))
                            .font(.system(size: 8, design: .monospaced))
                            .foregroundColor(LiquidTheme.secondaryText)
                            .frame(width: 22, height: cellSize)
                    }
                }

                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 3) {
                            ForEach(0..<weeks, id: \.self) { week in
                                VStack(spacing: 3) {
                                    ForEach(0..<7, id: \.self) { weekday in
                                        let offset = week * 7 + weekday
                                        let date = calendar.date(byAdding: .day, value: offset, to: firstDay) ?? firstDay
                                        let normalizedDate = calendar.startOfDay(for: date)
                                        let count = counts[normalizedDate, default: 0]

                                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                                            .fill(normalizedDate > today ? Color.clear : color(for: count))
                                            .frame(width: cellSize, height: cellSize)
                                            .help("\(SRLDay.string(normalizedDate)): \(count) attempt\(count == 1 ? "" : "s")")
                                            .accessibilityLabel("\(SRLDay.string(normalizedDate)), \(count) attempts")
                                            .accessibilityHidden(normalizedDate > today)
                                    }
                                }
                                .id(week)
                            }
                        }
                    }
                    .onAppear {
                        proxy.scrollTo(max(weeks - 1, 0), anchor: .trailing)
                    }
                }
            }

            HStack(spacing: 5) {
                Spacer()
                Text("Less")
                ForEach(0..<4, id: \.self) { level in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color(for: level))
                        .frame(width: 10, height: 10)
                }
                Text("More")
            }
            .font(.caption2)
            .foregroundColor(LiquidTheme.secondaryText)
        }
    }

    private func color(for count: Int) -> Color {
        switch count {
        case 0: return Color.white.opacity(0.09)
        case 1: return LiquidTheme.accent.opacity(0.36)
        case 2: return LiquidTheme.accent.opacity(0.66)
        default: return LiquidTheme.accent
        }
    }

    private func weekdayLabel(_ index: Int) -> String {
        switch index {
        case 1: return "M"
        case 3: return "W"
        case 5: return "F"
        default: return ""
        }
    }
}
