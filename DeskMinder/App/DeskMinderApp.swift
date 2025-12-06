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
        // Pas de fenêtre principale, juste éventuellement des réglages
        Settings {
            EmptyView()
        }
    }
}
