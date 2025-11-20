import Foundation
import UniformTypeIdentifiers
import PDFKit
import UIKit

/// 负责从 URL 解析文本（支持 txt / pdf / image），并按页拆分
actor AttachmentTextLoader {
    
    func loadDocument(from url: URL, name: String? = nil) async throws -> AttachmentDocument {
        let resourceValues = try url.resourceValues(forKeys: [.contentTypeKey])
        let type = resourceValues.contentType
        
        if type?.conforms(to: .plainText) == true {
            return try loadPlainText(from: url, name: name)
        } else if type?.conforms(to: .pdf) == true {
            return try await loadPDF(from: url, name: name)
        } else if type?.conforms(to: .image) == true {
            return try await loadImage(from: url, name: name)
        } else {
            // 尝试按纯文本解析
            return try loadPlainText(from: url, name: name)
        }
    }
    
    // MARK: - txt
    
    private func loadPlainText(from url: URL, name: String?) throws -> AttachmentDocument {
        let data = try Data(contentsOf: url)
        guard let text = String(data: data, encoding: .utf8) else {
            throw NSError(
                domain: "AttachmentTextLoader",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "无法以 UTF-8 解码文件内容，请确认是文本文件。"]
            )
        }
        
        let page = AttachmentPage(index: 1, text: text)
        return .init(
            name: name ?? url.lastPathComponent,
            fullText: text,
            pages: [page]
        )
    }
    
    // MARK: - PDF（按页拆分，强制走图片 OCR）
    
    private func loadPDF(from url: URL, name: String?) async throws -> AttachmentDocument {
        guard let pdf = PDFDocument(url: url) else {
            throw NSError(
                domain: "AttachmentTextLoader",
                code: -2,
                userInfo: [NSLocalizedDescriptionKey: "无法打开 PDF 文档。"]
            )
        }
        
        var pages: [AttachmentPage] = []
        let pageCount = pdf.pageCount
        
        for index in 0..<pageCount {
            guard let page = pdf.page(at: index) else { continue }
            
            // 直接把每一页当成图片做 OCR
            let uiImage = page.thumbnail(of: CGSize(width: 1200, height: 1600),
                                         for: .mediaBox)
            guard let cgImage = uiImage.cgImage else { continue }
            
            // 使用 OCRKit 识别文字
            let text = try await OCRKit.recognizeText(in: cgImage)
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            
            let pageModel = AttachmentPage(index: index + 1, text: trimmed)
            pages.append(pageModel)
        }
        
        guard !pages.isEmpty else {
            throw NSError(
                domain: "AttachmentTextLoader",
                code: -3,
                userInfo: [NSLocalizedDescriptionKey: "无法从 PDF 中提取文本（图片 OCR 结果为空）。"]
            )
        }
        
        let fullText = pages
            .sorted { $0.index < $1.index }
            .map { "Page \($0.index)\n\($0.text)" }
            .joined(separator: "\n\n----- Page Break -----\n\n")
        
        return .init(
            name: name ?? url.lastPathComponent,
            fullText: fullText,
            pages: pages
        )
    }
    
    // MARK: - 图片（视作一页，同样走 OCRKit）
    
    private func loadImage(from url: URL, name: String?) async throws -> AttachmentDocument {
        guard let uiImage = UIImage(contentsOfFile: url.path),
              let cgImage = uiImage.cgImage else {
            throw NSError(
                domain: "AttachmentTextLoader",
                code: -4,
                userInfo: [NSLocalizedDescriptionKey: "无法加载图片或获取 CGImage。"]
            )
        }
        
        let text = try await OCRKit.recognizeText(in: cgImage)
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmed.isEmpty else {
            throw NSError(
                domain: "AttachmentTextLoader",
                code: -5,
                userInfo: [NSLocalizedDescriptionKey: "未从图片中识别到文本。"]
            )
        }
        
        let page = AttachmentPage(index: 1, text: trimmed)
        return .init(
            name: name ?? url.lastPathComponent,
            fullText: trimmed,
            pages: [page]
        )
    }
}
