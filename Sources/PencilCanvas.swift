import SwiftUI
import UIKit
import PencilKit

enum PencilCanvasToolMode: Equatable {
    case pen
    case eraser

    var pencilKitTool: PKTool {
        switch self {
        case .pen: return PKInkingTool(.pen, color: .systemBlue, width: 3)
        case .eraser: return PKEraserTool(.vector)
        }
    }
}

struct PencilCanvas: UIViewRepresentable {
    @Binding var drawing: PKDrawing
    var showsToolPicker = true
    var toolMode: PencilCanvasToolMode?
    var drawingPolicy: PKCanvasViewDrawingPolicy = .pencilOnly

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.drawingPolicy = drawingPolicy
        if let toolMode {
            canvas.tool = toolMode.pencilKitTool
        }
        canvas.delegate = context.coordinator
        canvas.drawing = drawing
        canvas.alwaysBounceVertical = false
        canvas.isScrollEnabled = false

        if showsToolPicker, let window = canvas.window {
            context.coordinator.attachToolPicker(to: canvas, window: window)
        }
        DispatchQueue.main.async {
            context.coordinator.preventParentScrollsFromHandlingPencil(canvas)
            if showsToolPicker, let window = canvas.window {
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
        canvas.drawingPolicy = drawingPolicy
        if let toolMode {
            canvas.tool = toolMode.pencilKitTool
        }
        context.coordinator.preventParentScrollsFromHandlingPencil(canvas)
        if showsToolPicker, let window = canvas.window {
            context.coordinator.attachToolPicker(to: canvas, window: window)
        } else {
            context.coordinator.detachToolPicker(from: canvas)
        }
    }

    static func dismantleUIView(_ canvas: PKCanvasView, coordinator: Coordinator) {
        coordinator.restoreParentScrollTouchPolicies()
        coordinator.detachToolPicker(from: canvas)
    }

    @MainActor
    final class Coordinator: NSObject, PKCanvasViewDelegate {
        var parent: PencilCanvas
        private var toolPicker: PKToolPicker?
        private var parentScrollTouchPolicies: [ScrollViewTouchPolicy] = []

        private struct ScrollViewTouchPolicy {
            weak var scrollView: UIScrollView?
            let allowedTouchTypes: [NSNumber]?
        }

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

        func detachToolPicker(from canvas: PKCanvasView) {
            guard let toolPicker else { return }
            toolPicker.setVisible(false, forFirstResponder: canvas)
            toolPicker.removeObserver(canvas)
            self.toolPicker = nil
        }

        func preventParentScrollsFromHandlingPencil(_ canvas: PKCanvasView) {
            var ancestor = canvas.superview
            while let view = ancestor {
                if let scrollView = view as? UIScrollView,
                   !parentScrollTouchPolicies.contains(where: { $0.scrollView === scrollView }) {
                    parentScrollTouchPolicies.append(ScrollViewTouchPolicy(
                        scrollView: scrollView,
                        allowedTouchTypes: scrollView.panGestureRecognizer.allowedTouchTypes
                    ))
                    scrollView.panGestureRecognizer.require(toFail: canvas.drawingGestureRecognizer)
                    scrollView.panGestureRecognizer.allowedTouchTypes = [
                        NSNumber(value: UITouch.TouchType.direct.rawValue)
                    ]
                }
                ancestor = view.superview
            }
        }

        func restoreParentScrollTouchPolicies() {
            let defaultTouchTypes = [
                UITouch.TouchType.direct,
                .indirect,
                .pencil,
                .indirectPointer
            ].map { NSNumber(value: $0.rawValue) }
            for policy in parentScrollTouchPolicies {
                policy.scrollView?.panGestureRecognizer.allowedTouchTypes = policy.allowedTouchTypes ?? defaultTouchTypes
            }
            parentScrollTouchPolicies.removeAll()
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            parent.drawing = canvasView.drawing
        }
    }
}

