//
//  SwiftUIARKitApp.swift
//  SwiftUIARKit
//

import SwiftUI //this is the main file for the UI of the app - calls the ContentView file

@main
struct SwiftUIARKitApp: App {
    
    @StateObject var viewRouter = ViewRouter()
    
    var body: some Scene {
        WindowGroup {
            MainView(viewRouter: ViewRouter())
            //ContentView()
        }
    }
}
