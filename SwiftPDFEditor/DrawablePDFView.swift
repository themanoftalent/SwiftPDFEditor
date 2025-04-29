import PDFKit
import AppKit

class DrawablePDFView: PDFView {
    // Tool Properties
    var currentTool: DrawingTool = .pen
    var currentColor: NSColor = .black
    var lineWidth: CGFloat = 3.0
    var currentShape: ShapeType = .rectangle
    
    // Drawing State
    private var currentAnnotation: PDFAnnotation?
    private var startPoint: CGPoint = .zero
    private var temporaryShapeLayer: CAShapeLayer?
    private var activeTextField: NSTextField?
    private var currentPath: NSBezierPath? // Track the current path for ink annotations
    
    // MARK: - Mouse Handling
    override func mouseDown(with event: NSEvent) {
        guard let page = getCurrentPage(event: event) else { return }
        startPoint = convert(event.locationInWindow, from: nil)
        
        switch currentTool {
        case .pen, .highlighter:
            startInkAnnotation(on: page, at: startPoint)
        case .text:
            addTextAnnotation(on: page, at: startPoint)
        case .shape:
            startShapeAnnotation(on: page, at: startPoint)
        case .eraser:
            removeAnnotation(at: startPoint, on: page)
        }
    }
    
    override func mouseDragged(with event: NSEvent) {
        let currentPoint = convert(event.locationInWindow, from: nil)
        
        switch currentTool {
        case .pen, .highlighter:
            continueInkAnnotation(to: currentPoint)
        case .shape:
            updateTemporaryShape(to: currentPoint)
        default: break
        }
    }
    
    override func mouseUp(with event: NSEvent) {
        let endPoint = convert(event.locationInWindow, from: nil)
        
        if currentTool == .shape, let page = getCurrentPage(event: event) {
            finalizeShapeAnnotation(on: page, from: startPoint, to: endPoint)
        }
        
        cleanupDrawing()
    }
    
    // MARK: - Ink Annotation Methods
    private func startInkAnnotation(on page: PDFPage, at point: CGPoint) {
        let convertedPoint = convert(point, to: page)
        let path = NSBezierPath()
        path.move(to: convertedPoint)
        
        let annotation = PDFAnnotation(
            bounds: CGRect(origin: convertedPoint, size: CGSize(width: 1, height: 1)),
            forType: .ink,
            withProperties: nil
        )
        annotation.color = currentTool == .highlighter ?
            currentColor.withAlphaComponent(0.4) : currentColor
        annotation.add(path)
        page.addAnnotation(annotation)
        currentAnnotation = annotation
        currentPath = path // Track the path for dragging
    }
    
    private func continueInkAnnotation(to point: CGPoint) {
        guard let page = currentPage,
              let annotation = currentAnnotation,
              let path = currentPath else { return }
        
        let convertedPoint = convert(point, to: page)
        path.line(to: convertedPoint)
        annotation.add(path) // Re-add the updated path
        updateAnnotationBounds(annotation, with: convertedPoint)
        setNeedsDisplay(bounds) // Force redraw
    }
    
    // MARK: - Shape Annotation Methods
    private func startShapeAnnotation(on page: PDFPage, at point: CGPoint) {
        let layer = CAShapeLayer()
        layer.strokeColor = currentColor.cgColor
        layer.fillColor = currentColor.withAlphaComponent(0.2).cgColor
        layer.lineWidth = lineWidth
        self.layer?.addSublayer(layer)
        temporaryShapeLayer = layer
    }
    
    private func updateTemporaryShape(to currentPoint: CGPoint) {
        guard let layer = temporaryShapeLayer else { return }
        
        // Calculate the rectangle from startPoint to currentPoint
        let rect = CGRect(p1: startPoint, p2: currentPoint)
        
        // Create a path based on the current shape type
        let path = CGMutablePath()
        switch currentShape {
        case .rectangle:
            path.addRect(rect)
        case .circle:
            path.addEllipse(in: rect)
        }
        
        // Update the shape layer's path
        layer.path = path
    }
    
    private func finalizeShapeAnnotation(on page: PDFPage, from start: CGPoint, to end: CGPoint) {
        let startConverted = convert(start, to: page)
        let endConverted = convert(end, to: page)
        let rect = CGRect(p1: startConverted, p2: endConverted)
        
        let annotation = PDFAnnotation(
            bounds: rect,
            forType: currentShape.pdfAnnotationType,
            withProperties: nil
        )
        annotation.color = currentColor
        page.addAnnotation(annotation)
    }
    
    // MARK: - Text Annotation Methods
    private func addTextAnnotation(on page: PDFPage, at point: CGPoint) {
        let convertedPoint = convert(point, to: page)
        let textField = NSTextField(frame: NSRect(x: convertedPoint.x, y: convertedPoint.y, width: 200, height: 24))
        textField.delegate = self
        textField.isBezeled = false
        textField.backgroundColor = .clear
        textField.focusRingType = .none
        textField.font = NSFont.systemFont(ofSize: 14)
        
        // Add to PDFView
        self.addSubview(textField)
        textField.becomeFirstResponder()
        activeTextField = textField
    }
    
    private func finalizeTextAnnotation(textField: NSTextField, on page: PDFPage) {
        let convertedPoint = convert(textField.frame.origin, to: page)
        let annotation = PDFAnnotation(
            bounds: CGRect(origin: convertedPoint, size: textField.frame.size),
            forType: .freeText,
            withProperties: nil
        )
        annotation.contents = textField.stringValue
        annotation.color = currentColor
        annotation.font = textField.font
        page.addAnnotation(annotation)
        
        textField.removeFromSuperview()
        activeTextField = nil
    }
    
    // MARK: - Annotation Removal
    private func removeAnnotation(at point: CGPoint, on page: PDFPage) {
        let convertedPoint = convert(point, to: page)
        if let annotation = page.annotations.first(where: { $0.bounds.contains(convertedPoint) }) {
            page.removeAnnotation(annotation)
        }
    }
    
    // MARK: - Helper Methods
    private func getCurrentPage(event: NSEvent) -> PDFPage? {
        let point = convert(event.locationInWindow, from: nil)
        return page(for: point, nearest: true)
    }
    
    private func updateAnnotationBounds(_ annotation: PDFAnnotation, with point: CGPoint) {
        var bounds = annotation.bounds
        bounds = bounds.union(CGRect(origin: point, size: .zero))
        annotation.bounds = bounds
    }
    
    private func cleanupDrawing() {
        temporaryShapeLayer?.removeFromSuperlayer()
        temporaryShapeLayer = nil
        currentAnnotation = nil
        currentPath = nil // Clear the current path
    }
}

// MARK: - NSTextFieldDelegate
extension DrawablePDFView: NSTextFieldDelegate {
    func controlTextDidEndEditing(_ obj: Notification) {
        guard let textField = obj.object as? NSTextField,
              let page = currentPage else { return }
        
        if !textField.stringValue.isEmpty {
            finalizeTextAnnotation(textField: textField, on: page)
        } else {
            textField.removeFromSuperview()
            activeTextField = nil
        }
    }
}

// MARK: - Supporting Types
enum DrawingTool {
    case pen
    case highlighter
    case text
    case shape
    case eraser
}

enum ShapeType {
    case rectangle
    case circle
    
    var pdfAnnotationType: PDFAnnotationSubtype {
        switch self {
        case .rectangle: return .square
        case .circle: return .circle
        }
    }
}

extension CGRect {
    init(p1: CGPoint, p2: CGPoint) {
        self.init(
            x: min(p1.x, p2.x),
            y: min(p1.y, p2.y),
            width: abs(p1.x - p2.x),
            height: abs(p1.y - p2.y)
        )
    }
}
