//
//  VisualEffectView.swift
//  testDebugWindow
//
//  Created by Iris on 2024-11-14.
//

import Foundation
import SwiftUI

struct VisualEffectView: NSViewRepresentable {
    func makeNSView(context _: Context) -> NSVisualEffectView {
        let effectView = NSVisualEffectView()
        effectView.state = .active
        return effectView
    }

    func updateNSView(_: NSVisualEffectView, context _: Context) {}
}
