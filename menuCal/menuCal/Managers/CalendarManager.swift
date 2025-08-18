//
//  CalendarManager.swift
//  menuCal
//
//  Created by 차원준 on 6/23/25.
//

import EventKit
import SwiftUI

@MainActor
class CalendarManager: ObservableObject {
    let eventStore = EKEventStore()
    @Published var calendarAccessGranted = false
    @Published var events: [EKEvent] = []
    
    func requestCalendarAccess(completion: (() -> Void)? = nil) {
        if #available(macOS 14.0, *) {
            Task {
                do {
                    let granted = try await eventStore.requestFullAccessToEvents()
                    await MainActor.run {
                        self.calendarAccessGranted = granted
                        print("캘린더 권한 상태: \(granted)")
                        completion?()
                    }
                } catch {
                    print("권한 요청 오류: \(error)")
                    completion?()
                }
            }
        } else {
            eventStore.requestAccess(to: .event) { [weak self] granted, _ in
                DispatchQueue.main.async {
                    self?.calendarAccessGranted = granted
                    print("캘린더 권한 상태: \(granted)")
                    completion?()
                }
            }
        }
    }
    
} 
