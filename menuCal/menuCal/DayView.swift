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
