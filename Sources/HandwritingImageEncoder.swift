import PencilKit
import UIKit

/// Converts PencilKit strokes into the PNG payload expected by the grading API.
enum HandwritingImageEncoder {
    static func pngData(from drawing: PKDrawing) throws -> Data {
        guard !drawing.bounds.isNull, !drawing.bounds.isEmpty else {
            throw LearningAIServiceError.noWriting
        }

        let bounds = drawing.bounds.insetBy(dx: -16, dy: -16)
        let renderer = UIGraphicsImageRenderer(size: bounds.size)
        let image = renderer.image { context in
            UIColor.white.setFill()
            context.cgContext.fill(CGRect(origin: .zero, size: bounds.size))
            drawing.image(from: bounds, scale: 2).draw(in: CGRect(origin: .zero, size: bounds.size))
        }
        guard let data = image.pngData() else {
            throw LearningAIServiceError.invalidImage
        }
        return data
    }
}
