import SwiftUI

struct ScheduleCalendarView: View {
    @EnvironmentObject private var store: SRLDataStore
    @State private var visibleWeekAnchor = Date()
    @State private var selectedDate = Calendar.current.startOfDay(for: Date())

    private var calendar: Calendar {
        var calendar = Calendar.current
        calendar.firstWeekday = 1
        return calendar
    }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 5), count: 7)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                SectionCard("Review week", systemImage: "calendar.badge.clock") {
                    weekControls
                    weekGrid
                }

                selectedDayCard
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 12)
        }
    }

    private var weekControls: some View {
        HStack {
            weekButton(systemImage: "chevron.left", help: "Previous week") {
                moveWeek(by: -1)
            }

            Spacer()

            Button {
                visibleWeekAnchor = Date()
                selectedDate = calendar.startOfDay(for: Date())
            } label: {
                Text(weekRangeTitle)
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .padding(.horizontal, 10)
                    .frame(height: 24)
                    .contentShape(Capsule(style: .continuous))
                    .liquidGlassSurface(
                        cornerRadius: 12,
                        tint: LiquidTheme.accent.opacity(0.035),
                        interactive: true
                    )
            }
            .buttonStyle(.plain)
            .help("Return to this week")
            .accessibilityLabel("Week \(weekRangeTitle)")
            .accessibilityHint("Return to the current week")

            Spacer()

            weekButton(systemImage: "chevron.right", help: "Next week") {
                moveWeek(by: 1)
            }
        }
        .frame(height: 20)
    }

    private func weekButton(
        systemImage: String,
        help: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundColor(Color.white.opacity(0.78))
                .frame(width: 16, height: 16)
                .contentShape(Rectangle())
        }
        .liquidButtonStyle()
        .controlSize(.mini)
        .help(help)
        .accessibilityLabel(help)
    }

    private var weekGrid: some View {
        LazyVGrid(columns: columns, spacing: 5) {
            ForEach(weekDates, id: \.self) { date in
                dayCell(date)
            }
        }
    }

    private func dayCell(_ date: Date) -> some View {
        let normalizedDate = calendar.startOfDay(for: date)
        let isPast = isPastDay(normalizedDate)
        let problems = problems(on: normalizedDate, isPast: isPast)
        let isSelected = calendar.isDate(normalizedDate, inSameDayAs: selectedDate)
        let isToday = calendar.isDateInToday(normalizedDate)
        let countDescription = isPast
            ? "\(problems.count) question\(problems.count == 1 ? "" : "s") finished"
            : "\(problems.count) review\(problems.count == 1 ? "" : "s") scheduled"

        return Button {
            selectedDate = normalizedDate
        } label: {
            VStack(spacing: 3) {
                Text(normalizedDate.formatted(.dateTime.weekday(.narrow)))
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundColor(isSelected ? .white : LiquidTheme.secondaryText)

                Text("\(calendar.component(.day, from: normalizedDate))")
                    .font(.caption.monospacedDigit().weight(isToday ? .bold : .medium))
                    .foregroundColor(.white)

                HStack(spacing: 2) {
                    Image(systemName: isPast ? "checkmark" : "clock")
                    Text("\(problems.count)")
                }
                .font(.system(size: 8, weight: .bold, design: .rounded))
                .foregroundColor(isSelected ? .white : LiquidTheme.accent)
                .frame(height: 9)
                .opacity(problems.isEmpty ? 0 : 1)
            }
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(
                        isSelected
                            ? LiquidTheme.accent.opacity(0.24)
                            : cellBackground(hasItems: !problems.isEmpty, isToday: isToday)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(
                        isSelected
                            ? Color.white.opacity(0.18)
                            : (isToday ? LiquidTheme.accent.opacity(0.85) : Color.white.opacity(0.07)),
                        lineWidth: isToday ? 1 : 0.6
                    )
            )
            .shadow(
                color: isSelected ? LiquidTheme.accent.opacity(0.18) : .clear,
                radius: 6,
                y: 2
            )
        }
        .buttonStyle(.plain)
        .help(problems.isEmpty ? (isPast ? "No questions finished" : "No reviews scheduled") : countDescription)
        .accessibilityLabel(
            "\(normalizedDate.formatted(date: .complete, time: .omitted)), \(countDescription)"
        )
        .accessibilityValue(
            [isToday ? "Today" : nil, isSelected ? "Selected" : nil]
                .compactMap { $0 }
                .joined(separator: ", ")
        )
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var selectedDayCard: some View {
        let normalizedDate = calendar.startOfDay(for: selectedDate)
        let isPast = isPastDay(normalizedDate)
        let problems = problems(on: normalizedDate, isPast: isPast)

        return SectionCard(
            selectedDate.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()),
            systemImage: isPast ? "checkmark.circle" : "calendar.badge.clock",
            showsBackground: false
        ) {
            if problems.isEmpty {
                Text(isPast ? "No questions finished." : "No questions scheduled.")
                    .font(.subheadline)
                    .foregroundColor(LiquidTheme.secondaryText)
            } else {
                ForEach(problems) { problem in
                    HStack(spacing: 8) {
                        Image(systemName: isPast ? "checkmark.circle.fill" : "circle")
                            .font(.caption)
                            .foregroundColor(
                                isPast ? LiquidTheme.accent : LiquidTheme.secondaryText
                            )
                        Text(problem.name)
                            .font(.subheadline)
                            .lineLimit(1)
                        Spacer(minLength: 8)
                        if isPast, let rating = problem.lastRating {
                            Text("\(rating)/5")
                                .font(.caption2.monospacedDigit().weight(.semibold))
                                .foregroundColor(LiquidTheme.secondaryText)
                                .padding(.horizontal, 5)
                                .frame(height: 16)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(Color.white.opacity(0.06))
                                )
                        }
                        ExternalLinkButton(urlString: problem.url)
                    }
                }
            }
        }
    }

    private var weekStart: Date {
        calendar.dateInterval(of: .weekOfYear, for: visibleWeekAnchor)?.start
            ?? calendar.startOfDay(for: visibleWeekAnchor)
    }

    private var weekDates: [Date] {
        (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: weekStart)
        }
    }

    private var weekRangeTitle: String {
        guard let firstDate = weekDates.first, let lastDate = weekDates.last else { return "This week" }

        let formatter = DateIntervalFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: firstDate, to: lastDate)
    }

    private func moveWeek(by value: Int) {
        visibleWeekAnchor = calendar.date(
            byAdding: .weekOfYear,
            value: value,
            to: visibleWeekAnchor
        ) ?? visibleWeekAnchor
        selectedDate = calendar.date(
            byAdding: .weekOfYear,
            value: value,
            to: selectedDate
        ) ?? selectedDate
    }

    private func isPastDay(_ date: Date) -> Bool {
        date < calendar.startOfDay(for: Date())
    }

    private func problems(on date: Date, isPast: Bool) -> [PracticeProblem] {
        if isPast {
            return store.finishedByDay[date, default: []]
        }
        return store.scheduledByDay[date, default: []]
    }

    private func cellBackground(hasItems: Bool, isToday: Bool) -> Color {
        if hasItems { return LiquidTheme.accent.opacity(0.12) }
        if isToday { return LiquidTheme.accent.opacity(0.055) }
        return Color.white.opacity(0.04)
    }
}
