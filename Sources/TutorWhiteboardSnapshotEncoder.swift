import PencilKit
import UIKit

/// Renders the current illustration and ink layer into the image sent to the tutor.
struct TutorWhiteboardSnapshotEncoder {
    func base64(illustration: UIImage?, drawing: PKDrawing, canvasSize: CGSize) -> String? {
        guard canvasSize.width > 0, canvasSize.height > 0,
              illustration != nil || !drawing.bounds.isEmpty else { return nil }
        let scale = min(1, 1_024 / max(canvasSize.width, canvasSize.height))
        let outputSize = CGSize(width: canvasSize.width * scale, height: canvasSize.height * scale)
        let outputBounds = CGRect(origin: .zero, size: outputSize)
        let sourceBounds = CGRect(origin: .zero, size: canvasSize)
        let renderer = UIGraphicsImageRenderer(size: outputSize)
        let image = renderer.image { context in
            UIColor.white.setFill()
            context.cgContext.fill(outputBounds)
            if let illustration {
                illustration.draw(in: aspectFitRect(for: illustration.size, inside: outputBounds))
            }
            drawing.image(from: sourceBounds, scale: scale).draw(in: outputBounds)
        }
        return image.pngData()?.base64EncodedString()
    }

    private func aspectFitRect(for imageSize: CGSize, inside bounds: CGRect) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else { return bounds }
        let scale = min(bounds.width / imageSize.width, bounds.height / imageSize.height)
        let size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return CGRect(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2, width: size.width, height: size.height)
    }
}
