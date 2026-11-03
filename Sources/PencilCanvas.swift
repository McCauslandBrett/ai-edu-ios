import SwiftUI
import UIKit
import PencilKit

struct PencilCanvas: UIViewRepresentable {
    @Binding var drawing: PKDrawing

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.drawingPolicy = .pencilOnly // Leave finger gestures available for scrolling the assignment page.
        canvas.tool = PKInkingTool(.pen, color: .systemBlue, width: 3)
        canvas.delegate = context.coordinator
        canvas.drawing = drawing
        canvas.alwaysBounceVertical = false
        canvas.isScrollEnabled = false

        if let window = canvas.window {
            context.coordinator.attachToolPicker(to: canvas, window: window)
        }
        DispatchQueue.main.async {
            if let window = canvas.window {
                context.coordinator.attachToolPicker(to: canvas, window: window)
            }
        }
        return canvas
    }

    func updateUIView(_ canvas: PKCanvasView, context: Context) {
        context.coordinator.parent = self
        if canvas.drawing != drawing {
            canvas.drawing = drawing
        }
        if let window = canvas.window {
            context.coordinator.attachToolPicker(to: canvas, window: window)
        }
    }

    @MainActor
    final class Coordinator: NSObject, PKCanvasViewDelegate {
        var parent: PencilCanvas
        private var toolPicker: PKToolPicker?

        init(_ parent: PencilCanvas) {
            self.parent = parent
        }

        func attachToolPicker(to canvas: PKCanvasView, window: UIWindow) {
            guard toolPicker == nil else { return }
            let picker = PKToolPicker()
            picker.setVisible(true, forFirstResponder: canvas)
            picker.addObserver(canvas)
            canvas.becomeFirstResponder()
            toolPicker = picker
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            parent.drawing = canvasView.drawing
        }
    }
}

