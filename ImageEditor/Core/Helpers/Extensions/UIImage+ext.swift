//
//  UIImage+Extensions.swift
//  ImageEditor
//
//  Created by Andrey Ulanov on 09.05.2024.
//

import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins
import Vision

extension CIImage {

    func applySepia(amount: Float = 1) throws -> UIImage {
        let context = CIContext()
        let filter = CIFilter.sepiaTone()
        filter.inputImage = self
        filter.intensity = amount
        guard let outputImage = filter.outputImage,
              let cgImage = context.createCGImage(outputImage, from: outputImage.extent)
        else {
            throw "Failed to apply sepia"
        }

        return UIImage(cgImage: cgImage)
    }

    func applyBlur(amount: Float = 1) throws -> UIImage {
        let context = CIContext()
        let filter = CIFilter.gaussianBlur()
        filter.inputImage = self
        filter.radius = amount
        guard let outputImage = filter.outputImage,
              let cgImage = context.createCGImage(outputImage, from: outputImage.extent)
        else {
            throw "Failed to apply blur"
        }

        return UIImage(cgImage: cgImage)
    }

    func applySaturation(amount: Float = 1) throws -> UIImage {
        let context = CIContext()
        let filter = CIFilter.colorControls()
        filter.inputImage = self
        filter.saturation = amount
        guard let outputImage = filter.outputImage,
              let cgImage = context.createCGImage(outputImage, from: outputImage.extent)
        else {
            throw "Failed to apply saturation"
        }

        return UIImage(cgImage: cgImage)
    }

    func applyExposure(amount: Float = 1) throws -> UIImage {
        let context = CIContext()
        let filter = CIFilter.exposureAdjust()
        filter.inputImage = self
        filter.ev = amount
        guard let outputImage = filter.outputImage,
              let cgImage = context.createCGImage(outputImage, from: outputImage.extent)
        else {
            throw "Failed to apply saturation"
        }

        return UIImage(cgImage: cgImage)
    }

}

extension UIImage {

    func applySepia(_ amount: Float) -> UIImage? {
        let ciImage = CIImage(image: self)
        return try? ciImage?.applySepia(amount: amount)
    }

    func applyBlur(_ amount: Float) -> UIImage? {
        let ciImage = CIImage(image: self)
        return try? ciImage?.applyBlur(amount: amount * 10)
    }

    func applySaturation(_ amount: Float) -> UIImage? {
        let ciImage = CIImage(image: self)
        return try? ciImage?.applySaturation(amount: amount)
    }

    func applyExposure(_ amount: Float) -> UIImage? {
        let ciImage = CIImage(image: self)
        return try? ciImage?.applyExposure(amount: amount * 1.5)
    }

    func resizeImageTo(size: CGSize) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        self.draw(in: CGRect(origin: CGPoint.zero, size: size))
        guard let resizedImage = UIGraphicsGetImageFromCurrentImageContext() else { return nil }
        UIGraphicsEndImageContext()
        return resizedImage
    }

    func withPadding(x: CGFloat, y: CGFloat) -> UIImage? {
        let newWidth = size.width + 2 * x
        let newHeight = size.height + 2 * y
        let newSize = CGSize(width: newWidth, height: newHeight)
        UIGraphicsBeginImageContextWithOptions(newSize, false, 0)

        let origin = CGPoint(x: (newWidth - size.width) / 2, y: (newHeight - size.height) / 2)
        draw(at: origin)

        let imageWithPadding = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return imageWithPadding
    }

    /// Convert image pixels to black or white pixels via threshold
    /// https://stackoverflow.com/a/31661519
    func convertToBlackAndWhite() -> UIImage? {
        guard let inputCGImage = self.cgImage else {
            print("Unable to get cgImage")
            return nil
        }
        let colorSpace       = CGColorSpaceCreateDeviceRGB()
        let width            = inputCGImage.width
        let height           = inputCGImage.height
        let bytesPerPixel    = 4
        let bitsPerComponent = 8
        let bytesPerRow      = bytesPerPixel * width
        let bitmapInfo       = RGBA32.bitmapInfo
        let threshold        = 44 // components less than 44 of 256 will be considered white, others as black

        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: bitsPerComponent, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: bitmapInfo) else {
            print("Unable to create context")
            return nil
        }
        context.draw(inputCGImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        guard let buffer = context.data else {
            print("Unable to get context data")
            return nil
        }

        let pixelBuffer = buffer.bindMemory(to: RGBA32.self, capacity: width * height)

        for row in 0 ..< Int(height) {
            for column in 0 ..< Int(width) {
                let offset = row * width + column
                if (pixelBuffer[offset].redComponent > threshold &&
                    pixelBuffer[offset].greenComponent > threshold &&
                    pixelBuffer[offset].blueComponent > threshold) {
                    pixelBuffer[offset] = .black
                }
            }
        }

        guard let outputCGImage = context.makeImage() else {
            print("Unable to make an image")
            return nil
        }

        return UIImage(cgImage: outputCGImage, scale: self.scale, orientation: self.imageOrientation)
    }
}

/// Structure used by convertToBlackAndWhite()
struct RGBA32: Equatable {
    private var color: UInt32

    var redComponent: UInt8 {
        return UInt8((color >> 24) & 255)
    }

    var greenComponent: UInt8 {
        return UInt8((color >> 16) & 255)
    }

    var blueComponent: UInt8 {
        return UInt8((color >> 8) & 255)
    }

    var alphaComponent: UInt8 {
        return UInt8((color >> 0) & 255)
    }

    init(red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8) {
        let red   = UInt32(red)
        let green = UInt32(green)
        let blue  = UInt32(blue)
        let alpha = UInt32(alpha)
        color = (red << 24) | (green << 16) | (blue << 8) | (alpha << 0)
    }

    static let red     = RGBA32(red: 255, green: 0,   blue: 0,   alpha: 255)
    static let green   = RGBA32(red: 0,   green: 255, blue: 0,   alpha: 255)
    static let blue    = RGBA32(red: 0,   green: 0,   blue: 255, alpha: 255)
    static let white   = RGBA32(red: 255, green: 255, blue: 255, alpha: 255)
    static let black   = RGBA32(red: 0,   green: 0,   blue: 0,   alpha: 255)
    static let magenta = RGBA32(red: 255, green: 0,   blue: 255, alpha: 255)
    static let yellow  = RGBA32(red: 255, green: 255, blue: 0,   alpha: 255)
    static let cyan    = RGBA32(red: 0,   green: 255, blue: 255, alpha: 255)

    static let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Little.rawValue

    static func ==(lhs: RGBA32, rhs: RGBA32) -> Bool {
        return lhs.color == rhs.color
    }
}
