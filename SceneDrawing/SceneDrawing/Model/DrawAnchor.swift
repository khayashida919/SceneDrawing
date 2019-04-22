//
//  DrawAnchor.swift
//  SceneDrawing
//
//  Created by khayashida on 2019/04/17.
//  Copyright © 2019 khayashida. All rights reserved.
//

import ARKit

final class DrawAnchor: ARAnchor {
    let color: UIColor
    let size: Float
    init(name: String, transform: simd_float4x4, color: UIColor, size: Float) {
        self.color = color
        self.size = size
        super.init(name: name, transform: transform)
    }
    
    required init(anchor: ARAnchor) {
        let drawAnchor = anchor as! DrawAnchor
        self.color = drawAnchor.color
        self.size = drawAnchor.size
        super.init(anchor: drawAnchor)
    }
    
    required init?(coder aDecoder: NSCoder) {
        guard
            let color = try? aDecoder.decodeTopLevelObject(of: UIColor.self, forKey: "color") else {
                return nil
        }
        self.color = color
        self.size = aDecoder.decodeFloat(forKey: "size")
        super.init(coder: aDecoder)
    }
    
    override func encode(with aCoder: NSCoder) {
        aCoder.encode(self.color, forKey: "color")
        aCoder.encode(size, forKey: "size")
        super.encode(with: aCoder)
    }
    
    override class var supportsSecureCoding: Bool {
        return true
    }
}
