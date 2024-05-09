//
//  MediaProcessor.swift
//  ImageEditor
//
//  Created by Andrey Ulanov on 09.05.2024.
//

import Foundation
import AVKit
import Photos
import SwiftUI

enum VideoExportError: Error {
    case failed
    case canceled
}

class MediaProcessor {

    /// Draw the markup and save image to user's media library
    static func exportImage(image original: UIImage, markup: UIImage, contentMode: ContentMode, imageView: UIImageView) {
        let image = makeImage(image: original, markup: markup, contentMode: contentMode, imageView: imageView)
        UIGraphicsEndImageContext()
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
    }

    static func makeImage(image original: UIImage, markup: UIImage, contentMode: ContentMode, imageView: UIImageView) -> UIImage {
        var original = original

        if contentMode == .fill {
            // calculate size of visible image area
            let imageSize = original.size
            let pixelsSize = imageView.aspectFillSize

            let h, w, offsetX, offsetY: CGFloat
            if imageSize.width > imageSize.height {
                h = imageSize.height
                w = imageView.bounds.width / pixelsSize.width * imageSize.width
                offsetX = floor((imageSize.width - w) / 2)
                offsetY = 0.0
            } else {
                w = imageSize.width
                h = imageView.bounds.height / pixelsSize.height * imageSize.height
                offsetX = 0.0
                offsetY = floor((imageSize.height - h) / 2)
            }
            let rect = CGRect(x: offsetX, y: offsetY, width: round(w), height: round(h))

            if let cgImage = original.cgImage, let cropped = cgImage.cropping(to: rect) {
                original = UIImage(cgImage: cropped)
            }
        }

        UIGraphicsBeginImageContextWithOptions(original.size, true, 1.0)

        let rect = CGRect(x: 0, y: 0, width: original.size.width, height: original.size.height)
        original.draw(in: rect)

        markup.draw(in: rect, blendMode: .normal, alpha: 1.0)

        let image = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()

        return image
    }
}
