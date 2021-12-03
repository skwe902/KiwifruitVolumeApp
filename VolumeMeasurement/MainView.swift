//
//  MainView.swift
//  SwiftUIARKit
//
//
//

import SwiftUI

struct MainView: View {
    
    @State var currentPage: Page = .page1
    @StateObject var viewRouter: ViewRouter
    
    var body: some View {
        switch viewRouter.currentPage{
        case .page1:
            StartView(viewRouter: viewRouter)
        case .page2:
            ContentView()
                .transition(.scale)
        }
    }
}

struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView(viewRouter: ViewRouter())
    }
}
