//
//  WeatherManager.swift
//  menuCal
//
//  Created by 차원준 on 6/23/25.
//

import AppKit
import CoreLocation
import SwiftUI
import WeatherKit

@MainActor
class WeatherManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var temperature: String = "?"
    @Published var condition: String = NSLocalizedString("Locating...", comment: "Location loading text")
    @Published var weatherIcon: String = "location.fill"
    @Published var iconColor: Color = .secondary
    @Published var locationName: String = NSLocalizedString("Locating...", comment: "Location loading text")
    @Published var isLoading: Bool = false
    
    private let locationManager = CLLocationManager()
    private let weatherService = WeatherService()
    private var currentLocation: CLLocation?
    private var selectedDate: Date = .init()
    
    override init() {
        super.init()
        setupLocationManager()
        requestLocation()
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }
    
    func requestLocation() {
        isLoading = true
        locationName = NSLocalizedString("Locating...", comment: "Location loading text")
        currentLocation = nil
        
        // 권한 확인 후 위치 요청
        switch locationManager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.requestLocation()
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            showLocationError()
        default:
            showLocationError()
        }
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        currentLocation = location
        loadWeather(for: location, date: selectedDate)
        locationManager.stopUpdatingLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        showLocationError()
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        DispatchQueue.main.async {
            switch status {
            case .notDetermined:
                self.locationManager.requestWhenInUseAuthorization()
            case .authorizedWhenInUse, .authorizedAlways:
                self.requestLocation()
            case .denied, .restricted:
                self.showLocationError()
            default:
                break
            }
        }
    }
    
    // MARK: - Weather Loading
    
    func loadWeatherForDate(_ date: Date) { // loadWeather 함수를 통해 해당 날짜의 날씨를 가져온다.
        selectedDate = date
        guard let location = currentLocation else {
            showLocationError()
            return
        }
        loadWeather(for: location, date: date)
    }
    
    private func loadWeather(for location: CLLocation, date: Date) {
        // 날씨 불러오는 함수인데 지역을 받아오는 로직이 함께 있다.
        
        isLoading = true
        
        Task {
            do {
                let weather = try await weatherService.weather(for: location)
                
                let isToday = Calendar.current.isDate(date, inSameDayAs: Date())
                let isFutureDate = date > Date()
                
                if isToday {
                    updateWeatherUI(
                        temperature: Int(weather.currentWeather.temperature.value),
                        condition: weather.currentWeather.condition,
                        date: date
                    )
                } else {
                    if let dailyForecast = weather.dailyForecast.first(where: { forecast in
                        Calendar.current.isDate(forecast.date, inSameDayAs: date)
                    }) {
                        let avgTemp = (dailyForecast.highTemperature.value + dailyForecast.lowTemperature.value) / 2
                        updateWeatherUI(
                            temperature: Int(avgTemp),
                            condition: dailyForecast.condition,
                            date: date
                        )
                    } else {
                        self.temperature = ""
                        self.condition = isFutureDate ?
                            NSLocalizedString("The forecast isn't available yet.", comment: "Forecast data not available") :
                            NSLocalizedString("Past weather data is not available.", comment: "Past weather data not available")
                        self.weatherIcon = ""
                        self.iconColor = .secondary
                        self.isLoading = false
                    }
                }
                
                if locationName == NSLocalizedString("Locating...", comment: "Location loading text") {
                    getLocationName(for: location)
                }
                
                self.isLoading = false
            } catch {
                showWeatherError()
            }
        }
    }
    
    private func updateWeatherUI(temperature: Int, condition: WeatherCondition, date: Date) {
        self.temperature = "\(temperature)°"
        self.condition = weatherConditionText(for: condition)
        
        let iconInfo = weatherIconInfo(for: condition)
        weatherIcon = iconInfo.icon
        iconColor = iconInfo.color
    }
    
    // MARK: - Location Name
    
    private func getLocationName(for location: CLLocation) {
        let geocoder = CLGeocoder()
        
        if #available(macOS 11.0, *) {
            let systemLanguage = Locale.current.languageCode ?? "en"
            let preferredLocale = Locale(identifier: systemLanguage)
            geocoder.reverseGeocodeLocation(location, preferredLocale: preferredLocale) { [weak self] placemarks, error in
                self?.handleGeocodeResult(placemarks: placemarks, error: error)
            }
        } else {
            geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
                self?.handleGeocodeResult(placemarks: placemarks, error: error)
            }
        }
    }
    
    private func handleGeocodeResult(placemarks: [CLPlacemark]?, error: Error?) {
        DispatchQueue.main.async {
            if error != nil {
                self.locationName = NSLocalizedString("Current Location", comment: "Current location text")
                return
            }
            
            if let placemark = placemarks?.first {
                // loclity = 도시, administrativeArea = 광역 행정구역
                let originalLocationName = placemark.locality ??
                    placemark.administrativeArea ??
                    NSLocalizedString("Current Location", comment: "Current location text")
                
                let systemLanguage = Locale.current.languageCode ?? "en"
                
                // 지역에 맞춰서 언어 설정하기
                if systemLanguage == "en" && self.containsKorean(originalLocationName) {
                    self.locationName = self.translateKoreanLocationToEnglish(originalLocationName)
                } else {
                    self.locationName = originalLocationName
                }
            } else {
                self.locationName = NSLocalizedString("Current Location", comment: "Current location text")
            }
        }
    }
    
    private func containsKorean(_ text: String) -> Bool {
        for character in text {
            let scalar = character.unicodeScalars.first
            if let scalar = scalar,
               (scalar.value >= 0xAC00 && scalar.value <= 0xD7AF) ||
               (scalar.value >= 0x1100 && scalar.value <= 0x11FF) ||
               (scalar.value >= 0x3130 && scalar.value <= 0x318F) ||
               (scalar.value >= 0xA960 && scalar.value <= 0xA97F)
            {
                return true
            }
        }
        return false
    }
    
    private func translateKoreanLocationToEnglish(_ koreanLocation: String) -> String {
        let locationMap: [String: String] = [
            "포항시": "Pohang", "포항": "Pohang",
            "서울특별시": "Seoul", "서울시": "Seoul", "서울": "Seoul",
            "부산광역시": "Busan", "부산시": "Busan", "부산": "Busan",
            "대구광역시": "Daegu", "대구시": "Daegu", "대구": "Daegu",
            "인천광역시": "Incheon", "인천시": "Incheon", "인천": "Incheon",
            "광주광역시": "Gwangju", "광주시": "Gwangju", "광주": "Gwangju",
            "대전광역시": "Daejeon", "대전시": "Daejeon", "대전": "Daejeon",
            "울산광역시": "Ulsan", "울산시": "Ulsan", "울산": "Ulsan",
            "경상북도": "Gyeongsangbuk-do",
            "경주시": "Gyeongju", "경주": "Gyeongju",
            "안동시": "Andong", "안동": "Andong",
            "구미시": "Gumi", "구미": "Gumi",
            "강남구": "Gangnam-gu", "강동구": "Gangdong-gu",
            "종로구": "Jongno-gu", "중구": "Jung-gu"
        ]
        
        return locationMap[koreanLocation] ?? koreanLocation
    }
    
    // MARK: - Error Handling
    
    private func showLocationError() {
        isLoading = false
        locationName = NSLocalizedString("Location Failed", comment: "Location failed text")
        temperature = "?"
        condition = NSLocalizedString("Location permission required", comment: "Location permission required text")
        weatherIcon = "location.slash"
        iconColor = .red
    }
    
    private func showWeatherError() {
        isLoading = false
        temperature = "?"
        condition = NSLocalizedString("Unable to load weather data.", comment: "Weather fetch error text")
        weatherIcon = "exclamationmark.triangle"
        iconColor = .orange
    }
    
    // MARK: - Weather Icons & Text
    
    private func weatherIconInfo(for condition: WeatherCondition) -> (icon: String, color: Color) {
        switch condition {
        case .clear, .mostlyClear:
            return ("sun.max.fill", .orange)
        case .partlyCloudy:
            return ("cloud.sun.fill", .blue)
        case .mostlyCloudy, .cloudy:
            return ("cloud.fill", .gray)
        case .foggy:
            return ("cloud.fog.fill", .secondary)
        case .drizzle:
            return ("cloud.drizzle.fill", .blue)
        case .rain:
            return ("cloud.rain.fill", .blue)
        case .heavyRain:
            return ("cloud.heavyrain.fill", .blue)
        case .snow:
            return ("cloud.snow.fill", .cyan)
        case .sleet:
            return ("cloud.sleet.fill", .cyan)
        case .thunderstorms, .isolatedThunderstorms, .scatteredThunderstorms:
            return ("cloud.bolt.fill", .purple)
        case .strongStorms:
            return ("cloud.bolt.rain.fill", .purple)
        case .blizzard, .blowingSnow:
            return ("wind.snow", .cyan)
        case .freezingDrizzle, .freezingRain, .wintryMix:
            return ("cloud.sleet.fill", .cyan)
        case .frigid:
            return ("thermometer.snowflake", .cyan)
        case .hail:
            return ("cloud.hail.fill", .blue)
        case .hot:
            return ("thermometer.sun.fill", .red)
        case .hurricane:
            return ("hurricane", .purple)
        case .tropicalStorm:
            return ("tornado", .purple)
        case .windy:
            return ("wind", .secondary)
        @unknown default:
            return ("questionmark", .secondary)
        }
    }
    
    private func weatherConditionText(for condition: WeatherCondition) -> String {
        switch condition {
        case .clear:
            return NSLocalizedString("Clear", comment: "Weather condition: clear")
        case .mostlyClear:
            return NSLocalizedString("Mostly Clear", comment: "Weather condition: mostly clear")
        case .partlyCloudy:
            return NSLocalizedString("Partly Cloudy", comment: "Weather condition: partly cloudy")
        case .mostlyCloudy:
            return NSLocalizedString("Mostly Cloudy", comment: "Weather condition: mostly cloudy")
        case .cloudy:
            return NSLocalizedString("Cloudy", comment: "Weather condition: cloudy")
        case .foggy:
            return NSLocalizedString("Foggy", comment: "Weather condition: foggy")
        case .drizzle:
            return NSLocalizedString("Drizzle", comment: "Weather condition: drizzle")
        case .rain:
            return NSLocalizedString("Rain", comment: "Weather condition: rain")
        case .heavyRain:
            return NSLocalizedString("Heavy Rain", comment: "Weather condition: heavy rain")
        case .snow:
            return NSLocalizedString("Snow", comment: "Weather condition: snow")
        case .sleet:
            return NSLocalizedString("Sleet", comment: "Weather condition: sleet")
        case .thunderstorms:
            return NSLocalizedString("Thunderstorms", comment: "Weather condition: thunderstorms")
        case .windy:
            return NSLocalizedString("Windy", comment: "Weather condition: windy")
        case .hot:
            return NSLocalizedString("Hot", comment: "Weather condition: hot")
        default:
            return NSLocalizedString("Unknown Weather", comment: "Weather condition: unknown")
        }
    }
} 
