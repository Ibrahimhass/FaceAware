//
//  UIImageView+FaceAware.swift
//  FaceAware
//
//  The MIT License (MIT)
//
//  Copyright (c) 2022 Ibrahim Hassan
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.

import ObjectiveC

private var closureKey: UInt = 0
private var debugKey: UInt = 1

#if os(macOS)
import AppKit

extension NSImage {
    var ciImage: CIImage? {
        guard let data = tiffRepresentation else { return nil }
        return CIImage(data: data)
    }
    
    var faces: [CIFaceFeature]? {
        guard let ciImage = ciImage else { return [] }
        return CIDetector(ofType: CIDetectorTypeFace, context: nil, options: [CIDetectorAccuracy: CIDetectorAccuracyHigh])?
            .features(in: ciImage) as? [CIFaceFeature]
    }
}

class FaceAwareImageView: NSImageView, Attachable {
    private struct AssociatedCustomProperties {
        static var debugFaceAware: Bool = false
    }
    
    open override var image: NSImage? {
        set {
            self.imageAlignment = .alignTopLeft
            self.imageScaling = .scaleAxesIndependently
            self.layer?.contentsGravity = .resizeAspectFill
            self.layer = CALayer()
            self.layer?.contents = newValue
            self.wantsLayer = true
            
            super.image = newValue
        }
        get {
            return super.image
        }
    }
    
    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }
    
    //the image setter isn't called when loading from a storyboard
    //manually set the image if it is already set
    required public init?(coder: NSCoder) {
        super.init(coder: coder)
        
        if let theImage = image {
            self.image = theImage
        }
    }
    
    
    @IBInspectable
    public var debugFaceAware: Bool {
        set {
            objc_setAssociatedObject(self, &AssociatedCustomProperties.debugFaceAware, newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        } get {
            guard let debug = objc_getAssociatedObject(self, &AssociatedCustomProperties.debugFaceAware) as? Bool else {
                return false
            }
            
            return debug
        }
    }
    
    private var _focusOnFaces = false
    
    @IBInspectable
    public var focusOnFaces: Bool {
        set {
            self.wantsLayer = true
            _focusOnFaces = newValue
            set(image: self.image, focusOnFaces: newValue)
        } get {
            return _focusOnFaces
        }
    }
    
    func set(image: NSImage?, focusOnFaces: Bool) {
        guard focusOnFaces == true else {
            return
        }
        
        setImageAndFocusOnFaces(image: image)
    }
    
    /// You can provide a closure here to receive a callback for when all face
    /// detection and image adjustments have been finished.
    public var didFocusOnFaces: (() -> Void)? {
        set {
            set(newValue, forKey: &closureKey)
        } get {
            return getAttach(forKey: &closureKey) as? (() -> Void)
        }
    }
    
    private func setImageAndFocusOnFaces(image: NSImage?) {
        DispatchQueue.global(qos: .userInitiated).async {
            guard let image = image else {
                return
            }
            
            let features = image.faces ?? []
            
            if features.count > 0 {
                print("found \(features.count) faces")
                let imgSize = CGSize(width: Double(image.size.width), height: (Double(image.size.height)))
                self.applyFaceDetection(for: features, size: imgSize, image: image)
            } else {
                print("No faces found")
            }
        }
    }
    
    private func applyFaceDetection(for features: [CIFaceFeature], size: CGSize, image: NSImage) {
        DispatchQueue.main.async { [self] in
            // get bounds of first face
            
            var minX: CGFloat = CGFloat.infinity
            var maxX: CGFloat = -CGFloat.infinity
            var minY: CGFloat = CGFloat.infinity
            var maxY: CGFloat = -CGFloat.infinity
            
            for feature in features {
                minX = min(feature.bounds.minX, minX)
                minY = min(feature.bounds.minY, minY)
                maxX = max(feature.bounds.maxX, maxX)
                maxY = max(feature.bounds.maxY, maxY)
            }
            
            var imageWidth: CGFloat = maxX - minX
            var imageHeight: CGFloat = maxY - minY
            
            if imageWidth * 2 <= size.width {
                imageWidth = imageWidth * 2
            } else {
                imageWidth = size.width
            }
            
            if imageHeight * 2 <= size.height {
                imageHeight = imageHeight * 2
            } else {
                imageHeight = size.height
            }
            
            let newRect = CGRect(x: max(minX - imageWidth * 0.25, 0), y: max(minY - imageHeight * 0.25, 0), width: imageWidth, height: imageHeight)
            
            var newImage: NSImage? = nil
            
            if self.debugFaceAware {
                image.lockFocus()
                if let context = NSGraphicsContext.current?.cgContext {
                    context.setStrokeColor(NSColor.yellow.cgColor)
                    context.setLineWidth(3)
                    
                    for face in features {
                        context.addRect(face.bounds)
                        context.drawPath(using: .stroke)
                    }
                    
                    if let _image = context.makeImage() {
                        newImage = NSImage(cgImage: _image, size: image.size)
                    }
                }
                image.unlockFocus()
            } else {
                newImage = image
            }
            
            self.image = crop(nsImage: newImage, rect: newRect)
            self.didFocusOnFaces?()
        }
    }
    
    private func crop(nsImage: NSImage?, rect: CGRect) -> NSImage? {
        let newImage = NSImage(size: NSSizeFromCGSize(rect.size))
        newImage.lockFocus()
        let dest = NSRect(origin: NSPoint.zero, size: newImage.size)
        nsImage?.draw(in: dest, from: NSRectFromCGRect(rect), operation: .copy, fraction: 1)
        newImage.unlockFocus()
        
        return newImage
    }
}

#endif


#if os(iOS)
import UIKit

@IBDesignable
extension UIImageView: Attachable {
    
    private struct AssociatedCustomProperties {
        static var debugFaceAware: Bool = false
    }
    
    @IBInspectable
    public var debugFaceAware: Bool {
        set {
            objc_setAssociatedObject(self, &AssociatedCustomProperties.debugFaceAware, newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        } get {
            guard let debug = objc_getAssociatedObject(self, &AssociatedCustomProperties.debugFaceAware) as? Bool else {
                return false
            }
            
            return debug
        }
    }
    
    @IBInspectable
    public var focusOnFaces: Bool {
        set {
            let image = self.image
            self.image = nil
            set(image: image, focusOnFaces: newValue)
        } get {
            return sublayer() != nil ? true : false
        }
    }
    
    public func set(image: UIImage?, focusOnFaces: Bool) {
        guard focusOnFaces == true else {
            self.removeImageLayer(image: image)
            return
        }
        setImageAndFocusOnFaces(image: image)
    }
    
    /// You can provide a closure here to receive a callback for when all face
    /// detection and image adjustments have been finished.
    public var didFocusOnFaces: (() -> Void)? {
        set {
            set(newValue, forKey: &closureKey)
        } get {
            return getAttach(forKey: &closureKey) as? (() -> Void)
        }
    }
    
    private func setImageAndFocusOnFaces(image: UIImage?) {
        DispatchQueue.global(qos: .default).async {
            guard let image = image else {
                return
            }
            
            let cImage = image.ciImage ?? CIImage(cgImage: image.cgImage!)
            
            let detector = CIDetector(ofType: CIDetectorTypeFace, context: nil, options: [CIDetectorAccuracy:CIDetectorAccuracyLow])
            let features = detector!.features(in: cImage)
            
            if features.count > 0 {
                print("found \(features.count) faces")
                let imgSize = CGSize(width: Double(image.cgImage!.width), height: (Double(image.cgImage!.height)))
                self.applyFaceDetection(for: features, size: imgSize, image: image)
            } else {
                print("No faces found")
                self.removeImageLayer(image: image)
            }
        }
    }
    
    private func applyFaceDetection(for features: [AnyObject], size: CGSize, image: UIImage) {
        DispatchQueue.main.async { [self] in
            // get bounds of first face
            
            var rect = features[0].bounds!
            rect.origin.y = size.height - rect.origin.y - rect.size.height
            var rightBorder = Double(rect.origin.x + rect.size.width)
            var bottomBorder = Double(rect.origin.y + rect.size.height)
            
            for feature in features[1..<features.count] {
                var oneRect = feature.bounds!
                oneRect.origin.y = size.height - oneRect.origin.y - oneRect.size.height
                rect.origin.x = min(oneRect.origin.x, rect.origin.x)
                rect.origin.y = min(oneRect.origin.y, rect.origin.y)
                
                rightBorder = max(Double(oneRect.origin.x + oneRect.size.width), Double(rightBorder))
                bottomBorder = max(Double(oneRect.origin.y + oneRect.size.height), Double(bottomBorder))
            }
            
            rect.size.width = CGFloat(rightBorder) - rect.origin.x
            rect.size.height = CGFloat(bottomBorder) - rect.origin.y
            
            var center = CGPoint(x: rect.origin.x + rect.size.width / 2.0, y: rect.origin.y + rect.size.height / 2.0)
            var offset = CGPoint.zero
            var finalSize = size
            
            if size.width / size.height > bounds.size.width / bounds.size.height {
                finalSize.height = self.bounds.size.height
                finalSize.width = size.width/size.height * finalSize.height
                center.x = finalSize.width / size.width * center.x
                center.y = finalSize.width / size.width * center.y
                
                offset.x = center.x - self.bounds.size.width * 0.5
                if (offset.x < 0) {
                    offset.x = 0
                } else if (offset.x + self.bounds.size.width > finalSize.width) {
                    offset.x = finalSize.width - self.bounds.size.width
                }
                offset.x = -offset.x
            } else {
                finalSize.width = self.bounds.size.width
                finalSize.height = size.height / size.width * finalSize.width
                center.x = finalSize.width / size.width * center.x
                center.y = finalSize.width / size.width * center.y
                
                offset.y = center.y - self.bounds.size.height * CGFloat(1-0.618)
                if offset.y < 0 {
                    offset.y = 0
                } else if offset.y + self.bounds.size.height > finalSize.height {
                    finalSize.height = self.bounds.size.height
                    offset.y = finalSize.height
                }
                offset.y = -offset.y
            }
            
            var newImage: UIImage
            if self.debugFaceAware {
                let rawImage = UIImage(cgImage: image.cgImage!)
                UIGraphicsBeginImageContext(size)
                rawImage.draw(at: CGPoint.zero)
                
                let context = UIGraphicsGetCurrentContext()
                context!.setStrokeColor(UIColor.red.cgColor)
                context!.setLineWidth(3)
                
                for feature in features[0..<features.count] {
                    var faceViewBounds = feature.bounds!
                    faceViewBounds.origin.y = size.height - faceViewBounds.origin.y - faceViewBounds.size.height
                    
                    context!.addRect(faceViewBounds)
                    context!.drawPath(using: .stroke)
                }
                
                newImage = UIGraphicsGetImageFromCurrentImageContext()!
                UIGraphicsEndImageContext()
            } else {
                newImage = image
            }
            
            self.image = newImage
            
            let layer = self.imageLayer()
            layer.contents = newImage.cgImage
            print (CGRect(x: offset.x, y: offset.y, width: finalSize.width, height: finalSize.height))
            layer.frame = CGRect(x: offset.x, y: offset.y, width: finalSize.width, height: finalSize.height)
            self.didFocusOnFaces?()
        }
    }
    
    private func imageLayer() -> CALayer {
        if let layer = sublayer() {
            return layer
        }
        
        let subLayer = CALayer()
        subLayer.name = "AspectFillFaceAware"
        subLayer.actions = ["contents":NSNull(), "bounds":NSNull(), "position":NSNull()]
        layer.addSublayer(subLayer)
        return subLayer
    }
    
    private func removeImageLayer(image: UIImage?) {
        DispatchQueue.main.async {
            // avoid redundant layer when focus on faces for the image of cell specified in UITableView
            self.imageLayer().removeFromSuperlayer()
            self.image = image
        }
    }
    
    private func sublayer() -> CALayer? {
        if let sublayers = layer.sublayers {
            for layer in sublayers {
                if layer.name == "AspectFillFaceAware" {
                    return layer
                }
            }
        }
        return nil
    }
}

#endif
