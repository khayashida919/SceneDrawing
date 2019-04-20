//
//  Extensions.swift
//  SceneDrawing
//
//  Created by khayashida on 2019/04/13.
//  Copyright © 2019 khayashida. All rights reserved.
//

import UIKit
import ARKit

extension UIViewController {
    func showAlert(isCancel: Bool, title: String, message: String, handler: (() -> Void)? = nil) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let action = UIAlertAction(title: "OK", style: .default) { (_) in
            handler?()
        }
        alert.addAction(action)
        if isCancel {
            let cancelAction = UIAlertAction(title: "キャンセル", style: .cancel, handler: nil)
            alert.addAction(cancelAction)
        }
        present(alert, animated: true, completion: nil)
    }
}

extension ARFrame.WorldMappingStatus {
    var message: String {
        switch self {
        case .notAvailable, .limited: return "スキャンし続けてください"
        case .extending, .mapped: return "マッピング状態良好"
        @unknown default:
            fatalError()
        }
    }
}
