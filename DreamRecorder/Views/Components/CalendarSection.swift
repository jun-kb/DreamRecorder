import SwiftUI

/// ホーム画面のカレンダーセクション
struct CalendarSection: View {
    @ObservedObject var viewModel: HomeViewModel
    
    var body: some View {
        VStack(spacing: 12) {
            monthNavigation
            weekdayHeader
            daysGrid
        }
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(Color.white.opacity(0.05))
        .cornerRadius(20)
        .padding()
    }
    
    // MARK: - Subviews
    
    /// 月ナビゲーション（前月/次月ボタンと月表示）
    private var monthNavigation: some View {
        HStack {
            Button { viewModel.shiftMonth(by: -1) } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.dreamAccent)
                    .padding(8)
                    .background(Color.white.opacity(0.06))
                    .clipShape(Circle())
            }
            Spacer()
            Text(Self.monthFormatter.string(from: viewModel.displayedMonth))
                .font(.system(.headline, design: .rounded, weight: .semibold))
                .foregroundColor(.dreamText)
            Spacer()
            Button { viewModel.shiftMonth(by: 1) } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.dreamAccent)
                    .padding(8)
                    .background(Color.white.opacity(0.06))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal)
    }
    
    /// 曜日ヘッダー
    private var weekdayHeader: some View {
        HStack {
            ForEach(Self.weekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.dreamCaption)
                    .foregroundColor(.dreamTextSecondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 10)
    }
    
    /// 日付グリッド
    private var daysGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
            ForEach(viewModel.monthDaysWithPadding.indices, id: \.self) { index in
                if let date = viewModel.monthDaysWithPadding[index] {
                    DayCell(
                        date: date,
                        isSelected: Calendar.current.isDate(date, inSameDayAs: viewModel.selectedDate),
                        isToday: Calendar.current.isDateInToday(date),
                        hasDream: viewModel.hasDream(for: date),
                        hasReflection: viewModel.hasReflection(for: date),
                        onTap: { viewModel.handleDateTap(date) }
                    )
                } else {
                    Color.clear
                        .frame(height: 40)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 4)
    }
    
    // MARK: - Formatters
    
    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "y/MM"
        return formatter
    }()
    
    private static let weekdaySymbols: [String] = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.shortWeekdaySymbols.map { $0.uppercased() }
    }()
}

// MARK: - DayCell

/// カレンダーの日付セル
private struct DayCell: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let hasDream: Bool
    let hasReflection: Bool
    let onTap: () -> Void
    
    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "d"
        return formatter
    }()
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                Text(Self.dayFormatter.string(from: date))
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(isToday ? .black : .dreamText)
                    .frame(maxWidth: .infinity, minHeight: 28)
                    .background(
                        // 今日：背景にCircle
                        Circle()
                            .fill(isToday ? Color.dreamAccent : Color.clear)
                    )
                
                // 記入済みインジケーター（2つのドット）
                HStack(spacing: 3) {
                    if hasDream {
                        Circle()
                            .fill(Color.dreamIndicator)
                            .frame(width: 5, height: 5)
                    }
                    if hasReflection {
                        Circle()
                            .fill(Color.reflectionIndicator)
                            .frame(width: 5, height: 5)
                    }
                }
            }
            .frame(height: 40)
            .padding(6)
            .background(
                // 選択中：セル背景色を変更
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.dreamAccent.opacity(0.25) : Color.white.opacity(0.03))
            )
        }
        .buttonStyle(.plain)
    }
}
