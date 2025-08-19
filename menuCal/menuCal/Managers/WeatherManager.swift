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
                if systemLanguage == "en" { // 시스템 언어 "영어"
                    if self.containsKorean(originalLocationName) { // 지역명이 한국어인 경우
                        self.locationName = self.translateKoreanLocationToEnglish(originalLocationName)
                    } else { // 지역명이 한국어가 아닌 경우
                        self.locationName = originalLocationName
                    }
                } else { // 시스템 언어 "영어" 아님
                    self.locationName = originalLocationName
                }
            } else { // placemarks 배열에 값이 없음
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
            "가평군": "Gapyeong", "가평": "Gapyeong",
            "강릉시": "Gangneung", "강릉": "Gangneung",
            "강진군": "Gangjin", "강진": "Gangjin",
            "개천군": "Gaechon", "개천": "Gaechon",
            "거제시": "Geoje", "거제": "Geoje",
            "거창군": "GeoChang", "거창": "GeoChang",
            "경산시": "Gyeongsan", "경산": "Gyeongsan",
            "경주시": "Gyeongju", "경주": "Gyeongju",
            "계룡시": "Gyeryong", "계룡": "Gyeryong",
            "고성군(강원)": "Goseong (Gangwon)", "고성(강원)": "Goseong (Gangwon)",
            "고성군(경남)": "Goseong (Gyeongnam)", "고성(경남)": "Goseong (Gyeongnam)",
            "고창군": "Gochang", "고창": "Gochang",
            "고흥군": "Goheung", "고흥": "Goheung",
            "공주시": "Gongju", "공주": "Gongju",
            "과천시": "Gwacheon", "과천": "Gwacheon",
            "광명시": "Gwangmyeong", "광명": "Gwangmyeong",
            "광양시": "Gwangyang", "광양": "Gwangyang",
            "광주시": "Gwangju", "광주": "Gwangju",
            "광주광역시": "Gwangju Metropolitan City",
            "구례군": "Gurye", "구례": "Gurye",
            "구리시": "Guri", "구리": "Guri",
            "군산시": "Gunsan", "군산": "Gunsan",
            "군포시": "Gunpo", "군포": "Gunpo",
            "군위군": "Gunwi", "군위": "Gunwi",
            "김제시": "Gimje", "김제": "Gimje",
            "김천시": "Gimcheon", "김천": "Gimcheon",
            "김해시": "Gimhae", "김해": "Gimhae",
            "남양주시": "Namyangju", "남양주": "Namyangju",
            "남원시": "Namwon", "남원": "Namwon",
            "남해군": "Namhae", "남해": "Namhae",
            "논산시": "Nonsan", "논산": "Nonsan",
            "단양군": "Danyang", "단양": "Danyang",
            "담양군": "Damyang", "담양": "Damyang",
            "대구광역시": "Daegu", "대구": "Daegu",
            "대전광역시": "Daejeon", "대전": "Daejeon",
            "동두천시": "Dongducheon", "동두천": "Dongducheon",
            "동해시": "Donghae", "동해": "Donghae",
            "마산시": "Masan", "마산": "Masan",
            "목포시": "Mokpo", "목포": "Mokpo",
            "무안군": "Muan", "무안": "Muan",
            "무주군": "Muju", "무주": "Muju",
            "밀양시": "Miryang", "밀양": "Miryang",
            "보령시": "Boryeong", "보령": "Boryeong",
            "보성군": "Boseong", "보성": "Boseong",
            "부여군": "Buyeo", "부여": "Buyeo",
            "부천시": "Bucheon", "부천": "Bucheon",
            "부산광역시": "Busan",
            "서산시": "Seosan", "서산": "Seosan",
            "서귀포시": "Seogwipo", "서귀포": "Seogwipo",
            "서울특별시": "Seoul", "서울": "Seoul",
            "성남시": "Seongnam", "성남": "Seongnam",
            "세종특별자치시": "Sejong",
            "속초시": "Sokcho", "속초": "Sokcho",
            "수원시": "Suwon", "수원": "Suwon",
            "순천시": "Suncheon", "순천": "Suncheon",
            "순창군": "Sunchang", "순창": "Sunchang",
            "시흥시": "Siheung", "시흥": "Siheung",
            "아산시": "Asan", "아산": "Asan",
            "안동시": "Andong", "안동": "Andong",
            "안성시": "Anseong", "안성": "Anseong",
            "안양시": "Anyang", "안양": "Anyang",
            "양구군": "Yanggu", "양구": "Yanggu",
            "양산시": "Yangsan", "양산": "Yangsan",
            "양양군": "Yangyang", "양양": "Yangyang",
            "양평군": "Yangpyeong", "양평": "Yangpyeong",
            "양주시": "Yangju", "양주": "Yangju",
            "여수시": "Yeosu", "여수": "Yeosu",
            "여주시": "Yeoju", "여주": "Yeoju",
            "연천군": "Yeoncheon", "연천": "Yeoncheon",
            "영광군": "Yeonggwang", "영광": "Yeonggwang",
            "영덕군": "Yeongdeok", "영덕": "Yeongdeok",
            "영양군": "Yeongyang", "영양": "Yeongyang",
            "영주시": "Yeongju", "영주": "Yeongju",
            "영천시": "Yeongcheon", "영천": "Yeongcheon",
            "영월군": "Yeongwol", "영월": "Yeongwol",
            "예산군": "Yesan", "예산": "Yesan",
            "예천군": "Yecheon", "예천": "Yecheon",
            "오산시": "Osan", "오산": "Osan",
            "용인시": "Yongin", "용인": "Yongin",
            "울릉군": "Ulleung", "울릉": "Ulleung",
            "울산광역시": "Ulsan", "울산시": "Ulsan",
            "울진군": "Uljin", "울진": "Uljin",
            "원주시": "Wonju", "원주": "Wonju",
            "의성군": "Uiseong", "의성": "Uiseong",
            "의왕시": "Uiwang", "의왕": "Uiwang",
            "의정부시": "Uijeongbu", "의정부": "Uijeongbu",
            "익산시": "Iksan", "익산": "Iksan",
            "임실군": "Imsil", "임실": "Imsil",
            "장성군": "Jangseong", "장성": "Jangseong",
            "장수군": "Jangsu", "장수": "Jangsu",
            "장흥군": "Jangheung", "장흥": "Jangheung",
            "전주시": "Jeonju", "전주": "Jeonju",
            "정선군": "Jeongseon", "정선": "Jeongseon",
            "정읍시": "Jeongeup", "정읍": "Jeongeup",
            "제천시": "Jecheon", "제천": "Jecheon",
            "제주시": "Jeju", "제주": "Jeju",
            "진도군": "Jindo", "진도": "Jindo",
            "진주시": "Jinju", "진주": "Jinju",
            "진안군": "Jinan", "진안": "Jinan",
            "창녕군": "Changnyeong", "창녕": "Changnyeong",
            "창원시": "Changwon", "창원": "Changwon",
            "천안시": "Cheonan", "천안": "Cheonan",
            "청도군": "Cheongdo", "청도": "Cheongdo",
            "청송군": "Cheongsong", "청송": "Cheongsong",
            "청양군": "Cheongyang", "청양": "Cheongyang",
            "청주시": "Cheongju", "청주": "Cheongju",
            "철원군": "Cheorwon", "철원": "Cheorwon",
            "춘천시": "Chuncheon", "춘천": "Chuncheon",
            "충주시": "Chungju", "충주": "Chungju",
            "칠곡군": "Chilgok", "칠곡": "Chilgok",
            "태백시": "Taebaek", "태백": "Taebaek",
            "태안군": "Taean", "태안": "Taean",
            "통영시": "Tongyeong", "통영": "Tongyeong",
            "파주시": "Paju", "파주": "Paju",
            "평택시": "Pyeongtaek", "평택": "Pyeongtaek",
            "평창군": "Pyeongchang", "평창": "Pyeongchang",
            "포천시": "Pocheon", "포천": "Pocheon",
            "포항시": "Pohang", "포항": "Pohang",
            "하동군": "Hadong", "하동": "Hadong",
            "하남시": "Hanam", "하남": "Hanam",
            "함안군": "Haman", "함안": "Haman",
            "함평군": "Hampyeong", "함평": "Hampyeong",
            "함양군": "Hamyang", "함양": "Hamyang",
            "해남군": "Haenam", "해남": "Haenam",
            "홍천군": "Hongcheon", "홍천": "Hongcheon",
            "홍성군": "Hongseong", "홍성": "Hongseong",
            "화성시": "Hwaseong", "화성": "Hwaseong",
            "화순군": "Hwasun", "화순": "Hwasun",
            "화천군": "Hwacheon", "화천": "Hwacheon",
            "횡성군": "Hoengseong", "횡성": "Hoengseong"
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
