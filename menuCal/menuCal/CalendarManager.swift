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
    
    func fetchEvents(for date: Date) {
        guard calendarAccessGranted else {
            print("캘린더 권한이 없어서 이벤트를 가져올 수 없습니다.")
            return
        }
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        let predicate = eventStore.predicateForEvents(withStart: startOfDay, end: endOfDay, calendars: nil)
        let foundEvents = eventStore.events(matching: predicate)
        
        DispatchQueue.main.async {
            self.events = foundEvents
            print("\(date) 날짜의 이벤트 개수: \(foundEvents.count)")
            for event in foundEvents {
                print("이벤트: \(event.title ?? "제목 없음")")
            }
        }
    }
    
    func addEvent(title: String, date: Date, completion: @escaping (Bool) -> Void) {
        guard calendarAccessGranted else {
            print("캘린더 권한이 없어서 이벤트를 추가할 수 없습니다.")
            completion(false)
            return
        }
        
        let event = EKEvent(eventStore: eventStore)
        event.title = title
        event.startDate = date
        event.endDate = Calendar.current.date(byAdding: .hour, value: 1, to: date) ?? date
        event.calendar = eventStore.defaultCalendarForNewEvents
        
        do {
            try eventStore.save(event, span: .thisEvent)
            print("이벤트가 성공적으로 추가되었습니다")
            completion(true)
        } catch {
            print("이벤트 추가 실패: \(error)")
            completion(false)
        }
    }
    
    func openCalendarApp() {
        if let calendarAppURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.iCal") {
            NSWorkspace.shared.open(calendarAppURL)
        } else {
            NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: "/System/Applications/Calendar.app"),
                                               configuration: NSWorkspace.OpenConfiguration())
        }
    }
} 