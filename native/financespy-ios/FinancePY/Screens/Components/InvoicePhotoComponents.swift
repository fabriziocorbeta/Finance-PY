import SwiftUI
import PhotosUI
import UIKit

// MARK: - Camera Picker

struct CameraImagePicker: UIViewControllerRepresentable {
    let sourceType: UIImagePickerController.SourceType
    let onImagePicked: (Data, String) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(sourceType) ? sourceType : .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: CameraImagePicker

        init(_ parent: CameraImagePicker) {
            self.parent = parent
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage,
               let jpegData = image.jpegData(compressionQuality: 0.82) {
                let name = "factura_\(Int(Date().timeIntervalSince1970)).jpg"
                parent.onImagePicked(jpegData, name)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - Fullscreen Invoice Photo Viewer

struct InvoicePhotoViewerSheet: View {
    let imageData: Data
    let filename: String?
    let onDelete: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1.0
    @State private var showDeleteConfirm = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                if let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .scaleEffect(scale)
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    scale = min(max(value, 1.0), 4.0)
                                }
                        )
                        .onTapGesture(count: 2) {
                            withAnimation {
                                scale = scale > 1.0 ? 1.0 : 2.5
                            }
                        }
                } else {
                    Text("No se pudo mostrar la imagen.")
                        .foregroundColor(.white)
                }
            }
            .navigationTitle(filename ?? "Factura")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                }
                if let onDelete {
                    ToolbarItem(placement: .destructiveAction) {
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            Image(systemName: "trash")
                        }
                    }
                }
            }
            .alert("Eliminar foto de factura", isPresented: $showDeleteConfirm) {
                Button("Cancelar", role: .cancel) {}
                Button("Eliminar", role: .destructive) {
                    onDelete?()
                    dismiss()
                }
            } message: {
                Text("¿Seguro que querés eliminar la foto adjunta?")
            }
        }
    }
}

// MARK: - Reusable Invoice Photo Section

struct InvoicePhotoSectionView: View {
    let title: String
    let hasRemotePhoto: Bool
    let remoteFilename: String?
    let imageData: Data?
    let isLoading: Bool
    let isUploading: Bool
    let onPickImage: (Data, String) -> Void
    let onDeletePhoto: (() -> Void)?

    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var showViewer = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(title, systemImage: "doc.text.image")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if isUploading {
                    ProgressView()
                        .scaleEffect(0.85)
                }
            }

            if let imageData, let uiImage = UIImage(data: imageData) {
                Button {
                    showViewer = true
                } label: {
                    ZStack(alignment: .bottomTrailing) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: 180)
                            .clipped()
                            .cornerRadius(12)

                        Label("Ver", systemImage: "arrow.up.left.and.arrow.down.right")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                            .padding(8)
                    }
                }
                .buttonStyle(.plain)
            } else if isLoading {
                HStack {
                    ProgressView()
                    Text("Cargando foto de factura...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 80)
            } else if hasRemotePhoto {
                Text("Foto adjunta: \(remoteFilename ?? "factura.jpg")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text("Sin foto de factura adjunta")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 10) {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button {
                        showCamera = true
                    } label: {
                        Label("Cámara", systemImage: "camera")
                            .font(.caption.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(isUploading)
                }

                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    Label("Galería", systemImage: "photo.on.rectangle")
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(isUploading)

                if (imageData != nil || hasRemotePhoto), let onDeletePhoto {
                    Button(role: .destructive) {
                        onDeletePhoto()
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.bordered)
                    .disabled(isUploading)
                }
            }
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self) {
                    let compressed = UIImage(data: data)?.jpegData(compressionQuality: 0.82) ?? data
                    let name = "factura_\(Int(Date().timeIntervalSince1970)).jpg"
                    onPickImage(compressed, name)
                }
                selectedPhotoItem = nil
            }
        }
        .sheet(isPresented: $showCamera) {
            CameraImagePicker(sourceType: .camera) { data, name in
                onPickImage(data, name)
            }
        }
        .sheet(isPresented: $showViewer) {
            if let imageData {
                InvoicePhotoViewerSheet(
                    imageData: imageData,
                    filename: remoteFilename,
                    onDelete: onDeletePhoto
                )
            }
        }
    }
}
