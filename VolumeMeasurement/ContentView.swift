//
//  ContentView.swift
//  SwiftUIARKit
//

import SwiftUI

struct ContentView: View { // this is the ContentView ui for the app (the actual measurement page)
    @ObservedObject var arDelegate = ARDelegate()
    
    var body: some View {
        ZStack {
            ARViewRepresentable(arDelegate: arDelegate) //this is the camera
            VStack {
                Spacer()
                Text(arDelegate.message + "\n" + arDelegate.message2 + "\n" + arDelegate.message3) //text displaying the results
                    .font(.title)
                    .fontWeight(.heavy)
                    .foregroundColor(Color(red: 1, green: 100/225, blue: 0))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 25.0)
                    .background(Color.gray)
            }
        }.edgesIgnoringSafeArea(.all)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
