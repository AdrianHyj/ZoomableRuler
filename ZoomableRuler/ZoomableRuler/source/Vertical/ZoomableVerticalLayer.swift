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
    /// 显示选中区域的颜色
    func layer(_ layer: ZoomableVerticalLayer, colorOfArea area: ZoomableRuler.SelectedArea) -> UIColor
}
protocol ZoomableVerticalLayerDelegate: NSObjectProtocol {
    func layer(_ layer: ZoomableVerticalLayer, areaID: String, withAction action: ZoomableRuler.AreaAction)
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
    // 每一个区域的间隔
    let areaSpace: CGFloat = 10.0

    /// 是否显示值刻度
    var showText: Bool = true

    /// 每一个值反应到屏幕的pixel
    private(set) var pixelPerUnit: CGFloat

    /// 二维数组
    /// 从上往下排，画出选中的区域
    var selectedAreas: [[ZoomableRuler.SelectedArea]] = [] {
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
            // 如果显示文字的时候，增加上面刻度的高度
            areaOriginX = showText ? (longLineWidth + 10 + timeTextSize.width + 5) : 0
            let lineCount: CGFloat = 4.0
            areaLineWidth = (rect.size.width - areaOriginX - (lineCount-1)*areaSpace)/lineCount
            for i in 0 ..< selectedAreas.count {
                let lineAreas = selectedAreas[i]
                var lineFrames: [String: CGRect] = [:]
                for area in lineAreas {
                    // 获取显示的颜色
                    let areaColor = zoomableDataSource?.layer(self, colorOfArea: area) ?? UIColor.green
                    ctx.setFillColor(areaColor.cgColor)
                    // 这里if else 的顺序是有讲究的，前者不被后者包含
                    // 例如 area.startValue < bottomValue && area.endValue > bottomValue 是 area.startValue < topValue && area.endValue > bottomValue 和 area.startValue < bottomValue && area.endValue > bottomValue 的父集，所以排到前面
                    // ！！！！！千万不要打乱顺序了！！！！！！
                    var rectCorner: UIRectCorner?
                    var areaRect: CGRect?
                    if area.endValue <= topValue {
                        // 不在范围内不需要画
                        continue
                    } else if area.startValue >= bottomValue {
                        // 不在范围内不需要画
                        continue
                    } else if area.startValue < topValue && area.endValue > bottomValue {
                        areaRect = CGRect(x: areaOriginX + CGFloat(i)*(areaLineWidth+areaSpace),
                                              y: 0,
                                              width: areaLineWidth,
                                              height: (bottomValue - topValue)*pixelPerUnit)
//                        print("1 - \(areaRect)")
                    } else if area.startValue < topValue && area.endValue > topValue {
                        rectCorner = [.bottomLeft, .bottomRight]
                        let tailValue = area.endValue > bottomValue ? bottomValue : area.endValue
                        areaRect = CGRect(x: areaOriginX + CGFloat(i)*(areaLineWidth+areaSpace),
                                          y: 0,
                                          width: areaLineWidth,
                                          height: (tailValue - topValue)*pixelPerUnit)
//                        print("2 - \(areaRect)")
                    } else if area.startValue < bottomValue && area.endValue > bottomValue {
                        rectCorner = [.topLeft, .topRight]
                        let headValue = area.startValue < topValue ? topValue : area.startValue
                        areaRect = CGRect(x: areaOriginX + CGFloat(i)*(areaLineWidth+areaSpace),
                                          y: (headValue - topValue)*pixelPerUnit,
                                          width: areaLineWidth,
                                          height: (bottomValue - headValue)*pixelPerUnit)
//                        print("3 - \(areaRect)")
                    } else if area.startValue > topValue && area.endValue < bottomValue {
                        rectCorner = .allCorners
                        areaRect = CGRect(x: areaOriginX + CGFloat(i)*(areaLineWidth+areaSpace),
                                          y: (area.startValue - topValue)*pixelPerUnit,
                                          width: areaLineWidth,
                                          height: (area.endValue - area.startValue)*pixelPerUnit)
//                        print("4 - \(areaRect)")
                    }

                    var areaPath: UIBezierPath?
                    if let areaRect = areaRect {
                        if let rectCorner = rectCorner {
                            areaPath = UIBezierPath(roundedRect: areaRect,
                                                    byRoundingCorners: rectCorner,
                                                    cornerRadii: CGSize(width: areaLineWidth/2, height: areaLineWidth/2))
                        } else {
                            areaPath = UIBezierPath(rect: areaRect)
                        }
                    }

                    if let areaPath = areaPath {
                        ctx.addPath(areaPath.cgPath)
                        ctx.closePath()
                        ctx.drawPath(using: .fill)
                        lineFrames[area.id] = areaRect

                        //如果圆角都不够就不用画图片了
                        if let image = area.icon, let areaRect = areaRect {
                            let imageScale = image.size.width/image.size.height
                            let imageRealHeight = areaRect.width/imageScale
                            let iconOffset = (area.startValue - topValue)*pixelPerUnit
                            if imageRealHeight <= areaRect.height, iconOffset > -imageRealHeight {
                                image.draw(in: CGRect(x: areaRect.origin.x,
                                                      y: areaRect.origin.y + (iconOffset > 0 ? 0: iconOffset),
                                                      width: areaRect.width,
                                                      height: imageRealHeight),
                                           blendMode: .normal,
                                           alpha: 1)
                                print("----> \(areaRect.origin.y) + \(iconOffset)")
                            }
                        }
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

    func point(_ point: CGPoint, ofAction action: ZoomableRuler.AreaAction) {
        var matchID = ""
        guard point.x > areaOriginX else { return }
        let lineIndex = Int(ceil(Double((point.x - areaOriginX)/(areaLineWidth+areaSpace)))) - 1
        guard lineIndex < visiableFrames.count else { return }
        let lineFrames = visiableFrames[lineIndex]
        for lineFramesID in lineFrames.keys {
            if lineFrames[lineFramesID]?.contains(point) ?? false {
                matchID = lineFramesID
                break
            }
        }
        if matchID.count > 0 {
            zoomableDelegate?.layer(self, areaID: matchID, withAction: action)
        }
    }
}
