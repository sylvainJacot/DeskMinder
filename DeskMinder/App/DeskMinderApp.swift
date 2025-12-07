//
//  DeskMinderApp.swift
//  DeskMinder
//
//  Created by Sylvain Jacot on 29/11/2025.
//

import SwiftUI

@main
struct DeskMinderApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        // No main window, only optional settings
        Settings {
            EmptyView()
        }
    }
}
