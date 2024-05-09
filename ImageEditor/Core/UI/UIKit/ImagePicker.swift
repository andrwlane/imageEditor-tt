//
//  ImagePicker.swift
//  ImageEditor
//
//  Created by Andrey Ulanov on 09.05.2024.
//

import SwiftUI
import AVKit

struct ImagePicker: UIViewControllerRepresentable {

    var didFinishSelection: (UIImage) -> Void

    func makeUIViewController(context: UIViewControllerRepresentableContext<ImagePicker>) -> UIImagePickerController {
        let imagePicker = UIImagePickerController()

        imagePicker.allowsEditing = false
        imagePicker.videoExportPreset = AVAssetExportPresetPassthrough
        imagePicker.videoQuality = .typeHigh
        imagePicker.sourceType = .photoLibrary
        if let mediaTypes = UIImagePickerController.availableMediaTypes(for: .photoLibrary) {
            imagePicker.mediaTypes = mediaTypes
        }
        imagePicker.overrideUserInterfaceStyle = .dark
        imagePicker.delegate = context.coordinator

        return imagePicker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: UIViewControllerRepresentableContext<ImagePicker>) { }

    func makeCoordinator() -> Coordinator { Coordinator(handler: didFinishSelection) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UINavigationBarDelegate {

        var handler: (UIImage) -> Void

        init(handler: @escaping (UIImage) -> Void) {
            self.handler = handler
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {

            if let image = info[.originalImage] as? UIImage {
                handler(image)
            }
        }
    }
}

struct ImagePicker_Previews: PreviewProvider {
    static var previews: some View {
        ImagePicker(didFinishSelection: { _ in })
    }
}
