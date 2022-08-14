//
//  ZoomableLayer.swift
//  ZoomableRuler
//
//  Created by Jin on 2022/7/28.
//

import UIKit

class ZoomableLayer: CALayer {
    /// 初始化时确定不变的第一个居中的值，所处于的坐标，后期会根据layer的frame的变化而做出对应的改变
    var startPoint: CGPoint
    /// 初始化时确定不变的第一个居中的值，用于判断划线，具体数值的显示
    let centerUnitValue: CGFloat
    /// 一屏内容所表达的大小
    let screenUnitValue: CGFloat
    /// 标尺线的宽度
    let lineWidth: CGFloat
    /// 总的宽度
    var totalWidth: CGFloat = 0


    private(set) var pixelPerUnit: CGFloat
    private(set) var pixelPerLine: CGFloat

    init(withStartPoint startPoint: CGPoint, screenUnitValue: CGFloat, centerUnitValue: CGFloat, pixelPerUnit: CGFloat, pixelPerLine: CGFloat = 1, lineWidth: CGFloat) {
        self.startPoint = startPoint
        self.centerUnitValue = centerUnitValue
        self.screenUnitValue = screenUnitValue
        self.pixelPerUnit = pixelPerUnit
        self.pixelPerLine = pixelPerLine
        self.lineWidth = lineWidth
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

    func update(withStartPoint startPoint: CGPoint, pixelPerUnit: CGFloat, pixelPerLine: CGFloat) {
        self.startPoint = startPoint
        self.pixelPerUnit = pixelPerUnit
        self.pixelPerLine = pixelPerLine
        setNeedsDisplay(frame)
    }

    private func curEdgePoint() -> CGPoint {
        let leftValue = CGFloat(Int(self.centerUnitValue/screenUnitValue))*screenUnitValue
        let valuePixel = (self.centerUnitValue - leftValue)*pixelPerUnit
        return CGPoint(x: startPoint.x - valuePixel, y: 0)
    }

    private func drawFrame(in rect: CGRect) {
        UIGraphicsBeginImageContextWithOptions(rect.size, false, UIScreen.main.scale)
        if let ctx = UIGraphicsGetCurrentContext() {

            // 通过总长度和当前startpoint的中心值centerUnitValue算出当前的总值跨度是多少
            let startUnit = centerUnitValue - startPoint.x/pixelPerUnit
            let endUnit = centerUnitValue + (totalWidth - startPoint.x)/pixelPerUnit

            var pixelsPerLine: CGFloat = 60/5
            if rect.size.width >= UIScreen.main.bounds.width*10 {
                pixelsPerLine = pixelsPerLine/10
            } else if rect.size.width >= UIScreen.main.bounds.width*5 {
                pixelsPerLine = pixelsPerLine/5
            }
            // 计算有多少个标记
            let numberOfLine: CGFloat = (endUnit - startUnit) / pixelsPerLine
            print("pixelsPerLine: \(pixelsPerLine) - numberOfLine: \(numberOfLine)")
            let unitWidth: CGFloat = totalWidth / numberOfLine
            
            // text part
            let attributeString = NSAttributedString.init(string: "00:00", attributes: [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 11)])
            let hourTextWidth = attributeString.size().width + 5
            let hourTextHeight = attributeString.size().height
            // 现在的edgepoint
            let edgePoint = curEdgePoint()

//            let unitWidth = lineWidth + pixelPerLine
//            // 前面没有显示的格子的整数
            let preUnitCount = Int((rect.minX-edgePoint.x)/unitWidth)
//            // 第一个格子的起点
            let offsetX = -((rect.minX-edgePoint.x) - CGFloat(preUnitCount)*unitWidth) - lineWidth/2
//            let numberOfLine: Int = Int(rect.width / (unitWidth))

            for i in 0 ..< Int(numberOfLine) {
                let position: CGFloat = CGFloat(i)*unitWidth
                // 超过显示范围的不理
                if (offsetX + position < 0) || (offsetX + position) > rect.size.width + lineWidth/2 {
                    continue
                }
                // 评断是长线还是短线, 12个格子一条长线，每个格子都是短线
                // 第11条是短线，第12条是长线
                let isLongLine = (preUnitCount+i)%12 == 0
                let upperLineRect = CGRect(x: offsetX + position - lineWidth/2, y: 0, width: 1, height: isLongLine ? 12 : 6)
                ctx.setFillColor(UIColor.white.cgColor)
                ctx.fill(upperLineRect)

                if isLongLine {
                    let textAttr = [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 11.0),
                                    NSAttributedString.Key.foregroundColor: UIColor.white]
                    let textRect = CGRect(x: upperLineRect.origin.x - hourTextWidth/2,
                                          y: upperLineRect.maxY + 10,
                                          width: hourTextWidth,
                                          height: hourTextHeight)
                    let lineUnit: Int = Int(centerUnitValue + 8*3600.0 + (rect.minX + lineWidth/2 - startPoint.x + upperLineRect.origin.x + lineWidth/2)/pixelPerUnit)
                    let hour: Int = lineUnit%(24*3600)/3600
                    let min: Int = lineUnit%(24*3600)%3600/60
                    let timeString = String(format: "%02d:%02d", hour, min)
                    let ocString = timeString as NSString
                    ocString.draw(in: textRect, withAttributes: textAttr)
                }
            }
            if let imageToDraw = UIGraphicsGetImageFromCurrentImageContext() {
                UIGraphicsEndImageContext()
                contents = imageToDraw.cgImage
            } else {
                UIGraphicsEndImageContext()
            }
        }
    }
}
