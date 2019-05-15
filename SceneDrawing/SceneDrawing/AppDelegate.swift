//
//  AppDelegate.swift
//  SceneDrawing
//
//  Created by khayashida on 2019/04/11.
//  Copyright © 2019 khayashida. All rights reserved.
//

import UIKit
import GoogleMobileAds

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        
        GADMobileAds.sharedInstance().start(completionHandler: nil)
        
        return true
    }

}

