// CalendarView.swift — Screen 14
//
// Read-only month view for the artist. Port of `CalendarScreen` at
// ios-app.jsx line 1279.
//
// Distinct from the tappable AvailabilityView in screen 21 — this one
// is a pure month-overview where booked + blocked dates are marked
// with dots and tapping navigates to the relevant booking detail.
// Think of it as the artist's version of the promoter's Bookings tab
// expressed spatially.

import SwiftUI
import DesignSystem

public struct CalendarView: View {
    @Bindable var nav: NavigationModel

    @State private var visibleMonth: Date = Date()

    public init(nav: NavigationModel) {
        self.nav = nav
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.horizontal, R.S.lg)
                    .padding(.top, R.S.sm)
                monthNav
                    .padding(.horizontal, R.S.lg)
                    .padding(.top, R.S.md)
                calendarCard
                    .padding(.horizontal, R.S.lg)
                    .padding(.top, R.S.md)
                legend
                    .padding(.horizontal, R.S.lg)
                    .padding(.top, R.S.sm)
                monthListSection
                    .padding(.top, R.S.xxl)
                Color.clear.frame(height: 100)
            }
        }
        .background(R.C.bg0)
    }

    // MARK: — Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Calendar")
                .font(R.F.display(30, weight: .bold))
                .tracking(-0.8)
                .foregroundStyle(R.C.fg1)
            Text("\(MockData.upcoming.count) gigs · \(blockedCount) blocked days")
                .monoLabel(size: 10, tracking: 0.6, color: R.C.fg3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: — Month nav

    private var monthNav: some View {
        HStack {
            Button {
                shiftMonth(-1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(R.C.fg1)
                    .frame(width: 36, height: 36)
                    .background { Circle().fill(R.C.glassLo) }
                    .overlay { Circle().strokeBorder(R.C.borderSoft, lineWidth: R.S.hairline) }
            }
            .buttonStyle(.plain)
            Spacer()
            Text(monthTitle)
                .font(R.F.display(20, weight: .bold))
                .tracking(-0.3)
                .foregroundStyle(R.C.fg1)
            Spacer()
            Button {
                shiftMonth(1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(R.C.fg1)
                    .frame(width: 36, height: 36)
                    .background { Circle().fill(R.C.glassLo) }
                    .overlay { Circle().strokeBorder(R.C.borderSoft, lineWidth: R.S.hairline) }
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: — Calendar card

    private var calendarCard: some View {
        VStack(alignment: .leading, spacing: R.S.sm) {
            weekdayHeader
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7),
                spacing: 4
            ) {
                ForEach(cells, id: \.id) { cell in
                    CalendarDayTile(
                        date: cell.date,
                        isToday: cell.date.map { Calendar.current.isDateInToday($0) } ?? false,
                        mark: cell.date.flatMap { markFor($0) }
                    )
                }
            }
        }
        .padding(R.S.md)
        .glassSurface(cornerRadius: R.Rad.card)
    }

    private var weekdayHeader: some View {
        HStack(spacing: 4) {
            ForEach(["MON","TUE","WED","THU","FRI","SAT","SUN"], id: \.self) { d in
                Text(d)
                    .monoLabel(size: 8.5, tracking: 0.6, color: R.C.fg3)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: — Legend

    private var legend: some View {
        HStack(spacing: R.S.lg) {
            LegendDot(color: R.C.fg1, label: "Today", ring: true)
            LegendDot(color: R.C.green, label: "Booked")
            LegendDot(color: R.C.red, label: "Blocked")
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    // MARK: — Month list section

    private var monthListSection: some View {
        VStack(alignment: .leading, spacing: R.S.md) {
            Text("This month's gigs")
                .monoLabel(size: 10, tracking: 0.8, color: R.C.fg3)
                .padding(.horizontal, R.S.lg)
            VStack(spacing: R.S.xs) {
                ForEach(MockData.upcoming) { booking in
                    GigRow(booking: booking) {
                        nav.push(.bookingDetail(bookingID: booking.id))
                    }
                }
            }
            .padding(.horizontal, R.S.lg)
        }
    }

    // MARK: — Helpers

    private struct DayCell: Hashable {
        let id: Int
        let date: Date?
    }

    private var monthTitle: String {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f.string(from: visibleMonth)
    }

    private var cells: [DayCell] {
        let cal = Calendar.current
        var out: [DayCell] = []
        let firstOfMonth = cal.date(from: cal.dateComponents([.year, .month], from: visibleMonth))!
        let range = cal.range(of: .day, in: .month, for: visibleMonth) ?? 1..<31
        let weekday = (cal.component(.weekday, from: firstOfMonth) + 5) % 7

        for i in 0..<weekday {
            out.append(DayCell(id: -1 - i, date: nil))
        }
        for day in range {
            let date = cal.date(byAdding: .day, value: day - 1, to: firstOfMonth)!
            out.append(DayCell(id: day, date: date))
        }
        while out.count < 42 {
            out.append(DayCell(id: -100 - out.count, date: nil))
        }
        return out
    }

    /// Mock: mark upcoming dates as booked, odd days as blocked when < 5,
    /// so the preview reads as a realistic mix.
    private func markFor(_ date: Date) -> DayMark? {
        let cal = Calendar.current
        let day = cal.component(.day, from: date)
        // Booked matches upcoming bookings' parsed day numbers.
        let bookedDays: Set<Int> = [24, 27, 28]
        if bookedDays.contains(day) { return .booked }
        // Blocked — first 3 odd weekdays of the month.
        if day <= 5 && day % 2 == 1 { return .blocked }
        return nil
    }

    private var blockedCount: Int {
        cells.compactMap { $0.date }.reduce(0) { acc, d in
            markFor(d) == .blocked ? acc + 1 : acc
        }
    }

    private func shiftMonth(_ direction: Int) {
        guard let next = Calendar.current.date(byAdding: .month, value: direction, to: visibleMonth) else { return }
        withAnimation(R.M.easeOut) { visibleMonth = next }
    }
}

// MARK: - Day mark

private enum DayMark {
    case booked
    case blocked
}

// MARK: - Day tile

private struct CalendarDayTile: View {
    let date: Date?
    let isToday: Bool
    let mark: DayMark?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: R.Rad.sm, style: .continuous)
                .fill(fill)
            RoundedRectangle(cornerRadius: R.Rad.sm, style: .continuous)
                .strokeBorder(stroke, lineWidth: isToday ? 1.5 : R.S.hairline)
            if let date {
                VStack(spacing: 3) {
                    Text("\(Calendar.current.component(.day, from: date))")
                        .font(R.F.mono(11, weight: isToday ? .bold : .semibold))
                        .foregroundStyle(isToday ? R.C.fg1 : R.C.fg1.opacity(0.85))
                    if let mark {
                        Circle()
                            .fill(mark == .booked ? R.C.green : R.C.red)
                            .frame(width: 5, height: 5)
                    }
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .opacity(date == nil ? 0 : 1)
    }

    private var fill: Color {
        if date == nil { return .clear }
        if isToday { return R.C.fg1.opacity(0.08) }
        return R.C.glassLo
    }

    private var stroke: Color {
        if isToday { return R.C.fg1 }
        if let mark {
            return mark == .booked ? R.C.green.opacity(0.35) : R.C.red.opacity(0.35)
        }
        return R.C.borderSoft
    }
}

// MARK: - Legend dot

private struct LegendDot: View {
    let color: Color
    let label: String
    var ring: Bool = false

    var body: some View {
        HStack(spacing: 5) {
            if ring {
                Circle()
                    .strokeBorder(color, lineWidth: 1.5)
                    .frame(width: 8, height: 8)
            } else {
                Circle().fill(color).frame(width: 8, height: 8)
            }
            Text(label).monoLabel(size: 9, tracking: 0.5, color: R.C.fg3)
        }
    }
}

// MARK: - Gig row

private struct GigRow: View {
    let booking: MockBooking
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: R.S.md) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(booking.day)
                        .font(R.F.mono(10, weight: .bold))
                        .tracking(0.8)
                        .foregroundStyle(R.C.fg1)
                    Text(booking.time)
                        .font(R.F.mono(9, weight: .medium))
                        .tracking(0.6)
                        .foregroundStyle(R.C.fg3)
                }
                .frame(width: 54, alignment: .leading)

                VStack(alignment: .leading, spacing: 2) {
                    Text(booking.venue)
                        .font(R.F.body(13.5, weight: .semibold))
                        .foregroundStyle(R.C.fg1)
                    Text(booking.artist)
                        .font(R.F.body(11.5, weight: .regular))
                        .foregroundStyle(R.C.fg2)
                }
                Spacer(minLength: R.S.sm)
                ChevronRightIcon(size: 11, color: R.C.fg3)
            }
            .padding(R.S.md)
            .glassSurface(cornerRadius: R.Rad.button2, intensity: .soft)
        }
        .buttonStyle(.plain)
    }
}

#if DEBUG
#Preview("CalendarView") {
    let nav = NavigationModel()
    return CalendarView(nav: nav)
        .preferredColorScheme(.dark)
}
#endif
