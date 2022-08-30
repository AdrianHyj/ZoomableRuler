//
//  ZoomableVerticalRuler.swift
//  ZoomableRuler
//
//  Created by Jin on 2022/8/25.
//

import UIKit


protocol ZoomableVerticalRulerDelegate: NSObjectProtocol {
    /// 当前中心的时间戳
    func ruler(_ ruler: ZoomableVerticalRuler, currentCenterValue unitValue: Double)
    /// 是否可以加载更多
    /// - Parameters:
    ///   - ruler: 尺子实例
    ///   - block: 可以处理完回调，回调true标识ruler可以加载更多
    ///   - unitValue: 请求加载更多的边界值
    func ruler(_ ruler: ZoomableVerticalRuler, shouldShowMoreInfo block: @escaping (Bool)->(), lessThan unitValue: Double)
    /// 当前到达最小值
    func rulerReachMinimumValue(_ ruler: ZoomableVerticalRuler)
    /// 是否可以加载更多
    /// - Parameters:
    ///   - ruler: 尺子实例
    ///   - block: 可以处理完回调，回调true标识ruler可以加载更多
    ///   - unitValue: 请求加载更多的边界值
    func ruler(_ ruler: ZoomableVerticalRuler, shouldShowMoreInfo block: @escaping (Bool)->(), moreThan unitValue: Double)
    /// 当前达到最大值
    func rulerReachMaximumValue(_ ruler: ZoomableVerticalRuler)
    /// 点击了区域的id
    func ruler(_ ruler: ZoomableVerticalRuler, didTapAreaID areaID: String)
    /// 用户拖动到的值
    func ruler(_ ruler: ZoomableVerticalRuler, userDidMoveToValue unitValue: Double)
    /// 用户拖动了ruler
    func userDidDragRuler(_ ruler: ZoomableVerticalRuler)
    /// 请求Area需要的颜色
    func ruler(_ ruler: ZoomableVerticalRuler, requestColorWithArea area: ZoomableRulerSelectedArea) -> UIColor
}


class ZoomableVerticalRuler: UIControl {

    weak var delegate: ZoomableVerticalRulerDelegate?

    /// 显示内容的Layer
    private var zoomableLayer: ZoomableVerticalLayer?

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
  /// 用户piching的比例
    var pinchScale: CGFloat = 1.0
   /// 缩放时上一刻的比例
    var minScale: CGFloat = 1
    /// 缩放时上一刻的比例
    var maxScale: CGFloat = 120
       /// 是否在pinch来调整比例
    var pinching: Bool = false

    /// 一屏内容所表达的大小
    let screenUnitValue: CGFloat = 3*3600.0
    /// 理论上3倍于Scrollview的内容能通过移动行成用户循环的错觉
    var layerMaxHeight: CGFloat = UIScreen.main.bounds.height*3
    /// 最小的layer高度
    var layerMinHeight: CGFloat = 0
    /// 最小的内容高度
    var scrollViewContentMinHeight: CGFloat = 0

    /// 显示在中央的数值
    private(set) var centerUnitValue: CGFloat = 0
    /// Ruler最小的值
    private(set) var minUnitValue: CGFloat?
    /// Ruler最大的值
    private(set) var maxUnitValue: CGFloat?
    /// 每一个pixel对应的数值
    private(set) var pixelPerUnit: CGFloat = 1

    /// 线的高度
    let lineHeight: CGFloat = 1.0
    /// 显示文本的宽度
    let labelWidth: CGFloat
    /// 显示文本的高度
    let labelHeight: CGFloat
    /// 上下的空挡
    let marginHeight: CGFloat

    /// 缩放手势
    var pinchGesture: UIPinchGestureRecognizer?
    /// 点击手势
    var tapGesture: UITapGestureRecognizer?

    /// 是否显示值刻度
    var showText: Bool = true {
        didSet {
            zoomableLayer?.showText = showText
        }
    }

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
        scrollView.showsVerticalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.backgroundColor = .clear
        return scrollView
    }()

    override init(frame: CGRect) {
        let attributeString = NSAttributedString.init(string: "00:00:00", attributes: [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 11)])
        labelWidth = attributeString.size().width + 5
        labelHeight = attributeString.size().height
        marginHeight = CGFloat(ceil(Double(labelHeight/2)))
        super.init(frame: frame)
        backgroundColor = .clear

        addSubview(scrollView)

        let pichGR = UIPinchGestureRecognizer.init(target: self, action: #selector(pinchAction(recoginer:)))
        addGestureRecognizer(pichGR)
        pinchGesture = pichGR

        let tabGR = UITapGestureRecognizer.init(target: self, action: #selector(tapAction(recoginer:)))
        addGestureRecognizer(tabGR)
        tapGesture = tabGR
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
        self.centerUnitValue = CGFloat(Int(value))
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

    @objc private func tapAction(recoginer: UITapGestureRecognizer) -> Void {
        guard let zoomableLayer = zoomableLayer else {
            return
        }
        let point = recoginer.location(in: scrollView)
        let layerPoint = zoomableLayer.convert(point, from: scrollView.layer)
        let _ = zoomableLayer.contains(layerPoint)
    }

    func scrollToTime(_ timestamp: Double) {
        guard let zLayer = zoomableLayer else { return }
        let timePoint = CGPoint(x: 0,
                                y: zLayer.startPoint.y - scrollView.frame.size.height/2 + (timestamp - zLayer.centerUnitValue)*pixelPerUnit)
        // 如果需求的点在当前scrollview的范围之外
        if (timePoint.y < -zLayer.startPoint.y + scrollView.contentInset.top) || (timePoint.y > scrollView.contentSize.height) {
            centerUnitValue = timestamp
            resetScrollView(withFrame: frame)
        } else {
            scrollView.contentOffset = timePoint
        }
    }

    private func resetScrollView(withFrame frame: CGRect) {
        // clean layer
        zoomableLayer?.removeFromSuperlayer()
        zoomableLayer = nil

        let contentInsetTop = CGFloat(ceil(Double(frame.size.height/2)))
        scrollView.contentInset = UIEdgeInsets(top: contentInsetTop, left: 0, bottom: contentInsetTop, right: 0)
        scrollView.frame = CGRect(x: 0, y: 0, width: frame.size.width, height: frame.size.height)
        layerMaxHeight = scrollView.frame.size.height*3

        let (startPoint, scrollViewContentHeight) = startPointAndHeight(withCenterUnitValue: centerUnitValue)

        scrollView.contentSize = CGSize(width: scrollView.frame.size.width,
                                        height: scrollViewContentHeight)
        scrollView.contentOffset = CGPoint(x: 0, y: startPoint.y - scrollView.frame.size.height/2)

        // layer
        let zLayer = ZoomableVerticalLayer(withStartPoint: startPoint,
                                   screenUnitValue: screenUnitValue,
                                   centerUnitValue: centerUnitValue,
                                   pixelPerUnit: pixelPerUnit,
                                   lineHeight: lineHeight)
        zLayer.showText = showText
        zLayer.zoomableDataSource = self
        zLayer.zoomableDelegate = self
        zLayer.totalHeight = scrollViewContentHeight
        zLayer.scale = startScale
        zLayer.marginHeight = marginHeight

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        // layer的定位会再layoutSubviews的方法中完成
        zLayer.frame = CGRect(x: 0,
                              y: 0,
                              width: scrollView.frame.size.width,
                              height: (scrollViewContentHeight > layerMaxHeight ? layerMaxHeight : scrollViewContentHeight) + marginHeight*2)
        CATransaction.commit()
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
        // 上一刻和这一刻的缩放对比
        let scale = startScale/preScale

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        // 更新屏幕的px对应表达的数值
        let _ = defaultHeightByUpdatePixelPerUnit()

        let checkHeight = scrollView.contentSize.height*scale
        zLayer.totalHeight = checkHeight < scrollViewContentMinHeight ? scrollViewContentMinHeight : checkHeight

        zLayer.scale = startScale

        // 同步初始值在此缩放比率下对应的坐标
        zLayer.update(withStartPoint: CGPoint(x: 0, y: zLayer.startPoint.y * scale),
                      pixelPerUnit: pixelPerUnit)

        let offset = scrollView.frame.size.height - scrollView.contentInset.top

        // 由于layer 和 contentsize.height 的缩放机制不同， layer只能根据自身的限制做缩放
        // CGFloat的位数是有限的，所以如果小数点前的位数增多，从两位数变到4位数的话，小数后就会自动舍弃
        // 这里 增加1px是为了小数的唔差不能精确判定 = < > 而做的
        var layerHeight = (zLayer.frame.size.height + 1 - marginHeight*2) < scrollView.contentSize.height ? zLayer.frame.size.height : zLayer.totalHeight + marginHeight*2
        if layerHeight > layerMaxHeight + marginHeight*2 {
            // 如果一开始就很少数据，不足一个屏，就可以放到到最大3个屏的layer
            layerHeight = layerMaxHeight + marginHeight*2
        } else if layerHeight < layerMinHeight + marginHeight*2 {
            // 在缩小的情况下
            // 缩小的时候，如果比 layerMinHeight（一开始通过判断定下来的）小，就停止
            layerHeight = layerMinHeight + marginHeight*2
        }
        var layerFrame = CGRect(x: zLayer.frame.origin.x,
                                y: (scrollView.contentOffset.y + offset)*scale - offset - zLayer.frame.size.height/2 - marginHeight,
                                width: zLayer.frame.size.width,
                                height: layerHeight)
        // 在缩放的情况下，如果右边超过了滚动区域的范围，强行向左缩放
        // 左边超过了的话，同理
        if layerFrame.maxY - marginHeight*2 > zLayer.totalHeight {
            layerFrame.origin.y = zLayer.totalHeight - zLayer.frame.size.height + marginHeight
        } else if layerFrame.minY < 0 {
            layerFrame.origin.y = -marginHeight
        }
        // 更新layer 的frame
        zLayer.frame = layerFrame

        // 同步当前时间戳
        let scrollViewOffsetY = (scrollView.contentOffset.y + offset)*scale - offset
        centerUnitValue = zLayer.centerUnitValue + (scrollViewOffsetY + scrollView.contentInset.top - zLayer.startPoint.y)/pixelPerUnit
        delegate?.ruler(self, currentCenterValue: Double(centerUnitValue))

        scrollView.contentOffset = CGPoint(x: scrollView.contentOffset.x,
                                           y: scrollViewOffsetY)

        scrollView.contentSize = CGSize(width: scrollView.contentSize.width,
                                        height:  zLayer.totalHeight)

        preScale = startScale

        CATransaction.commit()
    }

    /// 获取新一页，新一个时间段的高度，顺便更新pixelPerUnit
    /// - Returns: 新一个时间段的高度
    private func defaultHeightByUpdatePixelPerUnit() -> CGFloat {
        let scrollViewContentHeight = layerMaxHeight*startScale
        pixelPerUnit = scrollViewContentHeight/screenUnitValue
        return scrollViewContentHeight
    }

    /// 计算起始坐标
    private func startPointAndHeight(withCenterUnitValue unitValue: CGFloat) -> (CGPoint, CGFloat){
        // 根据定义的加载一屏范围，求出中心点的所在的前后一屏
        var (topValue, bottomValue) = calculateEdgeValue(withUnitValue: unitValue)

        // 看看最小值是否在这个范围内，如果在，就缩小展示范围
        if let minValue = minUnitValue {
            hasLessValue = topValue > minValue
            topValue = hasLessValue ? topValue: minValue
        }
        if let maxValue = maxUnitValue {
            hasMoreValue = maxValue > bottomValue
            bottomValue = hasMoreValue ? bottomValue : maxValue
        }

        var scrollViewContentHeight = defaultHeightByUpdatePixelPerUnit()
        let maxY = (bottomValue - unitValue)*pixelPerUnit
        let minY = (unitValue - topValue)*pixelPerUnit
        // 是否一开始就小于默认滚动的范围, 如果是，则算出对应的Contentsize, 如果不是，则直接用默认的高度(后续判断是否询问继续加载更多内容的时候需要)
        scrollViewContentHeight = (maxY + minY) < scrollViewContentHeight ? (maxY + minY) : scrollViewContentHeight

        // 如果计算出来比3屏高度小，可以根据是否有更多的标记，添加更多数据
        if scrollViewContentHeight < layerMaxHeight {
            let moreDistance = defaultHeightByUpdatePixelPerUnit()
            if (hasLessValue && !hasMoreValue) {
                if let value = minUnitValue {
                    hasLessValue = (topValue - screenUnitValue) > value
                    let topMoreValue = hasLessValue ? (topValue - screenUnitValue) : value
                    scrollViewContentHeight = maxY + (unitValue - topMoreValue)*pixelPerUnit
                    topValue = topMoreValue
                } else {
                    scrollViewContentHeight = scrollViewContentHeight + moreDistance
                    topValue = topValue - screenUnitValue
                }
            } else if (!hasLessValue && hasMoreValue) {
                if let value = maxUnitValue {
                    hasMoreValue = value > (bottomValue + screenUnitValue)
                    let bottomMoreValue = hasMoreValue ? (bottomValue + screenUnitValue) : value
                    scrollViewContentHeight = minY + (bottomMoreValue - unitValue)*pixelPerUnit
                    bottomValue = bottomValue + bottomMoreValue
                } else {
                    scrollViewContentHeight = scrollViewContentHeight + moreDistance
                    bottomValue = bottomValue + screenUnitValue
                }
            }
        }
        // 最小的layer的高度
        layerMinHeight = scrollViewContentHeight > layerMaxHeight ? layerMaxHeight : scrollViewContentHeight
        scrollViewContentMinHeight = scrollViewContentHeight

        return (CGPoint(x: 0, y: (unitValue - topValue)*pixelPerUnit), scrollViewContentHeight)
    }

    /// 加载跟多左边的内容
    private func lessToGo() {
        guard let zLayer = zoomableLayer else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)

        // 默认三个屏幕的高度
        var loadMoreHeight = defaultHeightByUpdatePixelPerUnit()

        // 计算增加的距离，理论上是默认距离（3个屏），但是需要根据最小值来做相应调整
        let oldStartPointY = zLayer.startPoint.y
        if let minValue = minUnitValue {
            // 买个保险，如果超出最小值，不增加距离
            if zLayer.centerUnitValue - (oldStartPointY - zLayer.frame.minY + marginHeight)/pixelPerUnit <= minValue {
                loadMoreHeight = 0
            } else {
                // 最小值离当前开始点的距离
                let minYDistance = abs(oldStartPointY - (zLayer.centerUnitValue - minValue)*pixelPerUnit)
                hasLessValue = loadMoreHeight < minYDistance
                loadMoreHeight = hasLessValue ? loadMoreHeight : minYDistance
            }
        }

        // 增加距离后，contentOffset的位置
        let scrollViewOffsetY = self.scrollView.contentOffset.y + loadMoreHeight

        // 增加距离后对应的初始中值的位置
        zLayer.startPoint = CGPoint(x: zLayer.startPoint.x, y: zLayer.startPoint.y + loadMoreHeight)
        zLayer.totalHeight = self.scrollView.contentSize.height + loadMoreHeight

        var layerFrame = zLayer.frame
        let layerHeight = (zLayer.totalHeight > layerMaxHeight ? layerMaxHeight : zLayer.totalHeight) + marginHeight*2
        layerFrame.size.height = layerHeight
        // 根据改变后的layer的高度和当前Offset的坐标，计算出Layer需要的位置
        layerFrame.origin.y = scrollViewOffsetY - layerFrame.size.height/2 - marginHeight
        if layerFrame.maxY - marginHeight*2 > zLayer.totalHeight {
            // 如果再最后边缘
            layerFrame.origin.y = zLayer.totalHeight - layerFrame.size.height + marginHeight
        } else if layerFrame.minY - marginHeight < 0 {
            // 如果再最左边缘
            layerFrame.origin.y = -marginHeight
        }
        zLayer.frame = layerFrame

        self.scrollView.contentSize = CGSize(width: self.scrollView.contentSize.width,
                                             height: zLayer.totalHeight)
        self.scrollView.contentOffset = CGPoint(x: self.scrollView.contentOffset.x, y: scrollViewOffsetY)

        CATransaction.commit()
    }

    /// 增加右边的值
    /// 相应的注释可以参考lessToGo的方法
    private func moreToGo() {
        guard let zLayer = zoomableLayer else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)

        var loadMoreHeight = defaultHeightByUpdatePixelPerUnit()
        let oldStartPointY = zLayer.startPoint.y
        if let maxValue = maxUnitValue {
            if (zLayer.frame.maxY - marginHeight*2 - oldStartPointY)/pixelPerUnit + zLayer.centerUnitValue >= maxValue {
                loadMoreHeight = 0
            } else {
                // 最大值离当前开始点的距离
                let maxYDistance = (maxValue - zLayer.centerUnitValue)*pixelPerUnit - (zLayer.frame.maxY - marginHeight*2 - oldStartPointY)
                hasMoreValue = loadMoreHeight < maxYDistance
                loadMoreHeight = hasMoreValue ? loadMoreHeight : maxYDistance
            }
        }
        zLayer.totalHeight = self.scrollView.contentSize.height + loadMoreHeight

        var layerFrame = zLayer.frame
        let layerHeight = (zLayer.totalHeight > layerMaxHeight ? layerMaxHeight : zLayer.totalHeight) + marginHeight*2
        layerFrame.size.height = layerHeight
        if layerFrame.maxY - marginHeight*2 > zLayer.totalHeight {
            layerFrame.origin.y = zLayer.totalHeight - layerFrame.size.height + marginHeight
        } else if layerFrame.minY - marginHeight < 0 {
            layerFrame.origin.y = -marginHeight
        }
        zLayer.frame = layerFrame

        // 在下面增加高度的话，不需要移动contentOffset
        self.scrollView.contentSize = CGSize(width: self.scrollView.contentSize.width,
                                             height: zLayer.totalHeight)

        CATransaction.commit()
    }

    /// 按照screenUnitValue来算出给出的值所掉落的时间区间
    /// - Parameter unitValue: 值
    /// - Returns: 返回 (左区间, 右区间) 的值
    private func calculateEdgeValue(withUnitValue unitValue: CGFloat) -> (CGFloat, CGFloat) {
        let minValue = CGFloat(Int(unitValue/screenUnitValue))*screenUnitValue
        let maxValue: CGFloat = minValue + screenUnitValue
        return (minValue, maxValue)
    }
}

// MARK: - UIScrollViewDelegate
extension ZoomableVerticalRuler: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        // 保证有Layer
        guard let zoomableLayer = self.zoomableLayer, !pinching else { return }

        let contentOffsetY = scrollView.contentOffset.y
        let contentSizeHeight = scrollView.contentSize.height
        let contentScreenHeight = scrollView.frame.size.height

        // 同步当前时间戳
        centerUnitValue = zoomableLayer.centerUnitValue + (contentOffsetY + scrollView.contentInset.top - zoomableLayer.startPoint.y)/pixelPerUnit
        delegate?.ruler(self, currentCenterValue: Double(centerUnitValue))

        if contentOffsetY + scrollView.contentInset.top < 0 {
            if hasLessValue {
                if !requestingLess {
                    requestingLess = true
                    // 节点的时间必须卡在每一个小时的0s，也就是 0:00/03:00/06:00
                    let curlessValue = centerUnitValue - contentScreenHeight/2*pixelPerUnit
                    let (_, moreValue) = calculateEdgeValue(withUnitValue: curlessValue)
                    delegate?.ruler(self, shouldShowMoreInfo: { [weak self] should in
                        self?.requestingLess = false
                        if should {
                            self?.lessToGo()
                        }
                    }, lessThan: Double(moreValue))
                }
                return
            } else {
                delegate?.rulerReachMinimumValue(self)
            }
        } else if contentOffsetY - scrollView.contentInset.bottom > contentSizeHeight - contentScreenHeight {
            if hasMoreValue {
                if !requestingMore {
                    requestingMore = true
                    // 节点的时间必须卡在每一个小时的0s，也就是 0:00/03:00/06:00
                    let curlessValue = centerUnitValue + contentScreenHeight/2*pixelPerUnit
                    let (lessValue, _) = calculateEdgeValue(withUnitValue: curlessValue)
                    delegate?.ruler(self, shouldShowMoreInfo: { [weak self] should in
                        self?.requestingMore = false
                        if should {
                            self?.moreToGo()
                        }
                    }, moreThan: Double(lessValue))
                }
                return
            } else {
                delegate?.rulerReachMaximumValue(self)
            }
        }

        if contentOffsetY + contentScreenHeight/2 > zoomableLayer.frame.minY + zoomableLayer.frame.size.height/2 + marginHeight {
            var layerFrame = CGRect(x: 0,
                                    y: (contentOffsetY + contentScreenHeight) - zoomableLayer.frame.size.height/2,
                                    width: zoomableLayer.frame.width,
                                    height: zoomableLayer.frame.height)
            if layerFrame.maxY - marginHeight*2 > contentSizeHeight {
                // 如果需要移动的距离到右边边缘了，就按照右边边缘来保持不动
                layerFrame.origin.y = contentSizeHeight - layerFrame.size.height + marginHeight
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                zoomableLayer.frame = layerFrame
                CATransaction.commit()
            } else {
                // 向右移动一个屏
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                zoomableLayer.frame = layerFrame
                CATransaction.commit()
            }
        } else if contentOffsetY + contentScreenHeight/2 < zoomableLayer.frame.minY + marginHeight + zoomableLayer.frame.size.height/(2*3) {
            var layerFrame = CGRect(x: 0,
                                    y: (contentOffsetY + contentScreenHeight) - zoomableLayer.frame.size.height/2,
                                    width: zoomableLayer.frame.width,
                                    height: zoomableLayer.frame.height)
            if layerFrame.minY - marginHeight < 0 {
                // 如果需要移动的距离到左边边缘了，就按照左边边缘来保持不动
                layerFrame.origin.y = -marginHeight
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                zoomableLayer.frame = layerFrame
                CATransaction.commit()
            } else {
                // 向左移动一个屏
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                zoomableLayer.frame = layerFrame
                CATransaction.commit()
            }
        }
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        delegate?.userDidDragRuler(self)
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            // 用户确定选择的话，不会有 decelerate的
            delegate?.ruler(self, userDidMoveToValue: Double(centerUnitValue))
        }
    }
}

extension ZoomableVerticalRuler: ZoomableVerticalLayerDataSource {
    func layer(_ layer: ZoomableVerticalLayer, colorOfArea area: ZoomableRulerSelectedArea) -> UIColor {
        delegate?.ruler(self, requestColorWithArea: area) ?? .green
    }

    func layerRequestLabelSize(_ layer: ZoomableVerticalLayer) -> CGSize {
        CGSize(width: labelWidth, height: labelHeight)
    }
}

extension ZoomableVerticalRuler: ZoomableVerticalLayerDelegate {
    func layer(_ layer: ZoomableVerticalLayer, didTapAreaID areaID: String) {
        delegate?.ruler(self, didTapAreaID: areaID)
    }
}

