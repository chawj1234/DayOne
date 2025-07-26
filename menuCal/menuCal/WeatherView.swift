//
//  WeatherView.swift
//  menuCal
//
//  Created by 차원준 on 6/23/25.
//

import SwiftUI
import AppKit

struct WeatherView: View {
    @ObservedObject var weatherManager: WeatherManager
    
    var body: some View {
        VStack(spacing: 0) {
            Divider()
                .padding(.bottom, 10)
            
            // 위치 정보
            HStack(spacing: 4) {
                Image(systemName: "location.fill")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                
                Text(weatherManager.locationName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button(action: {
                    weatherManager.requestLocation()
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 10))
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(PlainButtonStyle())
                .help("Refresh weather")
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
                    
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 8) {
                            Text(weatherManager.temperature)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.primary)
                            
                            Text(weatherManager.condition)
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                        
                        HStack(spacing: 3) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 8))
                                .foregroundColor(.secondary.opacity(0.6))
                            
                            Text("Weather data by Apple Weather")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary.opacity(0.6))
                        }
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }.buttonStyle(PlainButtonStyle())
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