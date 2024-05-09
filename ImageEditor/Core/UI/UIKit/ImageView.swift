//
//  ImageView.swift
//  ImageEditor
//
//  Created by Andrey Ulanov on 09.05.2024.
//

import SwiftUI

struct ImageView: UIViewRepresentable {
    typealias UIViewType = UIImageView

    @Binding var image: UIImage
    var imageView: UIImageView

    @Binding var contentMode: UIView.ContentMode

    func makeUIView(context: Context) -> UIViewType {
        imageView.image = image
        imageView.backgroundColor = .clear
        imageView.contentMode = contentMode
        imageView.clipsToBounds = true

        imageView.setContentHuggingPriority(.defaultLow, for: .vertical)
        imageView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        imageView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        imageView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        return imageView
    }

    func updateUIView(_ uiView: UIViewType, context: Context) {
        uiView.image = image
        uiView.contentMode = contentMode
    }
}

