//
//  AppDelegate.swift
//  AspectDemo
//
//  Created by Kris Liu on 2019/3/12.
//  Copyright © 2019 Syzygy. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let navController = UINavigationController(rootViewController: ViewController())
        window?.rootViewController = navController
        
        return true
    }
}

