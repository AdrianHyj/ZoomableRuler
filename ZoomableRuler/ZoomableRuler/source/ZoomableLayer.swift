//
//  ZoomableLayer.swift
//  ZoomableRuler
//
//  Created by Jin on 2022/7/28.
//

import UIKit

class ZoomableLayer: CALayer {
    override var frame: CGRect {
        didSet {
            setNeedsDisplay(frame)
        }
    }

    override func setNeedsDisplay(_ r: CGRect) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        // work
        drawFrame(in: r)
        CATransaction.commit()
    }

    private func drawFrame(in rect: CGRect) {
        UIGraphicsBeginImageContextWithOptions(rect.size, false, UIScreen.main.scale)
        if let ctx = UIGraphicsGetCurrentContext() {
            // text part
            let attributeString = NSAttributedString.init(string: "00:00", attributes: [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 11)])
            let hourTextWidth = attributeString.size().width
            let hourTextHeight = attributeString.size().height

            let lineSpace: CGFloat = 50.0
            let numberOfLine: Int = Int(rect.width / lineSpace)
            print(">>>>>>>>> rect :\(rect) >>>>>>>>>>")
//            ctx.beginPath()
            for i in 0 ..< numberOfLine {
                let position: CGFloat = CGFloat(i)*lineSpace

                let upperLineRect = CGRect(x: -0.5 + position, y: 0, width: 1, height: 6)

//                ctx.move(to: CGPoint(x: -0.5, y: 0))
//                ctx.addLine(to: CGPoint(x: -0.5, y: 0))
//                ctx.addLine(to: CGPoint(x: -0.5, y: 6))
//                ctx.setLineWidth(1)
                ctx.setFillColor(UIColor.black.cgColor)
                ctx.fill(upperLineRect)
                print("paint rect: \(upperLineRect)")
                let textAttr = [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 11.0),
                                NSAttributedString.Key.foregroundColor: UIColor.white]
                let textRect = CGRect(x: upperLineRect.origin.x - hourTextWidth/2,
                                      y: upperLineRect.maxY + 10,
                                      width: hourTextWidth,
                                      height: hourTextHeight)
                let ocString = "\(Int((upperLineRect.origin.x + rect.origin.x)/lineSpace))" as NSString
                ocString.draw(in: textRect, withAttributes: textAttr)
            }
//            ctx.closePath()
//            ctx.strokePath()
            print("<<<<<<<<<<<<<<<")
            if let imageToDraw = UIGraphicsGetImageFromCurrentImageContext() {
                UIGraphicsEndImageContext()
//                contentsRect = rect
                contents = imageToDraw.cgImage
            } else {
                UIGraphicsEndImageContext()
            }
        }
    }
}
