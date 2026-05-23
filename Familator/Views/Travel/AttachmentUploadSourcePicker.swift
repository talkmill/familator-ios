import PhotosUI
import SwiftUI
import UIKit
import VisionKit

struct AttachmentUploadSourcePicker: View {
    let onPicked: (Data, String, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var activeSource: UploadSource?

    private enum UploadSource: String, Identifiable {
        case photoLibrary, camera, documentScanner, filePicker
        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            List {
                Button {
                    activeSource = .photoLibrary
                } label: {
                    Label("Photo Library", systemImage: "photo.on.rectangle")
                }

                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button {
                        activeSource = .camera
                    } label: {
                        Label("Camera", systemImage: "camera")
                    }
                }

                if VNDocumentCameraViewController.isSupported {
                    Button {
                        activeSource = .documentScanner
                    } label: {
                        Label("Scan Document", systemImage: "doc.viewfinder")
                    }
                }

                Button {
                    activeSource = .filePicker
                } label: {
                    Label("Choose File", systemImage: "folder")
                }
            }
            .navigationTitle("Add Attachment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(item: $activeSource) { source in
                switch source {
                case .photoLibrary:
                    PhotoLibraryPicker { data, filename, mimeType in
                        activeSource = nil
                        onPicked(data, filename, mimeType)
                    }
                case .camera:
                    CameraPicker { data, filename, mimeType in
                        activeSource = nil
                        onPicked(data, filename, mimeType)
                    }
                case .documentScanner:
                    DocumentScannerPicker { data, filename, mimeType in
                        activeSource = nil
                        onPicked(data, filename, mimeType)
                    }
                case .filePicker:
                    FilePickerView { data, filename, mimeType in
                        activeSource = nil
                        onPicked(data, filename, mimeType)
                    }
                }
            }
        }
    }
}

// MARK: - Photo Library (PHPicker)

struct PhotoLibraryPicker: UIViewControllerRepresentable {
    let onPicked: (Data, String, String) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.selectionLimit = 1
        config.filter = .images
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onPicked: onPicked) }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onPicked: (Data, String, String) -> Void

        init(onPicked: @escaping (Data, String, String) -> Void) {
            self.onPicked = onPicked
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard let result = results.first else { return }
            let provider = result.itemProvider

            if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                provider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
                    guard let image = object as? UIImage,
                          let jpegData = image.jpegData(compressionQuality: 0.85) else { return }
                    let filename = provider.suggestedName.map { "\($0).jpg" } ?? "photo.jpg"
                    DispatchQueue.main.async {
                        self?.onPicked(jpegData, filename, "image/jpeg")
                    }
                }
            }
        }
    }
}

// MARK: - Camera

struct CameraPicker: UIViewControllerRepresentable {
    let onPicked: (Data, String, String) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onPicked: onPicked) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onPicked: (Data, String, String) -> Void

        init(onPicked: @escaping (Data, String, String) -> Void) {
            self.onPicked = onPicked
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            picker.dismiss(animated: true)
            guard let image = info[.originalImage] as? UIImage,
                  let data = image.jpegData(compressionQuality: 0.85) else { return }
            let filename = "camera-\(UUID().uuidString.prefix(8)).jpg"
            onPicked(data, filename, "image/jpeg")
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

// MARK: - Document Scanner

struct DocumentScannerPicker: UIViewControllerRepresentable {
    let onPicked: (Data, String, String) -> Void

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let scanner = VNDocumentCameraViewController()
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onPicked: onPicked) }

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let onPicked: (Data, String, String) -> Void

        init(onPicked: @escaping (Data, String, String) -> Void) {
            self.onPicked = onPicked
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            controller.dismiss(animated: true)
            guard scan.pageCount > 0 else { return }
            // Upload each scanned page as a separate attachment
            for i in 0..<scan.pageCount {
                let image = scan.imageOfPage(at: i)
                guard let data = image.jpegData(compressionQuality: 0.9) else { continue }
                let suffix = scan.pageCount > 1 ? "-p\(i + 1)" : ""
                let filename = "scan-\(UUID().uuidString.prefix(8))\(suffix).jpg"
                onPicked(data, filename, "image/jpeg")
            }
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            controller.dismiss(animated: true)
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            controller.dismiss(animated: true)
        }
    }
}

// MARK: - File Picker

struct FilePickerView: UIViewControllerRepresentable {
    let onPicked: (Data, String, String) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.item])
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onPicked: onPicked) }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPicked: (Data, String, String) -> Void

        init(onPicked: @escaping (Data, String, String) -> Void) {
            self.onPicked = onPicked
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            guard url.startAccessingSecurityScopedResource() else { return }
            defer { url.stopAccessingSecurityScopedResource() }

            guard let data = try? Data(contentsOf: url) else { return }
            let filename = url.lastPathComponent
            let mimeType = mimeTypeForExtension(url.pathExtension)
            onPicked(data, filename, mimeType)
        }

        private func mimeTypeForExtension(_ ext: String) -> String {
            switch ext.lowercased() {
            case "jpg", "jpeg": return "image/jpeg"
            case "png": return "image/png"
            case "gif": return "image/gif"
            case "heic": return "image/heic"
            case "pdf": return "application/pdf"
            case "doc": return "application/msword"
            case "docx": return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
            case "xls": return "application/vnd.ms-excel"
            case "xlsx": return "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
            case "txt": return "text/plain"
            default: return "application/octet-stream"
            }
        }
    }
}
