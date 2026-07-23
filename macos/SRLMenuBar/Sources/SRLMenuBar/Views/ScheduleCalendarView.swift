import SwiftUI

struct ScheduleCalendarView: View {
    @EnvironmentObject private var store: SRLDataStore
    @State private var visibleMonth = Calendar.current.date(
        from: Calendar.current.dateComponents([.year, .month], from: Date())
    ) ?? Date()
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
            VStack(spacing: 12) {
                SectionCard("Future review schedule", systemImage: "calendar.badge.clock") {
                    monthControls
                    weekdayHeader
                    monthGrid
                }

                selectedDayCard
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
    }

    private var monthControls: some View {
        HStack {
            Button {
                moveMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.borderless)

            Spacer()

            Button(visibleMonth.formatted(.dateTime.month(.wide).year())) {
                visibleMonth = monthStart(for: Date())
                selectedDate = calendar.startOfDay(for: Date())
            }
            .buttonStyle(.borderless)
            .font(.headline)

            Spacer()

            Button {
                moveMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(.borderless)
        }
    }

    private var weekdayHeader: some View {
        LazyVGrid(columns: columns, spacing: 5) {
            ForEach(calendar.veryShortStandaloneWeekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(Color.white.opacity(0.58))
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var monthGrid: some View {
        LazyVGrid(columns: columns, spacing: 5) {
            ForEach(Array(monthCells.enumerated()), id: \.offset) { _, date in
                if let date {
                    dayCell(date)
                } else {
                    Color.clear
                        .frame(height: 48)
                }
            }
        }
    }

    private func dayCell(_ date: Date) -> some View {
        let normalizedDate = calendar.startOfDay(for: date)
        let problems = store.scheduledByDay[normalizedDate, default: []]
        let isSelected = calendar.isDate(normalizedDate, inSameDayAs: selectedDate)
        let isToday = calendar.isDateInToday(normalizedDate)

        return Button {
            selectedDate = normalizedDate
        } label: {
            VStack(spacing: 3) {
                Text("\(calendar.component(.day, from: normalizedDate))")
                    .font(.caption.monospacedDigit().weight(isToday ? .bold : .regular))
                    .foregroundColor(.white)

                if problems.isEmpty {
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 5, height: 5)
                } else {
                    Text("\(problems.count)")
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .foregroundColor(isSelected ? .white : .green)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? Color.green : cellBackground(problems: problems, isToday: isToday))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isToday && !isSelected ? Color.green : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .help(problems.isEmpty ? "No review scheduled" : "\(problems.count) review(s)")
    }

    private var selectedDayCard: some View {
        let problems = store.scheduledByDay[calendar.startOfDay(for: selectedDate), default: []]

        return SectionCard(
            selectedDate.formatted(.dateTime.weekday(.wide).month(.wide).day()),
            systemImage: "list.bullet"
        ) {
            if problems.isEmpty {
                Text("No questions are scheduled for this day.")
                    .font(.subheadline)
                    .foregroundColor(Color.white.opacity(0.58))
            } else {
                ForEach(problems) { problem in
                    HStack {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 6, height: 6)
                        Text(problem.name)
                            .font(.subheadline)
                        Spacer()
                        ExternalLinkButton(urlString: problem.url)
                    }
                }
            }

            Text("The calendar shows each in-progress question's next known review. Later reviews depend on the rating you give next time.")
                .font(.caption2)
                .foregroundColor(Color.white.opacity(0.58))
                .padding(.top, 2)
        }
    }

    private var monthCells: [Date?] {
        let start = monthStart(for: visibleMonth)
        guard let dayRange = calendar.range(of: .day, in: .month, for: start) else { return [] }
        let leadingBlanks = calendar.component(.weekday, from: start) - 1
        let blanks: [Date?] = Array(repeating: nil, count: leadingBlanks)
        let days: [Date?] = dayRange.compactMap { day in
            calendar.date(byAdding: .day, value: day - 1, to: start)
        }
        return blanks + days
    }

    private func moveMonth(by value: Int) {
        let newMonth = calendar.date(byAdding: .month, value: value, to: visibleMonth) ?? visibleMonth
        visibleMonth = newMonth
        selectedDate = monthStart(for: newMonth)
    }

    private func monthStart(for date: Date) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
    }

    private func cellBackground(problems: [PracticeProblem], isToday: Bool) -> Color {
        if !problems.isEmpty { return Color.green.opacity(0.13) }
        if isToday { return Color.green.opacity(0.05) }
        return Color.white.opacity(0.055)
    }
}
