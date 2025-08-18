//
//  CalendarView.swift
//  menuCal
//
//  Created by 차원준 on 6/23/25.
//

import SwiftUI

struct CalendarView: View {
    @State private var selectedDate: Date
    @State private var displayDate: Date
    @StateObject private var weatherManager: WeatherManager
    @StateObject private var calendarManager = CalendarManager()
    
    // 초기화 로직을 한 곳으로 집중
    init() {
        let today = Date()
        _selectedDate = State(initialValue: today)
        _displayDate = State(initialValue: today)
        _weatherManager = StateObject(wrappedValue: WeatherManager())
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            VStack(spacing: 8) {
                HStack {
                    Button(action: previousMonth) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Spacer()
                    
                    Text(monthYearString)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Button(action: nextMonth) {
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 8)

                // 요일 헤더
                HStack(spacing: 0) {
                    ForEach(weekdaySymbols, id: \.self) { day in
                        Text(day)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 8)
            }
            .padding(.bottom, 3)
            
            // 캘린더 그리드
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 0) {
                ForEach(calendarDays, id: \.self) { date in
                    if let date = date {
                        DayView(
                            date: date,
                            isSelected: Calendar.current.isDate(date, inSameDayAs: selectedDate),
                            isToday: Calendar.current.isDate(date, inSameDayAs: Date()),
                            isCurrentMonth: Calendar.current.isDate(date, equalTo: displayDate, toGranularity: .month),
                            calendarManager: calendarManager
                        ) {
                            selectedDate = date
                            weatherManager.loadWeatherForDate(date)
                        }
                    } else {
                        Text("")
                            .frame(height: 32)
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 8)
            
            // 날씨 정보
            WeatherView(weatherManager: weatherManager)
        }
        .frame(width: 280, height: 340)
        .background(Color(NSColor.windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.top, 4)
        .onAppear {
            // 앱 시작 시 캘린더 권한 요청
            calendarManager.requestCalendarAccess()
        }
    }
    
    // MARK: - Calendar Logic
    
    private var weekdaySymbols: [String] {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        return formatter.shortWeekdaySymbols
    }
    
    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = DateFormatter.dateFormat(fromTemplate: "yyyyMMMM", options: 0, locale: Locale.current)
        return formatter.string(from: displayDate)
    }
    
    private var calendarDays: [Date?] {
        let calendar = Calendar.current
        let startOfMonth = calendar.dateInterval(of: .month, for: displayDate)?.start ?? displayDate
        let endOfMonth = calendar.dateInterval(of: .month, for: displayDate)?.end ?? displayDate
        let startOfCalendar = calendar.dateInterval(of: .weekOfYear, for: startOfMonth)?.start ?? startOfMonth
        
        var days: [Date?] = []
        var currentDate = startOfCalendar
        
        while days.count < 42 {
            if currentDate < startOfMonth || currentDate >= endOfMonth {
                days.append(nil)
            } else {
                days.append(currentDate)
            }
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
        
        return days
    }
    
    private func previousMonth() {
        displayDate = Calendar.current.date(byAdding: .month, value: -1, to: displayDate) ?? displayDate
    }
    
    private func nextMonth() {
        displayDate = Calendar.current.date(byAdding: .month, value: 1, to: displayDate) ?? displayDate
    }
}
