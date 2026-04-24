// AvailabilityView.swift — Screen 21
//
// Availability editor for the logged-in artist. Port of
// `AvailabilityScreen` at ios-app.jsx line 1862. Three controls:
//
//   1. 7-column calendar — tap any cell to toggle blocked. Today is
//      ringed, past dates are dimmed + locked.
//   2. Base fee slider — monotonic AED fee from 5K to 80K with live
//      mono-font readout.
//   3. Tour mode toggle — when on, promoters see "Flexible on travel"
//      on the artist's public profile.
//
// No network writes in this wave — state is local @State. Wire up to
// the AvailabilityStore + update_artist_availability RPC in Wave 4.

import SwiftUI
import DesignSystem
#if canImport(UIKit)
import UIKit
#endif

public struct AvailabilityView: View {
    @Bindable var nav: NavigationModel

    @State private var visibleMonth: Date = Date()
    @State private var blockedDates: Set<Date> = [] // startOfDay-normalized
    @State private var baseFeeK: Double = 28         // fee in thousands of AED
    @State private var tourMode: Bool = false

    public init(nav: NavigationModel) {
        self.nav = nav
    }

    public var body: some View {
        VStack(spacing: 0) {
            NavHeader(title: "Availability", onBack: { nav.pop() }) {
                Button {
                    save()
                } label: {
                    Text("Save")
                        .monoLabel(size: 10, tracking: 0.8, color: R.C.bg0)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 14)
                        .background {
                            Capsule().fill(R.C.fg1)
                        }
                }
                .buttonStyle(.plain)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: R.S.xl) {
                    calendarCard
                    feeCard
                    tourCard
                    Color.clear.frame(height: R.S.xxl)
                }
                .padding(.horizontal, R.S.lg)
                .padding(.top, R.S.sm)
            }
        }
        .background(R.C.bg0)
    }

    // MARK: — Calendar card

    private var calendarCard: some View {
        VStack(alignment: .leading, spacing: R.S.md) {
            HStack {
                Button {
                    shiftMonth(-1)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(R.C.fg1)
                        .frame(width: 32, height: 32)
                        .background { Circle().fill(R.C.glassLo) }
                }
                .buttonStyle(.plain)
                Spacer()
                Text(monthTitle)
                    .font(R.F.display(18, weight: .bold))
                    .tracking(-0.3)
                    .foregroundStyle(R.C.fg1)
                Spacer()
                Button {
                    shiftMonth(1)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(R.C.fg1)
                        .frame(width: 32, height: 32)
                        .background { Circle().fill(R.C.glassLo) }
                }
                .buttonStyle(.plain)
            }

            weekdayHeader
            calendarGrid
            legend
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

    private var calendarGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
            ForEach(cells, id: \.self) { cell in
                DayCell(
                    date: cell.date,
                    inMonth: cell.inCurrentMonth,
                    isPast: cell.date.map { Calendar.current.startOfDay(for: $0) < Calendar.current.startOfDay(for: Date()) } ?? false,
                    isToday: cell.date.map { Calendar.current.isDateInToday($0) } ?? false,
                    isBlocked: cell.date.map { blockedDates.contains(Calendar.current.startOfDay(for: $0)) } ?? false,
                    onTap: {
                        guard let d = cell.date else { return }
                        toggle(d)
                    }
                )
            }
        }
    }

    private var legend: some View {
        HStack(spacing: R.S.md) {
            LegendDot(color: R.C.green, label: "Free")
            LegendDot(color: R.C.red, label: "Blocked")
            LegendDot(color: R.C.fg1, label: "Today", isRing: true)
        }
        .padding(.top, R.S.xs)
    }

    // MARK: — Fee card

    private var feeCard: some View {
        VStack(alignment: .leading, spacing: R.S.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text("Base fee")
                    .monoLabel(size: 10, tracking: 0.8, color: R.C.fg3)
                Spacer()
                Text("AED \(Int(baseFeeK))K")
                    .font(R.F.display(24, weight: .bold))
                    .tracking(-0.5)
                    .foregroundStyle(R.C.fg1)
            }
            Text("Your visible floor — promoters can offer more; anything below is filtered out.")
                .font(R.F.body(12, weight: .regular))
                .foregroundStyle(R.C.fg3)
                .lineSpacing(2)

            Slider(value: $baseFeeK, in: 5...80, step: 1)
                .tint(R.C.fg1)
                .padding(.top, R.S.xs)

            HStack {
                Text("AED 5K").monoLabel(size: 8.5, tracking: 0.5, color: R.C.fg3)
                Spacer()
                Text("AED 80K").monoLabel(size: 8.5, tracking: 0.5, color: R.C.fg3)
            }
        }
        .padding(R.S.md)
        .glassSurface(cornerRadius: R.Rad.card)
    }

    // MARK: — Tour mode card

    private var tourCard: some View {
        HStack(alignment: .center, spacing: R.S.md) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Tour mode")
                    .font(R.F.body(14, weight: .semibold))
                    .foregroundStyle(R.C.fg1)
                Text("Show 'Flexible on travel' on your profile. Promoters in other cities see you first.")
                    .font(R.F.body(12, weight: .regular))
                    .foregroundStyle(R.C.fg3)
                    .lineSpacing(2)
            }
            Spacer()
            Toggle("", isOn: $tourMode)
                .labelsHidden()
                .tint(R.C.fg1)
                .accessibilityLabel("Tour mode")
        }
        .padding(R.S.md)
        .glassSurface(cornerRadius: R.Rad.card)
    }

    // MARK: — Helpers

    private struct CalendarCell: Hashable {
        let id: Int                // monotonically increasing for stability
        let date: Date?            // nil for leading-blank cells
        let inCurrentMonth: Bool
    }

    private var monthTitle: String {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f.string(from: visibleMonth)
    }

    /// Build 6-row × 7-col grid with Mon-first start.
    private var cells: [CalendarCell] {
        let cal = Calendar.current
        var out: [CalendarCell] = []

        let monthRange = cal.range(of: .day, in: .month, for: visibleMonth) ?? 1..<31
        let firstOfMonth = cal.date(from: cal.dateComponents([.year, .month], from: visibleMonth))!

        // Mon=2, Sun=1 in Calendar's weekday; we want Mon=0.
        let weekday = (cal.component(.weekday, from: firstOfMonth) + 5) % 7

        // Leading blanks
        for i in 0..<weekday {
            out.append(CalendarCell(id: -1 - i, date: nil, inCurrentMonth: false))
        }

        // Days
        for day in monthRange {
            let date = cal.date(byAdding: .day, value: day - 1, to: firstOfMonth)!
            out.append(CalendarCell(id: day, date: date, inCurrentMonth: true))
        }

        // Trailing blanks to fill 6 rows of 7 cells (42 total)
        while out.count < 42 {
            out.append(CalendarCell(id: -100 - out.count, date: nil, inCurrentMonth: false))
        }
        return out
    }

    private func shiftMonth(_ direction: Int) {
        guard let next = Calendar.current.date(byAdding: .month, value: direction, to: visibleMonth) else { return }
        withAnimation(R.M.easeOut) { visibleMonth = next }
    }

    private func toggle(_ date: Date) {
        let d = Calendar.current.startOfDay(for: date)
        guard d >= Calendar.current.startOfDay(for: Date()) else { return }
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
        withAnimation(R.M.easeOutFast) {
            if blockedDates.contains(d) { blockedDates.remove(d) } else { blockedDates.insert(d) }
        }
    }

    private func save() {
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
        nav.pop()
    }
}

// MARK: - Day cell

private struct DayCell: View {
    let date: Date?
    let inMonth: Bool
    let isPast: Bool
    let isToday: Bool
    let isBlocked: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack {
                RoundedRectangle(cornerRadius: R.Rad.sm, style: .continuous)
                    .fill(fill)
                RoundedRectangle(cornerRadius: R.Rad.sm, style: .continuous)
                    .strokeBorder(stroke, lineWidth: isToday ? 1.5 : R.S.hairline)
                Text(dayLabel)
                    .font(R.F.mono(11, weight: isToday ? .bold : .semibold))
                    .foregroundStyle(labelColor)
            }
            .aspectRatio(1, contentMode: .fit)
        }
        .buttonStyle(.plain)
        .disabled(date == nil || isPast)
        .opacity(opacity)
        .accessibilityLabel(a11yLabel)
    }

    private var dayLabel: String {
        guard let date else { return "" }
        return "\(Calendar.current.component(.day, from: date))"
    }

    private var fill: Color {
        if !inMonth { return .clear }
        if isBlocked { return R.C.red.opacity(0.18) }
        if isToday { return R.C.fg1.opacity(0.08) }
        return R.C.glassLo
    }

    private var stroke: Color {
        if isToday { return R.C.fg1 }
        if isBlocked { return R.C.red.opacity(0.5) }
        return R.C.borderSoft
    }

    private var labelColor: Color {
        if isPast { return R.C.fg3 }
        if isBlocked { return R.C.red }
        return R.C.fg1
    }

    private var opacity: Double {
        if date == nil { return 0 }
        if isPast { return 0.4 }
        return 1.0
    }

    private var a11yLabel: String {
        guard let date else { return "" }
        let f = DateFormatter()
        f.dateStyle = .medium
        let state = isBlocked ? "blocked" : "available"
        return "\(f.string(from: date)), \(state)"
    }
}

// MARK: - Legend dot

private struct LegendDot: View {
    let color: Color
    let label: String
    var isRing: Bool = false

    var body: some View {
        HStack(spacing: 5) {
            if isRing {
                Circle()
                    .strokeBorder(color, lineWidth: 1.5)
                    .frame(width: 8, height: 8)
            } else {
                Circle().fill(color).frame(width: 8, height: 8)
            }
            Text(label).monoLabel(size: 8.5, tracking: 0.5, color: R.C.fg3)
        }
    }
}

#if DEBUG
#Preview("AvailabilityView") {
    let nav = NavigationModel()
    return AvailabilityView(nav: nav)
        .preferredColorScheme(.dark)
}
#endif
