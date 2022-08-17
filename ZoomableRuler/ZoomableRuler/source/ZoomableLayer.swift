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

    var scale: CGFloat = 1

    private(set) var pixelPerUnit: CGFloat

    /// 二维数组
    /// 从上往下排，画出选中的区域
    var selectedAreas: [[ZoomableRulerSelectedArea]] = [] {
        didSet {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            setNeedsDisplay(frame)
            CATransaction.commit()
        }
    }

    init(withStartPoint startPoint: CGPoint, screenUnitValue: CGFloat, centerUnitValue: CGFloat, pixelPerUnit: CGFloat, lineWidth: CGFloat) {
        self.startPoint = startPoint
        self.centerUnitValue = centerUnitValue
        self.screenUnitValue = screenUnitValue
        self.pixelPerUnit = pixelPerUnit
        self.lineWidth = lineWidth
        super.init()
        self.backgroundColor = UIColor.clear.cgColor
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

    func update(withStartPoint startPoint: CGPoint, pixelPerUnit: CGFloat) {
        self.startPoint = startPoint
        self.pixelPerUnit = pixelPerUnit
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

            // 一格60s。如果按照屏宽375来算的话，默认三屏 screenUnitValue/(3*375)得出1屏多少pixel
            var pixelsPerLine: CGFloat = 60
            if scale >= 12*5 {
                pixelsPerLine = pixelsPerLine/12/5
            } else if scale >= 12 {
                pixelsPerLine = pixelsPerLine/12
            }
            // 计算有多少个标记
            let numberOfLine: CGFloat = (endUnit - startUnit) / pixelsPerLine
            let unitWidth: CGFloat = totalWidth / numberOfLine

            // text part
            let attributeString = NSAttributedString.init(string: "00:00:00", attributes: [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 11)])
            let hourTextWidth = attributeString.size().width + 5
            let hourTextHeight = attributeString.size().height
            // 现在的edgepoint
//            let edgePoint = curEdgePoint()

            // 前面没有显示的格子的整数
            let preUnitCount = Int(rect.minX/unitWidth)
            // 可显示的line的个数，前后 + 1 确保
            let visibleLineCount = (rect.size.width / unitWidth) + 2
            // 第一个格子的起点
            let offsetX = -(rect.minX - CGFloat(preUnitCount)*unitWidth) - lineWidth/2

            let shortLineHeight: CGFloat = 6
            let longLineHeight: CGFloat = 10

            for visibleIndex in 0 ..< Int(visibleLineCount) {
                let i = visibleIndex
                let position: CGFloat = CGFloat(i)*unitWidth
//                // 超过显示范围的不理
//                if (offsetX + position < 0) || (offsetX + position) > rect.size.width + lineWidth/2 {
//                    continue
//                }
                // 评断是长线还是短线, 12个格子一条长线，每个格子都是短线
                // 第11条是短线，第12条是长线
                let isLongLine = (preUnitCount+i)%12 == 0
                let upperLineRect = CGRect(x: offsetX + position - lineWidth/2, y: 0, width: 1, height: isLongLine ? longLineHeight : shortLineHeight)
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
                    let sec: Int = lineUnit%(24*3600)%3600%60
                    let timeString = String(format: "%02d:%02d:%02d", hour, min, sec)
                    let ocString = timeString as NSString
                    ocString.draw(in: textRect, withAttributes: textAttr)
                }
            }

            // 画选择区域
            var leftValue: CGFloat = 0
            if rect.minX > startPoint.x {
                leftValue = (rect.minX - startPoint.x)/pixelPerUnit + centerUnitValue
            } else {
                leftValue = centerUnitValue - (startPoint.x - rect.minX)/pixelPerUnit
            }
            let rightValue = leftValue + rect.size.width/pixelPerUnit
            let originY = longLineHeight + 10 + hourTextHeight + 5
            let height = (rect.size.height - originY)/4.0
            ctx.setFillColor(UIColor.green.cgColor)
            for i in 0 ..< selectedAreas.count {
                let lineAreas = selectedAreas[i]
                for area in lineAreas {
                    if area.endValue <= leftValue {
                        continue
                    }
                    else if area.endValue > leftValue {
                        let cut = area.startValue < leftValue
                        let headValue = cut ? leftValue : area.startValue
                        let tailValue = area.endValue > rightValue ? rightValue : area.endValue
                        let areaPath = UIBezierPath(roundedRect: CGRect(x: (headValue - leftValue)*pixelPerUnit,
                                                                        y: originY + CGFloat(i)*height,
                                                                        width: (tailValue - headValue)*pixelPerUnit,
                                                                        height: height),
                                                    byRoundingCorners: (cut ? [.topRight, .bottomRight] : .allCorners),
                                                    cornerRadii: CGSize(width: height/2, height: height/2))
                        ctx.addPath(areaPath.cgPath)
                        ctx.closePath()
                        ctx.drawPath(using: .fill)
                    } else if area.startValue < rightValue {
                        let cut = area.endValue > rightValue
                        let tailValue = cut ? rightValue : area.endValue
                        let areaPath = UIBezierPath(roundedRect: CGRect(x: rect.size.width - (tailValue - area.startValue)/pixelPerUnit,
                                                                        y: originY + CGFloat(i)*height,
                                                                        width: (tailValue - area.startValue)/pixelPerUnit,
                                                                        height: height),
                                                    byRoundingCorners: (cut ? [.topLeft, .bottomLeft] : .allCorners),
                                                    cornerRadii: CGSize(width: height/2, height: height/2))
                        ctx.addPath(areaPath.cgPath)
                        ctx.closePath()
                        ctx.drawPath(using: .fill)
                    } else if area.startValue >= rightValue {
                        break
                    }
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
