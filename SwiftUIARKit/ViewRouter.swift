//
//  ViewRouter.swift
//  SwiftUIARKit
//
//  This is a helper script to navigate between different views/pages
//

import Foundation
import SwiftUI

class ViewRouter: ObservableObject{
    @Published var currentPage: Page = .page1
}
