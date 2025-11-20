import SwiftUI
import PhotosUI
import Vision

struct ImageTaggerView: View {
    // We continue to use our powerful AIEngine, configured for tagging.
    @StateObject private var aiEngine = AIEngine(configuration: .contentTagger)
    
    // MARK: - State Properties
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedImage: Image?
    @State private var visionKeywords: [String] = []
    @State private var tagResult: ContentTaggingResult.PartiallyGenerated?
    @State private var isLoading = false
    @State private var statusMessage: String = "Please select an image to begin."

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // MARK: - Image Display Area
                    if let selectedImage {
                        selectedImage
                            .resizable()
                            .scaledToFit()
                            .frame(height: 250)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                    } else {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.gray.opacity(0.1))
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.largeTitle)
                                .foregroundStyle(.gray.opacity(0.5))
                        }
                        .frame(height: 250)
                    }

                    // MARK: - Photo Picker
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        Label("Select Image", systemImage: "photo")
                    }
                    .buttonStyle(.bordered)
                    
                    // MARK: - Status & Results
                    if isLoading {
                        ProgressView { Text(statusMessage) }
                    } else {
                        // Display VisionKit's initial findings
                        if !visionKeywords.isEmpty {
                            VStack {
                                Text("VisionKit Keywords").font(.headline)
                                Text(visionKeywords.joined(separator: ", "))
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        // Display the AI Engine's rich tags
                        if let result = tagResult {
                            TagResultView(result: result)
                        }
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Image Tagger")
            .onChange(of: selectedPhotoItem) {
                Task {
                    await processImage(from: selectedPhotoItem)
                }
            }
        }
    }
    
    // MARK: - Processing Logic
    
    /// The main orchestration function that chains VisionKit and AIEngine.
    private func processImage(from item: PhotosPickerItem?) async {
        guard let item else { return }
        
        // 1. Reset state and start loading
        isLoading = true
        statusMessage = "Loading image..."
        visionKeywords = []
        tagResult = nil
        
        do {
            // 2. Load image data from PhotosPickerItem
            guard let data = try await item.loadTransferable(type: Data.self),
                  let uiImage = UIImage(data: data) else {
                throw NSError(domain: "ImageTaggerError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not load image data."])
            }
            await MainActor.run {
                self.selectedImage = Image(uiImage: uiImage)
            }
            
            // 3. Perform VisionKit image classification
            statusMessage = "Analyzing image with VisionKit..."
            let keywords = try await performVisionRequest(on: uiImage)
            await MainActor.run {
                self.visionKeywords = keywords
            }
            
            // 4. Use VisionKit's keywords to prompt the AIEngine
            statusMessage = "Generating rich tags with AI..."
            let prompt = "Generate content tags for a scene described by these keywords: \(keywords.joined(separator: ", ")). Focus on potential actions, emotions, objects, and overall topics."
            let stream = aiEngine.generate(structuredResponseFor: prompt, ofType: ContentTaggingResult.self)
            
            for try await partialResult in stream {
                self.tagResult = partialResult
            }
            
        } catch {
            statusMessage = "Error: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    /// Performs an image classification request using VisionKit.
    private func performVisionRequest(on image: UIImage) async throws -> [String] {
        return try await withCheckedThrowingContinuation { continuation in
            guard let cgImage = image.cgImage else {
                continuation.resume(throwing: NSError(domain: "ImageTaggerError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not get CGImage."]))
                return
            }
            
            let request = VNClassifyImageRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let observations = request.results as? [VNClassificationObservation] else {
                    continuation.resume(returning: [])
                    return
                }
                
                // Take the top 5 most confident results from VisionKit
                let keywords = observations
                    .prefix(5)
                    .map { $0.identifier.components(separatedBy: ", ").first ?? "" } // Clean up the identifiers
                continuation.resume(returning: keywords)
            }
            
            let handler = VNImageRequestHandler(cgImage: cgImage)
            try? handler.perform([request])
        }
    }
}
