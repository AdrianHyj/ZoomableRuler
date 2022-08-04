//
//  ZoomableLayer.swift
//  ZoomableRuler
//
//  Created by Jin on 2022/7/28.
//

import UIKit

protocol ZoomableLayerDataSource: NSObjectProtocol {
    func layerRequesetCenterUnitValue(_ layer: ZoomableLayer) -> CGFloat
}

class ZoomableLayer: CALayer {
    weak var dataSource: ZoomableLayerDataSource?

    var startPoint: CGPoint
    let centerUnitValue: CGFloat

    var pixelPerUnit: CGFloat {
        didSet {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            setNeedsDisplay(frame)
            CATransaction.commit()
        }
    }
    var pixelPerLine: CGFloat {
        didSet {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            setNeedsDisplay(frame)
            CATransaction.commit()
        }
    }

    init(withStartPoint startPoint: CGPoint, centerUnitValue: CGFloat, pixelPerUnit: CGFloat, pixelPerLine: CGFloat = 1, dataSource: ZoomableLayerDataSource) {
        self.startPoint = startPoint
        self.centerUnitValue = centerUnitValue
        self.pixelPerUnit = pixelPerUnit
        self.pixelPerLine = pixelPerLine
        self.dataSource = dataSource
        super.init()
        self.backgroundColor = UIColor.blue.cgColor
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var frame: CGRect {
        didSet {
            setNeedsDisplay(frame)
        }
    }

    override func setNeedsDisplay(_ r: CGRect) {
        // work
        drawFrame(in: r)
    }

    private func drawFrame(in rect: CGRect) {
        UIGraphicsBeginImageContextWithOptions(rect.size, false, UIScreen.main.scale)
        if let ctx = UIGraphicsGetCurrentContext() {
            // text part
            let attributeString = NSAttributedString.init(string: "00:00", attributes: [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 11)])
            let hourTextWidth = attributeString.size().width + 5
            let hourTextHeight = attributeString.size().height

//            let centerUnitValue = dataSource?.layerRequesetCenterUnitValue(self) ?? 0
            let lineWidth: CGFloat = 1.0
//            let offsetX = ((rect.minX - centerPoint.x)/pixelPerLine - CGFloat(Int((rect.minX - centerPoint.x)/pixelPerLine)))*pixelPerLine
            let offsetX = (pixelPerLine+lineWidth) - ((rect.minX-startPoint.x) - CGFloat(Int((rect.minX-startPoint.x)/(pixelPerLine+lineWidth)))*(pixelPerLine+lineWidth)) - 0.5
            let numberOfLine: Int = Int(rect.width / (pixelPerLine+lineWidth))
//            print("============ \((rect.minX-startPoint.x)/(pixelPerLine+lineWidth)) - \(Int((rect.minX-startPoint.x)/(pixelPerLine+lineWidth)))")
//            print(">>>>>>>>> rect :\(rect) - \(offsetX) >>>>>>>>>>")
//            ctx.beginPath()
            for i in 0 ..< numberOfLine {
                let position: CGFloat = CGFloat(i)*(pixelPerLine+lineWidth)

                let upperLineRect = CGRect(x: offsetX + position, y: 0, width: 1, height: 6)

//                ctx.move(to: CGPoint(x: -0.5, y: 0))
//                ctx.addLine(to: CGPoint(x: -0.5, y: 0))
//                ctx.addLine(to: CGPoint(x: -0.5, y: 6))
//                ctx.setLineWidth(1)
                ctx.setFillColor(UIColor.black.cgColor)
                ctx.fill(upperLineRect)
                let textAttr = [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 11.0),
                                NSAttributedString.Key.foregroundColor: UIColor.white]
                let textRect = CGRect(x: upperLineRect.origin.x - hourTextWidth/2,
                                      y: upperLineRect.maxY + 10,
                                      width: hourTextWidth,
                                      height: hourTextHeight)
                let lineUnit: Int = Int(centerUnitValue + 8*3600.0 + (rect.minX - startPoint.x + upperLineRect.origin.x)/pixelPerUnit)
                let hour: Int = lineUnit%(24*3600)/3600
                let min: Int = lineUnit%(24*3600)%3600/60
//                print("paint rect: \(upperLineRect) with hourString: \(hour) minString: \(min)")
                let timeString = String(format: "%02d:%02d", hour, min)
                let ocString = timeString as NSString
                ocString.draw(in: textRect, withAttributes: textAttr)
            }
//            ctx.closePath()
//            ctx.strokePath()
//            print("<<<<<<<<<<<<<<<")
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
