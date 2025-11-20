import SwiftUI
import Vision
import PhotosUI
import FoundationModels

struct AIWatermarkView: View {
    @StateObject private var aiEngine = AIEngine(configuration: .contentTagger)

    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedImage: Image?
    @State private var tagResult: ContentTaggingResult.PartiallyGenerated?
    @State private var isLoading = false
    @State private var statusMessage: String = "Select an image to generate an AI Watermark."
    
    @State private var visionKeywords: [String] = []
    
    let rawContextData = "Location: San Francisco. Time: 5:30 PM. Weather: Foggy."

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    if let selectedImage {
                        selectedImage
                            .resizable()
                            .scaledToFit()
                            .frame(height: 250)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.1))
                            Image(systemName: "photo.on.rectangle.angled").font(.largeTitle).foregroundStyle(.gray.opacity(0.5))
                        }
                        .frame(height: 250)
                    }

                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        Label("Select Image", systemImage: "photo")
                    }
                    .buttonStyle(.bordered)
                    
                    if isLoading {
                        ProgressView { Text(statusMessage) }
                    } else if let tagResult {
                        TagResultView(result: tagResult)
                    } else {
                        Text(statusMessage).foregroundStyle(.secondary)
                    }
                }
                .padding()
            }
            .navigationTitle("AI Watermark Camera")
            .onChange(of: selectedPhotoItem) {
                Task {
                    await generateWatermark(from: selectedPhotoItem)
                }
            }
        }
    }
    
    private func generateWatermark(from item: PhotosPickerItem?) async {
        guard let item else { return }
        
        isLoading = true
        statusMessage = "Analyzing image..."
        tagResult = nil
        visionKeywords = []
        
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let uiImage = UIImage(data: data) else { throw URLError(.cannotDecodeContentData) }
            
            await MainActor.run { self.selectedImage = Image(uiImage: uiImage) }
            
            let keywords = try await performVisionRequest(on: uiImage)
            await MainActor.run {
                self.visionKeywords = keywords
            }
            
            statusMessage = "Generating AI Watermark..."

            let prompt = """
                        Generate content tags for a scene described by these keywords: \(keywords.joined(separator: ", ")). Focus on potential actions, emotions, objects, and overall topics.
            """
            
            let stream = aiEngine.generate(structuredResponseFor: prompt, ofType: ContentTaggingResult.self)
            
            for try await partialWatermark in stream {
                self.tagResult = partialWatermark
            }
            
        } catch {
            statusMessage = "Error: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    // --- FIX: This function has been made robust ---
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
                
                let keywords = observations
                    .prefix(10)
                    .map { $0.identifier.components(separatedBy: ", ").first ?? "" }
                continuation.resume(returning: keywords)
            }
            
            let handler = VNImageRequestHandler(cgImage: cgImage)
            
            // Dispatch the synchronous perform call to a background thread
            // and use a do-catch block to properly handle errors.
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])
                } catch {
                    // If perform fails, resume the continuation with the error.
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
