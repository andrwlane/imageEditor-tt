//
//  UIResponder+ext.swift
//  ImageEditor
//
//  Created by Andrey Ulanov on 09.05.2024.
//

import UIKit

extension UIResponder {
    /// Access parent controller
    public var parentViewController: UIViewController? {
        return next as? UIViewController ?? next?.parentViewController
    }
}
