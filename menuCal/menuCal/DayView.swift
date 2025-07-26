//
//  DayView.swift
//  menuCal
//
//  Created by 차원준 on 6/23/25.
//

import SwiftUI
import EventKit

struct DayView: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let isCurrentMonth: Bool
    @ObservedObject var calendarManager: CalendarManager
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text("\(Calendar.current.component(.day, from: date))")
                .font(.system(size: 13))
                .foregroundColor(textColor)
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(backgroundColor)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .frame(width: 32, height: 32)
        .contentShape(Rectangle())
        .contextMenu {
            if calendarManager.calendarAccessGranted {
                if calendarManager.events.isEmpty {
                    Text("일정 없음")
                } else {
                    ForEach(calendarManager.events, id: \.eventIdentifier) { event in
                        Text(event.title ?? "제목 없음")
                    }
                }
                Divider()
                Button("이벤트 추가") {
                    addEventToCalendar(for: date)
                }
                Button("캘린더 앱 열기") {
                    calendarManager.openCalendarApp()
                }
            } else {
                Button("캘린더 권한 요청") {
                    calendarManager.requestCalendarAccess {
                        calendarManager.fetchEvents(for: date)
                    }
                }
            }
        }
        .onAppear {
            if calendarManager.calendarAccessGranted {
                calendarManager.fetchEvents(for: date)
            }
        }
    }
    
    private func addEventToCalendar(for date: Date) {
        calendarManager.addEvent(title: "새 일정", date: date) { success in
            if success {
                // 이벤트 추가 후 목록 새로고침
                calendarManager.fetchEvents(for: date)
            }
        }
    }
    
    private var textColor: Color {
        if !isCurrentMonth {
            return .clear
        } else if isSelected {
            return .white
        } else if isToday {
            return .accentColor
        } else {
            return .primary
        }
    }
    
    private var backgroundColor: Color {
        if !isCurrentMonth {
            return .clear
        } else if isSelected {
            return .accentColor
        } else if isToday {
            return Color.accentColor.opacity(0.1)
        } else {
            return .clear
        }
    }
} 