//
//  ZoomableRuler.swift
//  ZoomableRuler
//
//  Created by Jin on 2022/7/28.
//

import UIKit

protocol ZoomableRulerDelegate: NSObjectProtocol {
    func ruler(_ ruler: ZoomableRuler, currentCenterValue unitValue: Double)
    func ruler(_ ruler: ZoomableRuler, shouldShowMoreInfo block: @escaping (Bool)->(), lessThan unitValue: Double)
    func ruler(_ ruler: ZoomableRuler, shouldShowMoreInfo block: @escaping (Bool)->(), moreThan unitValue: Double)
}

struct ZoomableRulerSelectedArea {
    let startValue: Double
    let endValue: Double
}

class ZoomableRuler: UIControl {

    weak var delegate: ZoomableRulerDelegate?
    /// 显示内容的Layer
    var zoomableLayer: ZoomableLayer?

    /// 正在请求更小的值，是否还有
    var requestingLess = false
    /// 是否还有更小的值范围等待加载
    var hasLessValue: Bool = true
    /// 正在请求更大的值，是否还有
    var requestingMore = false
    /// 是否还有更大的值范围等待加载
    var hasMoreValue: Bool = true
    /// 缩放时初始比例
    var startScale: CGFloat = 1
    /// 缩放时上一刻的比例
    var preScale: CGFloat = 1
    /// 缩放时上一刻的比例
    var minScale: CGFloat = 1
    /// 缩放时上一刻的比例
    var maxScale: CGFloat = 120
    /// 用户piching的比例
    var pinchScale: CGFloat = 1.0
    /// 是否在pinch来调整比例
    var pinching: Bool = false

    /// 一屏内容所表达的大小
    let screenUnitValue: CGFloat = 3*3600.0
    /// 理论上3个屏的内容能通过移动行成用户循环的错觉
    let layerMaxWidth: CGFloat = UIScreen.main.bounds.size.width * 3
    /// 理论上3个屏的内容能通过移动行成用户循环的错觉
    var layerMinWidth: CGFloat = 0

    /// 显示在中央的数值
    private(set) var centerUintValue: CGFloat = 0
    /// Ruler最小的值
    private(set) var minUnitValue: CGFloat?
    /// Ruler最大的值
    private(set) var maxUnitValue: CGFloat?
    /// 每一个pixel对应的数值
    private(set) var pixelPerUnit: CGFloat = 1

    /// 线的宽度
    let lineWidth: CGFloat = 1.0

    /// 缩放手势
    var pinchGesture: UIPinchGestureRecognizer?

    /// 二维数组
    /// 从上往下排，画出选中的区域
    /// 同一排的数据，应排序好，item的startValue从小到大排序好
    var selectedAreas: [[ZoomableRulerSelectedArea]] = [] {
        didSet {
            zoomableLayer?.selectedAreas = selectedAreas
        }
    }

    lazy var scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.delegate = self
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.backgroundColor = .clear
        return scrollView
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear

        addSubview(scrollView)

        let pichGR = UIPinchGestureRecognizer.init(target: self, action: #selector(pinchAction(recoginer:)))
        addGestureRecognizer(pichGR)
        pinchGesture = pichGR
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setCenterUnitValue(_ value: Double, maxUnitValue: Double? = nil, minUnitValue: Double? = nil) {
        self.maxUnitValue = nil
        self.minUnitValue = nil
        if let maxValue = maxUnitValue, value <= maxValue {
            self.maxUnitValue = CGFloat(Int(maxValue))
        }
        if let minValue = minUnitValue, value >= minValue {
            self.minUnitValue = CGFloat(Int(minValue))
        }
        self.centerUintValue = CGFloat(Int(value))
        resetScrollView(withFrame: frame)
    }

    @objc private func pinchAction(recoginer: UIPinchGestureRecognizer) -> Void {
        // 每一次 recognizer.scale 都是从大概1.0的左右开始缩小或者放大
        if recoginer.state == .began {
            pinchScale = recoginer.scale
            pinching = true
        }
        else if recoginer.state == .changed {
            // 缩放时更新layerFrame
            pinchScale = recoginer.scale / pinchScale
            if pinchScale * startScale > maxScale {
                pinchScale = maxScale/startScale
            } else if pinchScale * startScale < minScale {
                pinchScale = minScale/startScale
            }
            startScale = pinchScale * startScale
            setNeedsLayout()
        } else if recoginer.state == .ended || recoginer.state == .cancelled || recoginer.state == .failed {
            pinching = false
        }
    }

    func scrollToTime(_ timestamp: Double) {
        guard let zLayer = zoomableLayer else { return }
        let timePoint = CGPoint(x: zLayer.startPoint.x + (timestamp - zLayer.centerUnitValue)*pixelPerUnit, y: 0)
        // 如果需求的点在当前scrollview的范围之外
        if (timePoint.x < -zLayer.startPoint.x + scrollView.contentInset.left) || (timePoint.x > scrollView.contentSize.width) {
            centerUintValue = timestamp
            resetScrollView(withFrame: frame)
        } else {
            scrollView.contentOffset = timePoint
        }
    }

    private func resetScrollView(withFrame frame: CGRect) {
        let contentInsetLeft = CGFloat(ceil(Double(frame.size.width/2)))
        scrollView.contentInset = UIEdgeInsets(top: 0, left: contentInsetLeft, bottom: 0, right: contentInsetLeft)
        scrollView.frame = CGRect(x: 0, y: 0, width: frame.size.width, height: frame.size.height)

        let (startPoint, scrollViewContentWidth) = startPointAndWidth(withCenterUintValue: centerUintValue)

        scrollView.contentSize = CGSize(width: scrollViewContentWidth,
                                        height: scrollView.frame.size.height)
        scrollView.contentOffset = CGPoint(x: startPoint.x - scrollView.frame.size.width/2, y: 0)

        // layer
        let zLayer = ZoomableLayer(withStartPoint: startPoint,
                                   screenUnitValue: screenUnitValue,
                                   centerUnitValue: centerUintValue,
                                   pixelPerUnit: pixelPerUnit,
                                   lineWidth: lineWidth)
        zLayer.totalWidth = scrollViewContentWidth
        zLayer.scale = startScale
        zLayer.frame = CGRect(x: scrollViewContentWidth > layerMaxWidth ? (scrollViewContentWidth - layerMaxWidth) : 0,
                              y: startPoint.y,
                              width: scrollViewContentWidth > layerMaxWidth ? layerMaxWidth : scrollViewContentWidth,
                              height: scrollView.frame.size.height)

        scrollView.layer.addSublayer(zLayer)
        zoomableLayer = zLayer
        // layout subview
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        guard let zLayer = zoomableLayer else {
            return
        }
        let scale = startScale/preScale

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        let _ = defaultWidthByUpdatePixelPerUnit()

        zLayer.totalWidth = scrollView.contentSize.width*scale
        zLayer.scale = startScale

        zLayer.update(withStartPoint: CGPoint(x: zLayer.startPoint.x * scale, y: 0),
                      pixelPerUnit: pixelPerUnit)

        let offset = scrollView.frame.size.width - scrollView.contentInset.left
        var layerWidth = zLayer.frame.size.width*scale
        if layerWidth > layerMaxWidth {
            // 如果一开始就很少数据，不足一个屏，就可以放到到最大3个屏的layer
            layerWidth = layerMaxWidth
        } else if layerWidth < layerMinWidth {
            // 在缩小的情况下
            // 缩小的时候，如果比 layerMinWidth（一开始通过判断定下来的）小，就停止
            layerWidth = layerMinWidth
        }
        var layerFrame = CGRect(x: (scrollView.contentOffset.x + offset)*scale - offset - zLayer.frame.size.width/2,
                                y: zLayer.frame.origin.y,
                                width: layerWidth,
                                height: zLayer.frame.size.height)
        if layerFrame.maxX > zLayer.totalWidth {
            layerFrame.origin.x = zLayer.totalWidth - zLayer.frame.size.width
        } else if layerFrame.minX < 0 {
            layerFrame.origin.x = 0
        }
        zLayer.frame = layerFrame

        scrollView.contentOffset = CGPoint(x: (scrollView.contentOffset.x + offset)*scale - offset,
                                               y: scrollView.contentOffset.y)

        scrollView.contentSize = CGSize(width: zLayer.totalWidth,
                                        height: scrollView.contentSize.height)

        preScale = startScale

        CATransaction.commit()
    }

    /// 获取新一页，新一个时间段的宽度，顺便更新pixelPerUnit
    /// - Returns: 新一个时间段的宽度
    private func defaultWidthByUpdatePixelPerUnit() -> CGFloat {
        let scrollViewContentWidth = layerMaxWidth*startScale
        pixelPerUnit = scrollViewContentWidth/screenUnitValue
        return scrollViewContentWidth
    }

    /// 计算起始坐标
    private func startPointAndWidth(withCenterUintValue uintValue: CGFloat) -> (CGPoint, CGFloat){
        var leftValue = CGFloat(Int(uintValue/screenUnitValue))*screenUnitValue
        var rightValue: CGFloat = leftValue + screenUnitValue

        if let minValue = minUnitValue {
            hasLessValue = leftValue > minValue
            leftValue = hasLessValue ? leftValue: minValue
        }
        if let maxValue = maxUnitValue {
            hasMoreValue = maxValue > rightValue
            rightValue = hasMoreValue ? rightValue : maxValue
        }

        var scrollViewContentWidth = defaultWidthByUpdatePixelPerUnit()
        let maxX = (rightValue - uintValue)*pixelPerUnit
        let minX = (uintValue - leftValue)*pixelPerUnit
        // 是否一开始就小于默认滚动的范围, 如果是，则算出对应的Contentsize, 如果不是，则直接用默认的宽度(后续判断是否询问继续加载更多内容的时候需要)
        scrollViewContentWidth = (maxX + minX) < scrollViewContentWidth ? (maxX + minX) : scrollViewContentWidth

        // 如果计算出来比3屏宽度小，可以根据是否有更多的标记，添加更多数据
        if scrollViewContentWidth < layerMaxWidth {
            let moreDistance = defaultWidthByUpdatePixelPerUnit()
            if (hasLessValue && !hasMoreValue) {
                if let value = minUnitValue {
                    hasLessValue = (leftValue - screenUnitValue) > value
                    let leftMoreValue = hasLessValue ? (leftValue - screenUnitValue) : value
                    scrollViewContentWidth = maxX + (uintValue - leftMoreValue)*pixelPerUnit
                    leftValue = leftMoreValue
                } else {
                    scrollViewContentWidth = scrollViewContentWidth + moreDistance
                    leftValue = leftValue - screenUnitValue
                }
            } else if (!hasLessValue && hasMoreValue) {
                if let value = maxUnitValue {
                    hasMoreValue = value > (rightValue + screenUnitValue)
                    let rightMoreValue = hasMoreValue ? (rightValue + screenUnitValue) : value
                    scrollViewContentWidth = minX + (rightMoreValue - uintValue)*pixelPerUnit
                    rightValue = rightValue + rightMoreValue
                } else {
                    scrollViewContentWidth = scrollViewContentWidth + moreDistance
                    rightValue = rightValue + screenUnitValue
                }
            }
        }
        layerMinWidth = scrollViewContentWidth > layerMaxWidth ? layerMaxWidth : scrollViewContentWidth
        return (CGPoint(x: (uintValue - leftValue)*pixelPerUnit, y: 0), scrollViewContentWidth)
    }
}

// MARK: - UIScrollViewDelegate
extension ZoomableRuler: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        // 保证有Layer
        guard let zoomableLayer = self.zoomableLayer, !pinching else { return }

        let contentOffsetX = scrollView.contentOffset.x
        let contentSizeWidth = scrollView.contentSize.width
        let contentScreenWidth = scrollView.frame.size.width

        // 同步当前时间戳
        centerUintValue = zoomableLayer.centerUnitValue + (contentOffsetX + scrollView.contentInset.left - zoomableLayer.startPoint.x)/pixelPerUnit
        delegate?.ruler(self, currentCenterValue: Double(centerUintValue))

        guard !pinching else { return }
        // 如果在最大最小值都提供情况下，初始化后，滚动的内容达不到倍数，layer的宽度和scrollView.contentSize一样，不用刷新
        if (!hasMoreValue && !hasLessValue) {
            return
        }
        if contentOffsetX < 0 {
            guard hasLessValue else { return }
            if !requestingLess {
                requestingLess = true
                delegate?.ruler(self, shouldShowMoreInfo: { [weak self] should in
                    self?.requestingLess = false
                    if should {
                        self?.lessToGo()
                    }
                }, lessThan: Double(centerUintValue - contentScreenWidth/2*pixelPerUnit))
            }
            return
        } else if contentOffsetX > contentSizeWidth - contentScreenWidth {
            guard hasMoreValue else { return }
            if !requestingMore {
                requestingMore = true
                delegate?.ruler(self, shouldShowMoreInfo: { [weak self] should in
                    self?.requestingMore = false
                    if should {
                        self?.moreToGo()
                    }
                }, moreThan: Double(centerUintValue + contentScreenWidth/2*pixelPerUnit))
            }
            return
        }

        if contentOffsetX > zoomableLayer.frame.maxX - contentScreenWidth*3/2 {
            var layerFrame = CGRect(x: contentOffsetX - contentScreenWidth,
                                    y: 0,
                                    width: zoomableLayer.frame.width,
                                    height: zoomableLayer.frame.height)
            if layerFrame.maxX > contentSizeWidth {
                layerFrame.origin.x = contentSizeWidth - layerFrame.size.width
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                print(" ---- > 1 - \(layerFrame) - contentsize: \(contentSizeWidth)")
                zoomableLayer.frame = layerFrame
                CATransaction.commit()
            } else {
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                print(" ---- > 2 - \(layerFrame) - contentsize: \(contentSizeWidth)")
                zoomableLayer.frame = layerFrame
                CATransaction.commit()
            }
        } else if contentOffsetX < zoomableLayer.frame.minX + contentScreenWidth/2 {
            var layerFrame = CGRect(x: contentOffsetX - contentScreenWidth,
                                    y: 0,
                                    width: zoomableLayer.frame.width,
                                    height: zoomableLayer.frame.height)
            if layerFrame.minX < 0 {
                layerFrame.origin.x = 0
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                print(" ---- > 3 - \(layerFrame) - contentsize: \(contentSizeWidth)")
                zoomableLayer.frame = layerFrame
                CATransaction.commit()
            } else {
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                print(" ---- > 4 - \(layerFrame) - contentsize: \(contentSizeWidth)")
                zoomableLayer.frame = layerFrame
                CATransaction.commit()
            }
        }
    }

    private func lessToGo() {
        guard let zLayer = zoomableLayer else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)

        var loadMoreWidth = defaultWidthByUpdatePixelPerUnit()

        let oldStartPointX = zLayer.startPoint.x
        if let minValue = minUnitValue {
            if zLayer.centerUnitValue - (oldStartPointX - zLayer.frame.minX)/pixelPerUnit <= minValue {
                loadMoreWidth = 0
            } else {
                // 最小值离当前开始点的距离
                let minXDistance = abs(oldStartPointX - (zLayer.centerUnitValue - minValue)*pixelPerUnit)
                loadMoreWidth = loadMoreWidth > minXDistance ? minXDistance : loadMoreWidth
            }
        }

        let scrollViewOffsetX = self.scrollView.contentOffset.x + loadMoreWidth

        zLayer.startPoint = CGPoint(x: zLayer.startPoint.x + loadMoreWidth, y: zLayer.startPoint.y)
        zLayer.totalWidth = self.scrollView.contentSize.width + loadMoreWidth
        var layerFrame = zLayer.frame
        let layerWidth = zLayer.totalWidth > layerMaxWidth ? layerMaxWidth : zLayer.totalWidth
        layerFrame.size.width = layerWidth
        layerFrame.origin.x = scrollViewOffsetX - layerFrame.size.width/2
        if layerFrame.maxX > zLayer.totalWidth {
            layerFrame.origin.x = zLayer.totalWidth - layerFrame.size.width
        } else if layerFrame.minX < 0 {
            layerFrame.origin.x = 0
        }
        zLayer.frame = layerFrame

        self.scrollView.contentSize = CGSize(width: zLayer.totalWidth,
                                             height: self.scrollView.contentSize.height)
        self.scrollView.contentOffset = CGPoint(x: scrollViewOffsetX, y: self.scrollView.contentOffset.y)

        CATransaction.commit()
    }

    private func moreToGo() {
        guard let zLayer = zoomableLayer else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)

        var loadMoreWidth = defaultWidthByUpdatePixelPerUnit()
        let oldStartPointX = zLayer.startPoint.x
        if let maxValue = maxUnitValue {
            if (zLayer.frame.maxX - oldStartPointX)/pixelPerUnit + zLayer.centerUnitValue >= maxValue {
                loadMoreWidth = 0
            } else {
                // 最大值离当前开始点的距离
                let maxXDistance = (maxValue - zLayer.centerUnitValue)*pixelPerUnit - (zLayer.frame.maxX - oldStartPointX)
                loadMoreWidth = loadMoreWidth > maxXDistance ? maxXDistance : loadMoreWidth
            }
        }
        zLayer.totalWidth = self.scrollView.contentSize.width + loadMoreWidth

        var layerFrame = zLayer.frame
        let layerWidth = zLayer.totalWidth > layerMaxWidth ? layerMaxWidth : zLayer.totalWidth
        layerFrame.size.width = layerWidth
        if layerFrame.maxX > zLayer.totalWidth {
            layerFrame.origin.x = zLayer.totalWidth - layerFrame.size.width
        } else if layerFrame.minX < 0 {
            layerFrame.origin.x = 0
        }
        zLayer.frame = layerFrame

        self.scrollView.contentSize = CGSize(width: zLayer.totalWidth,
                                             height: self.scrollView.contentSize.height)

        CATransaction.commit()
    }
}
