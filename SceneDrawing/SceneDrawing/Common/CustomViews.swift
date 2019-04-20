//
//  CornerButton.swift
//  SceneDrawing
//
//  Created by khayashida on 2019/03/31.
//  Copyright © 2019 khayashida. All rights reserved.
//

import UIKit

@IBDesignable
final class CornerButton: UIButton {
    
    @IBInspectable var cornerRadius: CGFloat = 0 {
        didSet {
            layer.cornerRadius = cornerRadius
        }
    }
    
    @IBInspectable var borderWidth: CGFloat = 0 {
        didSet {
            layer.borderWidth = borderWidth
        }
    }
    
    @IBInspectable var borderColor: UIColor = UIColor.clear {
        didSet {
            layer.borderColor = borderColor.cgColor
        }
    }
}
