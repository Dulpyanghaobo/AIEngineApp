//
//  RealWorldContext.swift
//  AIEngineApp
//
//  Created by i564407 on 10/3/25.
//


import Foundation
import FoundationModels
import Combine
/// 封装了从用户真实世界数据中提取的上下文信息
@Generable
struct RealWorldContext: Equatable, Codable {
    @Guide(description: "The user's average sleep duration in hours during the period.")
    var averageSleepHours: Double?
    
    @Guide(description: "The number of nights with poor sleep quality (e.g., high heart rate).")
    var stressfulNights: Int?
    
    @Guide(description: "A list of significant events from the user's calendar.")
    var significantEvents: [String]?
    
    @Guide(description: "A concluding summary of the real-world data analysis.")
    var summary: String
}
