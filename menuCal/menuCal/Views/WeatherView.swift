//
//  WeatherView.swift
//  menuCal
//
//  Created by 차원준 on 6/23/25.
//

import SwiftUI
import AppKit

struct WeatherView: View {
    // ":"(타입 명시)을 통해서 weatherManager라는 이름의 변수는 WeatherManager라는 타입의 객체만 담을 수 있음을 나타냄, WeatherManager 객체를 전달 받을 것을 기대함
    @ObservedObject var weatherManager: WeatherManager
    
    //데이터의 주인(CalendarView.swift)은 @StateObject로 단 한 번만 선언하고,
    //그 데이터를 사용해야 하는 다른 뷰(WeatherView 등)들은 @ObservedObject로 전달받아 관찰만 합니다.
    
    var body: some View {
        VStack(spacing: 0) {
            Divider()
                .padding(.bottom, 10)
            
            // 위치 정보
            HStack(spacing: 4) {
                
                Text(weatherManager.locationName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                
                Spacer()
                
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
            
            Button(action: {
                openWeatherApp()
            }) {
                // 날씨 상세 정보
                HStack(spacing: 12) {
                    if weatherManager.isLoading {
                        ProgressView()
                            .scaleEffect(0.7)
                            .frame(width: 18, height: 18)
                    } else if !weatherManager.weatherIcon.isEmpty {
                        Image(systemName: weatherManager.weatherIcon)
                            .foregroundColor(weatherManager.iconColor)
                            .font(.system(size: 18))
                            .frame(width: 20, height: 20)
                    }
                    
                    HStack(spacing: 8) {
                        if !weatherManager.temperature.isEmpty {
                            Text(weatherManager.temperature)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.primary)
                        }
                        
                        if !weatherManager.condition.isEmpty {
                            Text(weatherManager.condition)
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 15)
            }.buttonStyle(PlainButtonStyle())
            .help("Weather data by Apple Weather")
        }
    }
    
    private func openWeatherApp() {
        // 날씨 앱 열기
        if let weatherAppURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.weather") {
            NSWorkspace.shared.open(weatherAppURL)
        } else {
            // 대체 방법: 앱 이름으로 열기
            NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: "/System/Applications/Weather.app"),
                                               configuration: NSWorkspace.OpenConfiguration())
        }
    }
} 
