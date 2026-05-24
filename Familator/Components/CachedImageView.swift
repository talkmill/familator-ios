import SwiftUI
import NukeUI
import Nuke

struct CachedImageView: View {
    let bucket: String
    let storagePath: String
    var contentMode: ContentMode = .fill

    @State private var imageRequest: ImageRequest?
    @State private var loadError: Error?

    var body: some View {
        Group {
            if let imageRequest {
                LazyImage(request: imageRequest) { state in
                    if let image = state.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: contentMode)
                    } else if state.error != nil {
                        errorPlaceholder
                    } else {
                        ProgressView()
                    }
                }
                .pipeline(ImageCacheService.shared.pipeline)
            } else if loadError != nil {
                errorPlaceholder
            } else {
                ProgressView()
            }
        }
        .task(id: "\(bucket)/\(storagePath)") {
            imageRequest = nil
            loadError = nil
            do {
                imageRequest = try await ImageCacheService.shared.imageRequest(
                    bucket: bucket,
                    storagePath: storagePath
                )
            } catch {
                loadError = error
            }
        }
    }

    private var errorPlaceholder: some View {
        Image(systemName: "photo")
            .font(.title2)
            .foregroundStyle(.secondary)
    }
}
