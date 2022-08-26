//
//  ZoomableVerticalLayer.swift
//  ZoomableRuler
//
//  Created by Jin on 2022/8/25.
//

import UIKit

protocol ZoomableVerticalLayerDataSource: NSObjectProtocol {
    /// 显示文本的宽高
    func layerRequestLabelSize(_ layer: ZoomableVerticalLayer) -> CGSize
}
protocol ZoomableVerticalLayerDelegate: NSObjectProtocol {
    func layer(_ layer: ZoomableVerticalLayer, didTapAreaID areaID: String)
}

class ZoomableVerticalLayer: CALayer {
    weak var zoomableDataSource: ZoomableVerticalLayerDataSource?
    weak var zoomableDelegate: ZoomableVerticalLayerDelegate?

    /// 初始化时确定不变的第一个居中的值，所处于的坐标，后期会根据layer的frame的变化而做出对应的改变
    var startPoint: CGPoint
    /// 初始化时确定不变的第一个居中的值，用于判断划线，具体数值的显示
    let centerUnitValue: CGFloat
    /// 一屏内容所表达的大小
    let screenUnitValue: CGFloat
    /// 标尺线高度
    let lineHeight: CGFloat
    /// 总的高度
    var totalHeight: CGFloat = 0

    var scale: CGFloat = 1
     /// 上下空档
    var marginHeight: CGFloat = 0

    // 显示的区域开始的X坐标
    var areaOriginX: CGFloat = 0
    // 每一个区域的宽度
    var areaLineWidth: CGFloat = 0

    /// 是否显示值刻度
    var showText: Bool = true

    /// 每一个值反应到屏幕的pixel
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

    var visiableFrames: [[String: CGRect]] = []

    init(withStartPoint startPoint: CGPoint, screenUnitValue: CGFloat, centerUnitValue: CGFloat, pixelPerUnit: CGFloat, lineHeight: CGFloat) {
        self.startPoint = startPoint
        self.centerUnitValue = centerUnitValue
        self.screenUnitValue = screenUnitValue
        self.pixelPerUnit = pixelPerUnit
        self.lineHeight = lineHeight
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

    private func drawFrame(in rect: CGRect) {
        UIGraphicsBeginImageContextWithOptions(rect.size, false, UIScreen.main.scale)
        if let ctx = UIGraphicsGetCurrentContext() {

            visiableFrames.removeAll()
            // 短刻度
            let shortLineWidth: CGFloat = 6
            // 长刻度
            let longLineWidth: CGFloat = 10
            // text part
            let timeTextSize = zoomableDataSource?.layerRequestLabelSize(self) ?? CGSize.zero

            if showText {
                // 通过总长度和当前startpoint的中心值centerUnitValue算出当前的总值跨度是多少
                let startUnit = centerUnitValue - (totalHeight - startPoint.y)/pixelPerUnit
                let endUnit = centerUnitValue + startPoint.y/pixelPerUnit

                // 一格60s。如果按照屏高来算的话，默认三屏 screenUnitValue/(3*屏高)得出1屏多少pixel
                var pixelsPerLine: CGFloat = 60
                if scale >= 12*5 {
                    pixelsPerLine = pixelsPerLine/12/5
                } else if scale >= 12 {
                    pixelsPerLine = pixelsPerLine/12
                }
                // 计算有多少个标记
                let numberOfLine: CGFloat = (endUnit - startUnit) / pixelsPerLine
                let unitHeight: CGFloat = totalHeight / numberOfLine

                // 前面没有显示的格子的整数
                let preUnitCount = Int((rect.minY + marginHeight)/unitHeight)
                // 可显示的line的个数
                let visibleLineCount = ((rect.size.height - marginHeight*2)/unitHeight)
                // 第一个格子的起点
                let offsetY = (unitHeight - (rect.minY - CGFloat(preUnitCount)*unitHeight)) - lineHeight/2

                for visibleIndex in 0 ..< Int(visibleLineCount) {
                    let position: CGFloat = CGFloat(visibleIndex)*unitHeight
                    // 评断是长线还是短线, 12个格子一条长线，每个格子都是短线
                    // 第11条是短线，第12条是长线
                    let isLongLine = (preUnitCount+visibleIndex+1)%12 == 0
                    let upperLineRect = CGRect(x: 0,
                                               y: offsetY + position - lineHeight/2,
                                               width: isLongLine ? longLineWidth : shortLineWidth,
                                               height: 1)
                    ctx.setFillColor(UIColor.white.cgColor)
                    ctx.fill(upperLineRect)

                    if isLongLine {
                        let paragraphStyle = NSMutableParagraphStyle()
                        paragraphStyle.alignment = .center
                        let textAttr = [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 11.0),
                                        NSAttributedString.Key.foregroundColor: UIColor.white,
                                        NSAttributedString.Key.paragraphStyle: paragraphStyle]
                        let textRect = CGRect(x: upperLineRect.maxX + 10,
                                              y: upperLineRect.origin.y - timeTextSize.height/2,
                                              width: timeTextSize.width,
                                              height: timeTextSize.height)
                        let lineUnit: Int = Int(centerUnitValue + 8*3600.0 + (rect.minY + lineHeight/2 - startPoint.y + upperLineRect.origin.y + lineHeight/2)/pixelPerUnit)
                        let hour: Int = lineUnit%(24*3600)/3600
                        let min: Int = lineUnit%(24*3600)%3600/60
                        let sec: Int = lineUnit%(24*3600)%3600%60
                        let timeString = String(format: "%02d:%02d:%02d", hour, min, sec)
                        let ocString = timeString as NSString
                        ocString.draw(in: textRect, withAttributes: textAttr)
                    }
                }
            }

            // 画选择区域
            var topValue: CGFloat = 0
            if rect.minY > startPoint.y {
                topValue = (rect.minY - startPoint.y)/pixelPerUnit + centerUnitValue
            } else {
                topValue = centerUnitValue - (startPoint.y - rect.minY)/pixelPerUnit
            }
            let bottomValue = topValue + rect.size.height/pixelPerUnit
            areaOriginX = longLineWidth + 10 + timeTextSize.width + 5
            areaLineWidth = (rect.size.width - areaOriginX)/4.0
            ctx.setFillColor(UIColor.green.cgColor)
            for i in 0 ..< selectedAreas.count {
                let lineAreas = selectedAreas[i]
                var lineFrames: [String: CGRect] = [:]
                for area in lineAreas {
                    if area.endValue <= topValue {
                        continue
                    }
                    else if area.endValue > topValue {
                        let cut = area.startValue < topValue
                        let headValue = cut ? topValue : area.startValue
                        let tailValue = area.endValue > bottomValue ? bottomValue : area.endValue
                        let areaRect = CGRect(x: areaOriginX + CGFloat(i)*areaLineWidth,
                                              y: (headValue - topValue)*pixelPerUnit,
                                              width: areaLineWidth,
                                              height: (tailValue - headValue)*pixelPerUnit)
                        let areaPath = UIBezierPath(roundedRect: areaRect,
                                                    byRoundingCorners: (cut ? [.bottomLeft, .bottomRight] : .allCorners),
                                                    cornerRadii: CGSize(width: areaLineWidth/2, height: areaLineWidth/2))
                        ctx.addPath(areaPath.cgPath)
                        ctx.closePath()
                        ctx.drawPath(using: .fill)
                        lineFrames[area.id] = areaRect
                    } else if area.startValue < bottomValue {
                        let cut = area.endValue > bottomValue
                        let tailValue = cut ? bottomValue : area.endValue
                        let areaRect = CGRect(x: areaOriginX + CGFloat(i)*areaLineWidth,
                                              y: rect.size.height - (tailValue - area.startValue)/pixelPerUnit,
                                              width: areaLineWidth,
                                              height: (tailValue - area.startValue)/pixelPerUnit)
                        let areaPath = UIBezierPath(roundedRect: areaRect,
                                                    byRoundingCorners: (cut ? [.topLeft, .topRight] : .allCorners),
                                                    cornerRadii: CGSize(width: areaLineWidth/2, height: areaLineWidth/2))
                        ctx.addPath(areaPath.cgPath)
                        ctx.closePath()
                        ctx.drawPath(using: .fill)
                        lineFrames[area.id] = areaRect
                    } else if area.startValue >= bottomValue {
                        break
                    }
                }
                visiableFrames.append(lineFrames)
            }

            if let imageToDraw = UIGraphicsGetImageFromCurrentImageContext() {
                UIGraphicsEndImageContext()
                contents = imageToDraw.cgImage
            } else {
                UIGraphicsEndImageContext()
            }
        }
    }

    override func contains(_ p: CGPoint) -> Bool {
        guard p.x > areaOriginX else { return true}
        let lineIndex = Int(ceil(Double((p.x - areaOriginX)/areaLineWidth))) - 1
        guard lineIndex < visiableFrames.count else { return true }
        let lineFrames = visiableFrames[lineIndex]
        for lineFramesID in lineFrames.keys {
            if lineFrames[lineFramesID]?.contains(p) ?? false {
                zoomableDelegate?.layer(self, didTapAreaID: lineFramesID)
                break
            }
        }
        return true
    }

}
