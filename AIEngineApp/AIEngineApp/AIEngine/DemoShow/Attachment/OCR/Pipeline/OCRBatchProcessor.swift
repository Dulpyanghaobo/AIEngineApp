//
//  OCRBatchProcessor.swift
//  CamScanner
//
//  Created by i564407 on 2025/7/20.
//
public actor OCRBatchProcessor {
    
    public struct Progress: Sendable {
        public let overall: Double        // 0‥1
        public let completed: Int
        public let total: Int
    }
    
    public typealias ProgressHandler = @Sendable (Progress) -> Void
    
    private let engine: OCREngine
    private let formatter: OCRFormatter
    
    public init(engine: OCREngine = VisionOCREngine(),
                formatter: OCRFormatter = TXTFormatter()) {
        self.engine = engine
        self.formatter = formatter
    }
    
    /// Process the request; for now runs serially because the recogniser is a stub.
    public func process(_ request: OCRRequest,
                        onProgress: ProgressHandler? = nil) async throws -> OCRResult {
        let total = request.images.count
        let pages = try await engine.recognize(request) { overall in
            let completed = Int(overall * Double(total))
            onProgress?(Progress(overall: overall,
                                 completed: completed,
                                 total: total))
        }
        // 结束兜底（确保 100 %）
        onProgress?(Progress(overall: 1,
                             completed: total,
                             total: total))
        return try formatter.generate(from: pages)
    }
}
