//
//  View+ext.swift
//  ImageEditor
//
//  Created by Andrey Ulanov on 09.05.2024.
//

import SwiftUI
import Combine

extension UIView {
    func copyView<T: UIView>() -> T {
        return NSKeyedUnarchiver.unarchiveObject(with: NSKeyedArchiver.archivedData(withRootObject: self)) as! T
    }
}

extension CALayer {
    var copied: CALayer {
        NSKeyedUnarchiver.unarchiveObject(with: NSKeyedArchiver.archivedData(withRootObject: self)) as! CALayer
    }
}
