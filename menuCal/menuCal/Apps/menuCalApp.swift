//
//  menuCalApp.swift
//  menuCal
//
//  Created by 차원준 on 6/23/25.
//

import SwiftUI
import AppKit
// import ServiceManagement  // 자동 실행 기능을 위해 필요한 경우 주석 해제

@main
struct menuCalApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        //메뉴바 전용 앱으로 메인 창이 없다.
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var popover: NSPopover?
    var statusBarMenu: NSMenu?
    var systemSettingsGuideWindow: NSWindow?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 독 아이콘 숨기기
        NSApp.setActivationPolicy(.accessory)
        
        // 로그인 시 자동 시작 설정 (필요한 경우 주석 해제)
        // enableLoginItem()
        
        // 상태바 아이템 생성
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            updateDateDisplay()
            button.action = #selector(statusBarButtonClicked(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        
        // 상태바 메뉴 설정
        setupStatusBarMenu()
        
        // 1분마다 날짜 업데이트
        Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { _ in
            self.updateDateDisplay()
        }
        
        // 팝오버 설정
        setupPopover()

        
        // 첫 실행 시 온보딩 표시
        checkAndShowOnboarding()
    }
    
    @objc func statusBarButtonClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        
        if event.type == .rightMouseUp {
            // 우클릭 - 메뉴 표시
            statusItem?.menu = statusBarMenu
            statusItem?.button?.performClick(nil)
            statusItem?.menu = nil
        } else {
            // 좌클릭 - 팝오버 토글
            togglePopover()
        }
    }
    
    private func setupStatusBarMenu() {
        statusBarMenu = NSMenu()
        
        // About 메뉴 아이템
        let aboutMenuItem = NSMenuItem(title: NSLocalizedString("About DayOne!", comment: "About menu item"), 
                                       action: #selector(showAbout), 
                                       keyEquivalent: "")
        aboutMenuItem.target = self
        statusBarMenu?.addItem(aboutMenuItem)
        
        // 구분선
        statusBarMenu?.addItem(NSMenuItem.separator())
        
        // Quit 메뉴 아이템
        let quitMenuItem = NSMenuItem(title: NSLocalizedString("Quit DayOne!", comment: "Quit menu item"), 
                                      action: #selector(quitApp), 
                                      keyEquivalent: "q")
        quitMenuItem.target = self
        statusBarMenu?.addItem(quitMenuItem)
    }
    
    @objc func showAbout() {
        let alert = NSAlert()
        alert.messageText = NSLocalizedString("About DayOne!", comment: "About dialog title")
        alert.informativeText = NSLocalizedString("DayOne! is a simple calendar and weather app for your menu bar.\n\nVersion 1.0\n\nWeather data provided by Apple Weather", comment: "About dialog content")
        alert.alertStyle = .informational
        alert.addButton(withTitle: NSLocalizedString("OK", comment: "OK button"))
        alert.runModal()
    }
    
    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }
    
    private func updateDateDisplay() {
        DispatchQueue.main.async {
            if let button = self.statusItem?.button {
                let calendar = Calendar.current
                let day = calendar.component(.day, from: Date())
                
                // 로케일에 따른 날짜 표현
                let systemLanguage = Locale.current.languageCode ?? "en"
                
                if systemLanguage == "ko" {
                    // 한국어: "26일" 형태
                    button.title = "\(day)일"
                } else {
                    // 기타 언어: 서수 표현 (1st, 2nd, 3rd, ...)
                    let numberFormatter = NumberFormatter()
                    numberFormatter.numberStyle = .ordinal
                    numberFormatter.locale = Locale.current
                    
                    let ordinalDay = numberFormatter.string(from: NSNumber(value: day)) ?? "\(day)"
                    button.title = ordinalDay
                }
            }
        }
    }
    
    private func setupPopover() {
        popover = NSPopover()
        popover?.contentSize = NSSize(width: 280, height: 340)
        popover?.behavior = .transient
        updatePopoverContent()
    }
    
    private func updatePopoverContent() {
        let contentView = ContentView()
        //NSHostingController는 SwiftUI 뷰를 AppKit 세상 안에서 사용할 수 있도록 "포장"해주는 특수한 컨트롤러
        //rootView: NSHostingController라는 통역사를 고용할 때, "어떤 SwiftUI 뷰를 통역(호스팅)할 것인지" 알려주는 파라미터
        popover?.contentViewController = NSHostingController(rootView: contentView)
    }
    
    @objc func togglePopover() {
        guard let button = statusItem?.button else { return }
        
        if let popover = popover {
            if popover.isShown {
                //popover 닫기
                popover.performClose(nil)
            } else {
                //popover 열기
                updatePopoverContent() // 팝오버를 열기 전에 컨텐츠를 새로 생성
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            }
        }
    }
    
    // 첫 실행 감지 및 온보딩 표시
    private func checkAndShowOnboarding() {
        if OnboardingManager.shouldShowOnboarding() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                OnboardingManager.showOnboarding()
            }
        }
    }
    
} 
