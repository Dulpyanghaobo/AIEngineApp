//
//  DreamType.swift
//  AIEngineApp
//
//  Created by i564407 on 10/3/25.
//


//
//  DreamType.swift
//  pdfexportapp
//
//  Created by i564407 on 10/3/25.
//

import Foundation

public enum DreamType: String, CaseIterable, Identifiable {
    case happy = "美梦"
    case nightmare = "噩梦"
    case weird = "奇怪的梦"
    case other = "其他的梦"
    
    public var id: String { self.rawValue }
}
