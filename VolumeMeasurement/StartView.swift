//
//  StartView.swift
//  SwiftUIARKit
//
//  Created by Dani D on 23/11/21.
//

import SwiftUI

struct StartView: View {
    
    @StateObject var viewRouter: ViewRouter
    
    var body: some View {
        ZStack{
            Color(red: 1, green: 100/225, blue: 0)
                .ignoresSafeArea()
            VStack{
                Text("Volume Measuring App")
                    .font(.title)
                    .fontWeight(.heavy)
                    .foregroundColor(Color.black)
                    .multilineTextAlignment(.center)
                
                Button(action: {withAnimation {viewRouter.currentPage = .page2}})
                {
                    StartButtonContent()
                }
            }
        }
    }
}

struct StartView_Previews: PreviewProvider {
    static var previews: some View {
        StartView(viewRouter: ViewRouter())
    }
}

struct StartButtonContent : View {
    var body: some View {
        Text("Start Measurement")
            .foregroundColor(.white)
            .frame(width: 200, height: 50)
            .background(Color.blue)
            .cornerRadius(15)
            .padding(.top, 200.0)
    }
}

