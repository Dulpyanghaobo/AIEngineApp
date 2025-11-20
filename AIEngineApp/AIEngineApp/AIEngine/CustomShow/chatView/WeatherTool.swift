//
//  WeatherTool.swift
//  AIEngineApp
//
//  Created by i564407 on 9/28/25.
//


import Foundation
import FoundationModels

// 一个模拟的工具，用于“获取”天气信息。
struct WeatherTool: Tool {
    var name: String = "getWeather"
    var description: String = "Provides the current weather for a given location."

    // 定义工具所需的参数
    @Generable
    struct Arguments {
        var location: String
    }

    // 当模型调用此工具时，此方法会执行
    func call(arguments: Arguments) async throws -> String {
        // 在真实应用中，这里会调用一个天气API。
        // 为了演示，我们返回一个硬编码的字符串。
        let fakeWeatherData = [
            "cupertino": "sunny, 25°C",
            "san francisco": "foggy, 18°C",
            "beijing": "clear, 22°C"
        ]
        
        let weather = fakeWeatherData[arguments.location.lowercased()] ?? "weather data not available for this location."
        
        // 工具的返回值必须是字符串
        return "The weather in \(arguments.location) is \(weather)."
    }
}
