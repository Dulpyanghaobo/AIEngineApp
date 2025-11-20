//
//  ClassificationResult.swift
//  AIEngineApp
//
//  Created by i564407 on 10/8/25.
//


import SwiftUI
import Vision
import AVFoundation
import Combine

struct VisionConfig {
    var maxResults: Int = 10
    var confidenceThreshold: Float = 0.1
    var minFrameInterval: TimeInterval = 0.3 // 每秒约3帧
    var enableObjectDetection: Bool = false
    var enableTextRecognition: Bool = false
}

// MARK: - 分类结果模型
struct ClassificationResult: Identifiable {
    let id = UUID()
    let label: String
    let confidence: Float
    
    var confidencePercentage: String {
        String(format: "%.1f%%", confidence * 100)
    }
}

struct ObjectDetectionResult: Identifiable {
    let id = UUID()
    let label: String
    let confidence: Float
    let boundingBox: CGRect
}

// MARK: - 文本识别结果
struct TextRecognitionResult: Identifiable {
    let id = UUID()
    let text: String
    let confidence: Float
    let boundingBox: CGRect
}

struct VisionAnalysisResult {
    var classifications: [ClassificationResult] = []
    var objects: [ObjectDetectionResult] = []
    var texts: [TextRecognitionResult] = []
}

// MARK: - 图像分类器核心类
@MainActor
class VisionClassifier: ObservableObject {
    @Published var results: VisionAnalysisResult = VisionAnalysisResult()
    @Published var isProcessing = false
    @Published var error: Error?
    
    private var config: VisionConfig
    private var customModel: VNCoreMLModel?
    
    // 性能优化：复用 request 对象
    private lazy var classificationRequest: VNClassifyImageRequest = {
        let request = VNClassifyImageRequest()
        return request
    }()
    
    private lazy var objectDetectionRequest: VNCoreMLRequest? = {
        // 使用系统默认的物体检测模型
        guard let model = try? VNCoreMLModel(for: createObjectDetectionModel()) else {
            return nil
        }
        let request = VNCoreMLRequest(model: model)
        request.imageCropAndScaleOption = .scaleFill
        return request
    }()
    
    private lazy var textRecognitionRequest: VNRecognizeTextRequest = {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        return request
    }()
    
    init(config: VisionConfig = VisionConfig()) {
        self.config = config
    }
    
    // MARK: - 配置方法
    
    func updateConfig(_ newConfig: VisionConfig) {
        self.config = newConfig
    }
    
    /// 加载自定义 CoreML 模型
    func loadCustomModel(from url: URL) throws {
        let mlModel = try MLModel(contentsOf: url)
        self.customModel = try VNCoreMLModel(for: mlModel)
    }
    
    /// 加载自定义 CoreML 模型（从已编译的模型）
    func loadCustomModel(_ mlModel: MLModel) throws {
        self.customModel = try VNCoreMLModel(for: mlModel)
    }
    
    // MARK: - 公共接口
    
    /// 综合分析图像（分类 + 物体检测 + 文本识别）
    func analyze(_ image: UIImage) async throws -> VisionAnalysisResult {
        guard let cgImage = image.cgImage else {
            throw ClassificationError.invalidImage
        }
        return try await analyze(cgImage)
    }
    
    /// 综合分析 CGImage
    func analyze(_ cgImage: CGImage) async throws -> VisionAnalysisResult {
        isProcessing = true
        defer { isProcessing = false }
        
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: ClassificationError.processingFailed)
                    return
                }
                
                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                var requests: [VNRequest] = []
                var result = VisionAnalysisResult()
                
                // 1. 图像分类
                let classRequest = self.customModel != nil ?
                    VNCoreMLRequest(model: self.customModel!) :
                    self.classificationRequest
                requests.append(classRequest)
                
                // 2. 物体检测
                if self.config.enableObjectDetection, let objRequest = self.objectDetectionRequest {
                    requests.append(objRequest)
                }
                
                // 3. 文本识别
                if self.config.enableTextRecognition {
                    requests.append(self.textRecognitionRequest)
                }
                
                do {
                    try handler.perform(requests)
                    
                    // 处理分类结果
                    if let classificationResults = classRequest.results as? [VNClassificationObservation] {
                        result.classifications = classificationResults
                            .filter { $0.confidence >= self.config.confidenceThreshold }
                            .prefix(self.config.maxResults)
                            .map { ClassificationResult(label: $0.identifier, confidence: $0.confidence) }
                            .map { $0 }
                    }
                    
                    // 处理物体检测结果
                    if self.config.enableObjectDetection,
                       let objectRequest = self.objectDetectionRequest,
                       let observations = objectRequest.results as? [VNRecognizedObjectObservation] {
                        result.objects = observations
                            .filter { $0.confidence >= self.config.confidenceThreshold }
                            .prefix(self.config.maxResults)
                            .map { obs in
                                ObjectDetectionResult(
                                    label: obs.labels.first?.identifier ?? "Unknown",
                                    confidence: obs.confidence,
                                    boundingBox: obs.boundingBox
                                )
                            }
                    }
                    
                    // 处理文本识别结果
                    if self.config.enableTextRecognition,
                       let observations = self.textRecognitionRequest.results {
                        result.texts = observations
                            .compactMap { observation -> TextRecognitionResult? in
                                guard let candidate = observation.topCandidates(1).first else { return nil }
                                return TextRecognitionResult(
                                    text: candidate.string,
                                    confidence: candidate.confidence,
                                    boundingBox: observation.boundingBox
                                )
                            }
                            .filter { $0.confidence >= self.config.confidenceThreshold }
                    }
                    
                    continuation.resume(returning: result)
                    
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// 分类 UIImage（简化接口）
    func classify(_ image: UIImage) async throws -> [ClassificationResult] {
        let result = try await analyze(image)
        return result.classifications
    }
    
    /// 分类 CGImage
    func classify(_ cgImage: CGImage) async throws -> [ClassificationResult] {
        let result = try await analyze(cgImage)
        return result.classifications
    }
    
    /// 分类 CVPixelBuffer（高性能接口，用于实时视频）
    func classify(_ pixelBuffer: CVPixelBuffer) async throws -> [ClassificationResult] {
        isProcessing = true
        defer { isProcessing = false }
        
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: ClassificationError.processingFailed)
                    return
                }
                
                let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
                let request = self.customModel != nil ?
                    VNCoreMLRequest(model: self.customModel!) :
                    self.classificationRequest
                
                do {
                    try handler.perform([request])
                    
                    guard let observations = request.results as? [VNClassificationObservation] else {
                        continuation.resume(throwing: ClassificationError.noResults)
                        return
                    }
                    
                    let results = observations
                        .filter { $0.confidence >= self.config.confidenceThreshold }
                        .prefix(self.config.maxResults)
                        .map { ClassificationResult(label: $0.identifier, confidence: $0.confidence) }
                    
                    continuation.resume(returning: Array(results))
                    
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// 综合分析 CVPixelBuffer
    func analyzePixelBuffer(_ pixelBuffer: CVPixelBuffer) async throws -> VisionAnalysisResult {
        isProcessing = true
        defer { isProcessing = false }
        
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: ClassificationError.processingFailed)
                    return
                }
                
                let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
                var requests: [VNRequest] = []
                var result = VisionAnalysisResult()
                
                let classRequest = self.customModel != nil ?
                    VNCoreMLRequest(model: self.customModel!) :
                    self.classificationRequest
                requests.append(classRequest)
                
                if self.config.enableObjectDetection, let objRequest = self.objectDetectionRequest {
                    requests.append(objRequest)
                }
                
                if self.config.enableTextRecognition {
                    requests.append(self.textRecognitionRequest)
                }
                
                do {
                    try handler.perform(requests)
                    
                    if let classificationResults = classRequest.results as? [VNClassificationObservation] {
                        result.classifications = classificationResults
                            .filter { $0.confidence >= self.config.confidenceThreshold }
                            .prefix(self.config.maxResults)
                            .map { ClassificationResult(label: $0.identifier, confidence: $0.confidence) }
                            .map { $0 }
                    }
                    
                    if self.config.enableObjectDetection,
                       let objectRequest = self.objectDetectionRequest,
                       let observations = objectRequest.results as? [VNRecognizedObjectObservation] {
                        result.objects = observations
                            .filter { $0.confidence >= self.config.confidenceThreshold }
                            .prefix(self.config.maxResults)
                            .map { obs in
                                ObjectDetectionResult(
                                    label: obs.labels.first?.identifier ?? "Unknown",
                                    confidence: obs.confidence,
                                    boundingBox: obs.boundingBox
                                )
                            }
                    }
                    
                    if self.config.enableTextRecognition,
                       let observations = self.textRecognitionRequest.results {
                        result.texts = observations
                            .compactMap { observation -> TextRecognitionResult? in
                                guard let candidate = observation.topCandidates(1).first else { return nil }
                                return TextRecognitionResult(
                                    text: candidate.string,
                                    confidence: candidate.confidence,
                                    boundingBox: observation.boundingBox
                                )
                            }
                            .filter { $0.confidence >= self.config.confidenceThreshold }
                    }
                    
                    continuation.resume(returning: result)
                    
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - 辅助方法
    
    private func createObjectDetectionModel() -> MLModel {
        // 这里返回一个占位符，实际使用时需要提供真实的物体检测模型
        // 例如: YOLOv5, MobileNetSSD 等
        // 由于系统限制，这里使用分类模型作为示例
        return MLModel()
    }
}

// MARK: - 错误定义
enum ClassificationError: LocalizedError {
    case invalidImage
    case noResults
    case processingFailed
    case cameraUnavailable
    case modelLoadFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidImage: return "无效的图像"
        case .noResults: return "未检测到分类结果"
        case .processingFailed: return "处理失败"
        case .cameraUnavailable: return "相机不可用"
        case .modelLoadFailed: return "模型加载失败"
        }
    }
}

// MARK: - 相机捕获管理器（增强版）
@MainActor
class CameraClassificationManager: NSObject, ObservableObject {
    @Published var results: VisionAnalysisResult = VisionAnalysisResult()
    @Published var isRunning = false
    @Published var currentFPS: Double = 0
    
    private let classifier: VisionClassifier
    private var captureSession: AVCaptureSession?
    private var videoOutput: AVCaptureVideoDataOutput?
    private let videoQueue = DispatchQueue(label: "com.vision.video", qos: .userInteractive)
    
    // 性能监控
    private var lastProcessTime: Date = .distantPast
    private var frameCount: Int = 0
    private var fpsTimer: Timer?
    
    var config: VisionConfig {
        didSet {
            classifier.updateConfig(config)
        }
    }
    
    init(config: VisionConfig = VisionConfig()) {
        self.classifier = VisionClassifier()
        self.config = config
        super.init()
        
        // FPS 计算定时器
        fpsTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.currentFPS = Double(self.frameCount)
                self.frameCount = 0
            }
        }
    }
    
    deinit {
        fpsTimer?.invalidate()
    }
    
    func startCamera() async throws {
        guard captureSession == nil else { return }
        
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        if status != .authorized {
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            guard granted else {
                throw ClassificationError.cameraUnavailable
            }
        }
        
        let session = AVCaptureSession()
        session.sessionPreset = .high
        
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: camera) else {
            throw ClassificationError.cameraUnavailable
        }
        
        session.addInput(input)
        
        let output = AVCaptureVideoDataOutput()
        output.setSampleBufferDelegate(self, queue: videoQueue)
        output.alwaysDiscardsLateVideoFrames = true
        
        // 设置像素格式以提高性能
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        
        session.addOutput(output)
        
        self.captureSession = session
        self.videoOutput = output
        
        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }
        
        isRunning = true
    }
    
    func stopCamera() {
        captureSession?.stopRunning()
        captureSession = nil
        videoOutput = nil
        isRunning = false
        currentFPS = 0
    }
    
    func updateFrameInterval(_ interval: TimeInterval) {
        config.minFrameInterval = interval
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension CameraClassificationManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        Task { @MainActor in
            let now = Date()
            
            // This logic is now safely running on the Main Actor
            guard now.timeIntervalSince(self.lastProcessTime) >= self.config.minFrameInterval else { return }
            self.lastProcessTime = now
            
            // The rest of the logic can continue safely here
            do {
                let analysisResult = try await self.classifier.analyzePixelBuffer(pixelBuffer)
                self.results = analysisResult
                self.frameCount += 1
            } catch {
                print("分析错误: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - 相册选择器
struct PhotoPickerView: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.dismiss) var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: PhotoPickerView
        
        init(_ parent: PhotoPickerView) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - 配置面板
struct ConfigurationPanel: View {
    @Binding var config: VisionConfig
    
    var body: some View {
        Form {
            Section("基础设置") {
                Stepper("最大结果数: \(config.maxResults)", value: $config.maxResults, in: 1...20)
                
                VStack(alignment: .leading) {
                    Text("置信度阈值: \(String(format: "%.2f", config.confidenceThreshold))")
                    Slider(value: $config.confidenceThreshold, in: 0.01...1.0)
                }
                
                VStack(alignment: .leading) {
                    Text("帧间隔: \(String(format: "%.2f", config.minFrameInterval))s")
                    Slider(value: $config.minFrameInterval, in: 0.1...2.0)
                }
            }
            
            Section("功能开关") {
                Toggle("物体检测", isOn: $config.enableObjectDetection)
                Toggle("文字识别", isOn: $config.enableTextRecognition)
            }
        }
    }
}

// MARK: - 增强版相机视图
struct EnhancedCameraView: View {
    @StateObject private var manager: CameraClassificationManager
    @State private var showSettings = false
    @State private var config = VisionConfig(
        maxResults: 10,
        confidenceThreshold: 0.1,
        minFrameInterval: 0.3,
        enableObjectDetection: true,
        enableTextRecognition: true
    )
    
    init() {
        let config = VisionConfig(
            maxResults: 10,
            confidenceThreshold: 0.1,
            minFrameInterval: 0.3,
            enableObjectDetection: true,
            enableTextRecognition: true
        )
        _manager = StateObject(wrappedValue: CameraClassificationManager(config: config))
        _config = State(initialValue: config)
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack {
                HStack {
                    Text("实时视觉分析")
                        .font(.title2)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Text("FPS: \(String(format: "%.1f", manager.currentFPS))")
                        .font(.caption)
                        .foregroundColor(.green)
                        .padding(8)
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(8)
                    
                    Button(action: { showSettings.toggle() }) {
                        Image(systemName: "gear")
                            .foregroundColor(.white)
                            .font(.title3)
                    }
                }
                .padding()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // 分类结果
                        if !manager.results.classifications.isEmpty {
                            ResultSection(title: "图像分类", icon: "tag.fill") {
                                ForEach(manager.results.classifications) { result in
                                    ResultRow(label: result.label, confidence: result.confidencePercentage)
                                }
                            }
                        }
                        
                        // 物体检测结果
                        if !manager.results.objects.isEmpty {
                            ResultSection(title: "物体检测", icon: "scope") {
                                ForEach(manager.results.objects) { obj in
                                    ResultRow(
                                        label: obj.label,
                                        confidence: String(format: "%.1f%%", obj.confidence * 100)
                                    )
                                }
                            }
                        }
                        
                        // 文本识别结果
                        if !manager.results.texts.isEmpty {
                            ResultSection(title: "文字识别", icon: "text.viewfinder") {
                                ForEach(manager.results.texts) { text in
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(text.text)
                                            .font(.body)
                                        Text(String(format: "置信度: %.1f%%", text.confidence * 100))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.white)
                                    .cornerRadius(8)
                                }
                            }
                        }
                    }
                    .padding()
                }
                
                Spacer()
                
                Button(action: {
                    if manager.isRunning {
                        manager.stopCamera()
                    } else {
                        Task {
                            try? await manager.startCamera()
                        }
                    }
                }) {
                    HStack {
                        Image(systemName: manager.isRunning ? "stop.circle.fill" : "play.circle.fill")
                        Text(manager.isRunning ? "停止" : "开始")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(width: 200, height: 50)
                    .background(manager.isRunning ? Color.red : Color.blue)
                    .cornerRadius(25)
                }
                .padding()
            }
        }
        .sheet(isPresented: $showSettings) {
            NavigationView {
                ConfigurationPanel(config: $config)
                    .navigationTitle("设置")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("完成") {
                                manager.config = config
                                showSettings = false
                            }
                        }
                    }
            }
        }
    }
}

// MARK: - 辅助视图组件
struct ResultSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                Text(title)
                    .font(.headline)
            }
            .foregroundColor(.white)
            
            VStack(spacing: 8) {
                content
            }
        }
    }
}

struct ResultRow: View {
    let label: String
    let confidence: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.body)
            Spacer()
            Text(confidence)
                .font(.caption)
                .foregroundColor(.green)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(8)
    }
}

// MARK: - 增强版相册视图
struct EnhancedPhotoView: View {
    @StateObject private var classifier: VisionClassifier
    @State private var selectedImage: UIImage?
    @State private var showPicker = false
    @State private var showSettings = false
    @State private var config = VisionConfig(
        maxResults: 10,
        confidenceThreshold: 0.1,
        enableObjectDetection: true,
        enableTextRecognition: true
    )
    
    init() {
        let config = VisionConfig(
            maxResults: 10,
            confidenceThreshold: 0.1,
            enableObjectDetection: true,
            enableTextRecognition: true
        )
        _classifier = StateObject(wrappedValue: VisionClassifier(config: config))
        _config = State(initialValue: config)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if let image = selectedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 300)
                        .cornerRadius(10)
                        .padding()
                } else {
                    VStack {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 80))
                            .foregroundColor(.gray)
                        Text("选择一张图片开始分析")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: 300)
                }
                
                Button("选择图片") {
                    showPicker = true
                }
                .buttonStyle(.borderedProminent)
                
                if classifier.isProcessing {
                    ProgressView("分析中...")
                }
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if !classifier.results.classifications.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("图像分类", systemImage: "tag.fill")
                                    .font(.headline)
                                
                                ForEach(classifier.results.classifications) { result in
                                    HStack {
                                        Text(result.label)
                                        Spacer()
                                        Text(result.confidencePercentage)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(10)
                        }
                        
                        if !classifier.results.objects.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("物体检测", systemImage: "scope")
                                    .font(.headline)
                                
                                ForEach(classifier.results.objects) { obj in
                                    HStack {
                                        Text(obj.label)
                                        Spacer()
                                        Text(String(format: "%.1f%%", obj.confidence * 100))
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(10)
                        }
                        
                        if !classifier.results.texts.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("文字识别", systemImage: "text.viewfinder")
                                    .font(.headline)
                                
                                ForEach(classifier.results.texts) { text in
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(text.text)
                                        Text(String(format: "置信度: %.1f%%", text.confidence * 100))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                            .padding()
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(10)
                        }
                    }
                    .padding()
                }
                
                Spacer()
            }
            .navigationTitle("图片分析")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showSettings.toggle() }) {
                        Image(systemName: "gear")
                    }
                }
            }
            .sheet(isPresented: $showPicker) {
                PhotoPickerView(selectedImage: $selectedImage)
            }
            .sheet(isPresented: $showSettings) {
                NavigationView {
                    ConfigurationPanel(config: $config)
                        .navigationTitle("设置")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("完成") {
                                    classifier.updateConfig(config)
                                    showSettings = false
                                }
                            }
                        }
                }
            }
            .onChange(of: selectedImage) { _, newImage in
                if let image = newImage {
                    Task {
                        do {
                            let result = try await classifier.analyze(image)
                            classifier.results = result
                        } catch {
                            classifier.error = error
                        }
                    }
                }
            }
        }
    }
}

// MARK: - 自定义模型管理视图
struct CustomModelView: View {
    @StateObject private var classifier = VisionClassifier()
    @State private var modelLoaded = false
    @State private var modelName = "未加载"
    @State private var showFilePicker = false
    @State private var selectedImage: UIImage?
    @State private var showImagePicker = false
    @State private var config = VisionConfig(maxResults: 10, confidenceThreshold: 0.1)
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // 模型状态卡片
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: modelLoaded ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(modelLoaded ? .green : .gray)
                            .font(.title)
                        
                        VStack(alignment: .leading) {
                            Text("模型状态")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(modelName)
                                .font(.headline)
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                    
                    Text("支持 .mlmodel 和 .mlmodelc 格式")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                
                // 功能按钮
                VStack(spacing: 16) {
                    Button(action: {
                        // 这里应该打开文件选择器
                        // 由于 SwiftUI 限制，这里用模拟演示
                        loadDemoModel()
                    }) {
                        HStack {
                            Image(systemName: "square.and.arrow.down")
                            Text("加载自定义模型")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.blue)
                        .cornerRadius(12)
                    }
                    
                    if modelLoaded {
                        Button(action: {
                            showImagePicker = true
                        }) {
                            HStack {
                                Image(systemName: "photo")
                                Text("测试模型")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.green)
                            .cornerRadius(12)
                        }
                    }
                }
                .padding(.horizontal)
                
                // 测试结果展示
                if let image = selectedImage {
                    VStack(spacing: 16) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 200)
                            .cornerRadius(12)
                        
                        if classifier.isProcessing {
                            ProgressView("处理中...")
                        } else if !classifier.results.classifications.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("分类结果")
                                    .font(.headline)
                                
                                ForEach(classifier.results.classifications) { result in
                                    HStack {
                                        Text(result.label)
                                        Spacer()
                                        Text(result.confidencePercentage)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
                
                // 使用说明
                VStack(alignment: .leading, spacing: 8) {
                    Text("使用说明")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Label("支持 CoreML 格式模型", systemImage: "1.circle.fill")
                        Label("可用于图像分类任务", systemImage: "2.circle.fill")
                        Label("自动调整输入尺寸", systemImage: "3.circle.fill")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal)
            }
            .padding(.vertical)
            .navigationTitle("自定义模型")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showImagePicker) {
                PhotoPickerView(selectedImage: $selectedImage)
            }
            .onChange(of: selectedImage) { _, newImage in
                if let image = newImage, modelLoaded {
                    Task {
                        do {
                            let result = try await classifier.analyze(image)
                            classifier.results = result
                        } catch {
                            print("分类错误: \(error)")
                        }
                    }
                }
            }
        }
    }
    
    private func loadDemoModel() {
        // 模拟加载模型
        modelLoaded = true
        modelName = "MobileNetV2 (示例)"
        
        // 在实际使用中，你需要这样加载模型：
        // if let modelURL = Bundle.main.url(forResource: "YourModel", withExtension: "mlmodelc") {
        //     do {
        //         try classifier.loadCustomModel(from: modelURL)
        //         modelLoaded = true
        //         modelName = "YourModel"
        //     } catch {
        //         print("模型加载失败: \(error)")
        //     }
        // }
    }
}
