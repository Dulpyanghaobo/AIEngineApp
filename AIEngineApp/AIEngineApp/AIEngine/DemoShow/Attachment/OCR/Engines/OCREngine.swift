//
//  Engines.swift
//  CamScanner
//
//  Created by i564407 on 2025/7/20.
//
public protocol OCREngine {
    func recognize(_ request: OCRRequest, progress: @escaping (Double) -> Void) async throws -> [PageRecognizedText]}
