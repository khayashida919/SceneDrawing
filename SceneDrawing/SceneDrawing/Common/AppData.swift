//
//  AppData.swift
//  SceneDrawing
//
//  Created by khayashida on 2019/05/08.
//  Copyright © 2019 khayashida. All rights reserved.
//

import Foundation

final class AppData {
    static let shared = AppData()
    
    var isFirstLaunch: Bool {
        set {
            UserDefaults.standard.set(newValue, forKey: "isFirstLaunch")
        }
        get {
           return UserDefaults.standard.bool(forKey: "isFirstLaunch")
        }
    }
    
    private init() {
        UserDefaults.standard.register(defaults: ["isFirstLaunch" : true])
    }
}
