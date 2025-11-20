import Foundation
import PDFKit
import UIKit
import FoundationModels

// MARK: - 当前文档基础信息 ---------------------------------------------

struct CurrentDocumentInfoTool: Tool {
    let name = "getCurrentDocumentInfo"
    let description = "Returns metadata about the currently uploaded document (file name, size, type, page count)."

    @Generable
    struct Arguments: ConvertibleFromGeneratedContent { }

    @Generable
    struct Result: PromptRepresentable {
        var hasDocument: Bool
        var fileName: String?
        var fileSizeMB: Double?
        var isPDF: Bool
        var pageCount: Int?
    }

    /// 由外部 Demo 注入的当前文档 URL
    let documentURL: URL?

    func call(arguments: Arguments) async throws -> Result {
        guard let url = documentURL else {
            return Result(
                hasDocument: false,
                fileName: nil,
                fileSizeMB: nil,
                isPDF: false,
                pageCount: nil
            )
        }

        let fileName = url.lastPathComponent
        let ext = url.pathExtension.lowercased()
        let isPDF = (ext == "pdf")

        var sizeMB: Double? = nil
        do {
            let resource = try url.resourceValues(forKeys: [.fileSizeKey])
            if let bytes = resource.fileSize {
                sizeMB = Double(bytes) / (1024.0 * 1024.0)
            }
        } catch {
            // 读取不到体积就忽略，不作为致命错误
        }

        var pageCount: Int? = nil
        if isPDF, let pdf = PDFDocument(url: url) {
            pageCount = pdf.pageCount
        }

        return Result(
            hasDocument: true,
            fileName: fileName,
            fileSizeMB: sizeMB,
            isPDF: isPDF,
            pageCount: pageCount
        )
    }
}

// MARK: - 当前文档 OCR ---------------------------------------------------

struct CurrentDocumentOCRTool: Tool {
    let name = "ocrCurrentDocument"
    let description = "Runs OCR on the currently uploaded document (image or first page of a PDF)."

    @Generable
    struct Arguments: ConvertibleFromGeneratedContent {
        @Guide(description: "Optional page index for PDF (0-based)")
        var pageIndex: Int?
    }

    @Generable
    struct Result: PromptRepresentable {
        var text: String
        var note: String
    }

    let documentURL: URL?

    func call(arguments: Arguments) async throws -> Result {
        guard let url = documentURL else {
            return Result(
                text: "",
                note: "No document has been uploaded yet."
            )
        }

        let ext = url.pathExtension.lowercased()

        // PDF：取指定页（默认第 0 页），转成位图再 OCR
        if ext == "pdf" {
            guard let pdf = PDFDocument(url: url) else {
                throw NSError(
                    domain: "CurrentDocumentOCRTool",
                    code: -10,
                    userInfo: [NSLocalizedDescriptionKey: "无法打开 PDF 文档。"]
                )
            }

            let index = max(0, arguments.pageIndex ?? 0)
            guard index < pdf.pageCount, let page = pdf.page(at: index) else {
                throw NSError(
                    domain: "CurrentDocumentOCRTool",
                    code: -11,
                    userInfo: [NSLocalizedDescriptionKey: "PDF 页面索引超出范围。"]
                )
            }

            let box = page.bounds(for: .mediaBox)
            // 用 thumbnail 生成位图
            let thumbnail = page.thumbnail(of: box.size, for: .mediaBox)
            guard let cgImage = thumbnail.cgImage else {
                throw NSError(
                    domain: "CurrentDocumentOCRTool",
                    code: -12,
                    userInfo: [NSLocalizedDescriptionKey: "无法从 PDF 页面生成位图。"]
                )
            }

            let text = try await OCRKit.recognizeText(in: cgImage)
            return Result(
                text: text,
                note: "OCR on page \(index + 1) of current PDF."
            )
        } else {
            // 非 PDF：按图片处理
            guard let uiImage = UIImage(contentsOfFile: url.path),
                  let cgImage = uiImage.cgImage else {
                throw NSError(
                    domain: "CurrentDocumentOCRTool",
                    code: -13,
                    userInfo: [NSLocalizedDescriptionKey: "无法加载图片或获取 CGImage。"]
                )
            }

            let text = try await OCRKit.recognizeText(in: cgImage)
            return Result(
                text: text,
                note: "OCR on current image document."
            )
        }
    }
}
