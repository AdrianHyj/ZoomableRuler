//
//  ZoomableLayer.swift
//  ZoomableRuler
//
//  Created by Jin on 2022/7/28.
//

import UIKit

protocol ZoomableLayerDataSource: NSObjectProtocol {
    /// 显示文本的宽高
    func layerRequestLabelSize(_ layer: ZoomableLayer) -> CGSize
}
protocol ZoomableLayerDelegate: NSObjectProtocol {
    func layer(_ layer: ZoomableLayer, didTapAreaID areaID: String)
}

class ZoomableLayer: CALayer {
    weak var dataSource: ZoomableLayerDataSource?
    weak var zoomableDelegate: ZoomableLayerDelegate?

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
     /// 前后的空挡
    var marginWidth: CGFloat = 0

    // 显示的区域开始的Y坐标
    var areaOriginY: CGFloat = 0
    // 每一个区域的高度
    var areaLineHeight: CGFloat = 0

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

    private func drawFrame(in rect: CGRect) {
        UIGraphicsBeginImageContextWithOptions(rect.size, false, UIScreen.main.scale)
        if let ctx = UIGraphicsGetCurrentContext() {

            visiableFrames.removeAll()
            // 短刻度
            let shortLineHeight: CGFloat = 6
            // 长刻度
            let longLineHeight: CGFloat = 10
            // text part
            let timeTextSize = dataSource?.layerRequestLabelSize(self) ?? CGSize.zero

            if showText {
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

                // 前面没有显示的格子的整数
                let preUnitCount = Int((rect.minX + marginWidth)/unitWidth)
                // 可显示的line的个数
                let visibleLineCount = ((rect.size.width - marginWidth*2)/unitWidth)
                // 第一个格子的起点
                let offsetX = (unitWidth - (rect.minX - CGFloat(preUnitCount)*unitWidth)) - lineWidth/2

                for visibleIndex in 0 ..< Int(visibleLineCount) {
                    let position: CGFloat = CGFloat(visibleIndex)*unitWidth
                    // 评断是长线还是短线, 12个格子一条长线，每个格子都是短线
                    // 第11条是短线，第12条是长线
                    let isLongLine = (preUnitCount+visibleIndex+1)%12 == 0
                    let upperLineRect = CGRect(x: offsetX + position - lineWidth/2, y: 0, width: 1, height: isLongLine ? longLineHeight : shortLineHeight)
                    ctx.setFillColor(UIColor.white.cgColor)
                    ctx.fill(upperLineRect)

                    if isLongLine {
                        let paragraphStyle = NSMutableParagraphStyle()
                        paragraphStyle.alignment = .center
                        let textAttr = [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 11.0),
                                        NSAttributedString.Key.foregroundColor: UIColor.white,
                                        NSAttributedString.Key.paragraphStyle: paragraphStyle]
                        let textRect = CGRect(x: upperLineRect.origin.x - timeTextSize.width/2,
                                              y: upperLineRect.maxY + 10,
                                              width: timeTextSize.width,
                                              height: timeTextSize.height)
                        let lineUnit: Int = Int(centerUnitValue + 8*3600.0 + (rect.minX + lineWidth/2 - startPoint.x + upperLineRect.origin.x + lineWidth/2)/pixelPerUnit)
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
            var leftValue: CGFloat = 0
            if rect.minX > startPoint.x {
                leftValue = (rect.minX - startPoint.x)/pixelPerUnit + centerUnitValue
            } else {
                leftValue = centerUnitValue - (startPoint.x - rect.minX)/pixelPerUnit
            }
            let rightValue = leftValue + rect.size.width/pixelPerUnit
            areaOriginY = longLineHeight + 10 + timeTextSize.height + 5
            areaLineHeight = (rect.size.height - areaOriginY)/4.0
            ctx.setFillColor(UIColor.green.cgColor)
            for i in 0 ..< selectedAreas.count {
                let lineAreas = selectedAreas[i]
                var lineFrames: [String: CGRect] = [:]
                for area in lineAreas {
                    if area.endValue <= leftValue {
                        continue
                    }
                    else if area.endValue > leftValue {
                        let cut = area.startValue < leftValue
                        let headValue = cut ? leftValue : area.startValue
                        let tailValue = area.endValue > rightValue ? rightValue : area.endValue
                        let areaRect = CGRect(x: (headValue - leftValue)*pixelPerUnit,
                                              y: areaOriginY + CGFloat(i)*areaLineHeight,
                                              width: (tailValue - headValue)*pixelPerUnit,
                                              height: areaLineHeight)
                        let areaPath = UIBezierPath(roundedRect: areaRect,
                                                    byRoundingCorners: (cut ? [.topRight, .bottomRight] : .allCorners),
                                                    cornerRadii: CGSize(width: areaLineHeight/2, height: areaLineHeight/2))
                        ctx.addPath(areaPath.cgPath)
                        ctx.closePath()
                        ctx.drawPath(using: .fill)
                        lineFrames[area.id] = areaRect
                    } else if area.startValue < rightValue {
                        let cut = area.endValue > rightValue
                        let tailValue = cut ? rightValue : area.endValue
                        let areaRect = CGRect(x: rect.size.width - (tailValue - area.startValue)/pixelPerUnit,
                                              y: areaOriginY + CGFloat(i)*areaLineHeight,
                                              width: (tailValue - area.startValue)/pixelPerUnit,
                                              height: areaLineHeight)
                        let areaPath = UIBezierPath(roundedRect: areaRect,
                                                    byRoundingCorners: (cut ? [.topLeft, .bottomLeft] : .allCorners),
                                                    cornerRadii: CGSize(width: areaLineHeight/2, height: areaLineHeight/2))
                        ctx.addPath(areaPath.cgPath)
                        ctx.closePath()
                        ctx.drawPath(using: .fill)
                        lineFrames[area.id] = areaRect
                    } else if area.startValue >= rightValue {
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
        guard p.y > areaOriginY else { return true}
        let lineIndex = Int(ceil(Double((p.y - areaOriginY)/areaLineHeight))) - 1
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
