import EditorCore
import MetalKit
import SwiftUI

/// Hosts the Metal view that the shared renderer draws the preview into.
struct PreviewView: NSViewRepresentable {
    let drawer: PreviewDrawer

    func makeNSView(context: Context) -> MTKView {
        let view = MTKView()
        drawer.configure(view)
        return view
    }

    func updateNSView(_ view: MTKView, context: Context) {}
}
