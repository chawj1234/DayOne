//
//  menuCalApp.swift
//  menuCal
//
//  Created by 차원준 on 6/23/25.
//

import SwiftUI
import AppKit
import ServiceManagement

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

class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    var statusItem: NSStatusItem?
    var statusBarMenu: NSMenu?
    var systemSettingsGuideWindow: NSWindow?
    var mainMenu: NSMenu?
    
    private let launchAtLoginKey = "launchAtLoginEnabled"
    private let loginItemIdentifier = "com.Wonjun.menuCal.launcher"
    private var launchAtLoginMenuItem: NSMenuItem?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 독 아이콘 숨기기
        NSApp.setActivationPolicy(.accessory)
        
        configureLaunchAtLoginOnStartup()
        
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
            // 좌클릭 - 메인 메뉴 열기
            presentMainMenu()
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
        
        let launchAtLoginTitle = NSLocalizedString("Launch at Login", comment: "Launch at login menu item")
        let launchAtLoginItem = NSMenuItem(title: launchAtLoginTitle,
                                           action: #selector(toggleLaunchAtLogin(_:)),
                                           keyEquivalent: "")
        launchAtLoginItem.target = self
        launchAtLoginMenuItem = launchAtLoginItem
        updateLaunchAtLoginMenuItemState()
        statusBarMenu?.addItem(launchAtLoginItem)
        
        // 구분선
        statusBarMenu?.addItem(NSMenuItem.separator())
        
        // Quit 메뉴 아이템
        let quitMenuItem = NSMenuItem(title: NSLocalizedString("Quit DayOne!", comment: "Quit menu item"), 
                                      action: #selector(quitApp), 
                                      keyEquivalent: "q")
        quitMenuItem.target = self
        statusBarMenu?.addItem(quitMenuItem)
    }
    
    private func configureLaunchAtLoginOnStartup() {
        let defaults = UserDefaults.standard
        let storedPreference = defaults.object(forKey: launchAtLoginKey) as? Bool
        let desiredState = storedPreference ?? true
        applyLaunchAtLoginPreference(desiredState)
    }
    
    private func applyLaunchAtLoginPreference(_ enabled: Bool) {
        let loginItemService = SMAppService.loginItem(identifier: loginItemIdentifier)
        let currentState = loginItemService.status == .enabled
        
        do {
            if enabled, !currentState {
                try loginItemService.register()
            } else if !enabled, currentState {
                try loginItemService.unregister()
            }
            UserDefaults.standard.set(enabled, forKey: launchAtLoginKey)
            updateLaunchAtLoginMenuItemState(enabled: enabled)
        } catch {
            NSLog("로그인 아이템 업데이트 실패: \(error)")
            updateLaunchAtLoginMenuItemState()
        }
    }
    
    private func currentLaunchAtLoginState() -> Bool {
        SMAppService.loginItem(identifier: loginItemIdentifier).status == .enabled
    }
    
    private func updateLaunchAtLoginMenuItemState(enabled: Bool? = nil) {
        guard let menuItem = launchAtLoginMenuItem else { return }
        let isEnabled = enabled ?? currentLaunchAtLoginState()
        menuItem.state = isEnabled ? .on : .off
    }
    
    @objc private func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        let nextState = !currentLaunchAtLoginState()
        applyLaunchAtLoginPreference(nextState)
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
    
    private func presentMainMenu() {
        guard let statusItem = statusItem, let button = statusItem.button else { return }
        let menu = buildMainMenu()
        mainMenu = menu
        statusItem.menu = menu
        button.performClick(nil)
        statusItem.menu = nil
    }
    
    private func buildMainMenu() -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.delegate = self
        
        let contentItem = NSMenuItem()
        let hostingView = NSHostingView(rootView: CalendarView())
        hostingView.frame = NSRect(x: 0, y: 0, width: 280, height: 320)
        contentItem.view = hostingView
        menu.addItem(contentItem)
        return menu
    }
    
    func menuDidClose(_ menu: NSMenu) {
        if menu == mainMenu {
            mainMenu = nil
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
