//
//  ZoomableRuler.swift
//  ZoomableRuler
//
//  Created by Jin on 2022/7/28.
//

import UIKit

protocol ZoomableRulerDelegate: NSObjectProtocol {
    /// 当前中心的时间戳
    func ruler(_ ruler: ZoomableRuler, currentCenterValue unitValue: Double)
    /// 是否可以加载更多
    /// - Parameters:
    ///   - ruler: 尺子实例
    ///   - block: 可以处理完回调，回调true标识ruler可以加载更多
    ///   - unitValue: 请求加载更多的边界值
    func ruler(_ ruler: ZoomableRuler, shouldShowMoreInfo block: @escaping (Bool)->(), lessThan unitValue: Double)
    /// 当前到达最小值
    func rulerReachMinimumValue(_ ruler: ZoomableRuler)
    /// 是否可以加载更多
    /// - Parameters:
    ///   - ruler: 尺子实例
    ///   - block: 可以处理完回调，回调true标识ruler可以加载更多
    ///   - unitValue: 请求加载更多的边界值
    func ruler(_ ruler: ZoomableRuler, shouldShowMoreInfo block: @escaping (Bool)->(), moreThan unitValue: Double)
    /// 当前达到最大值
    func rulerReachMaximumValue(_ ruler: ZoomableRuler)
    /// 点击了区域的id
    func ruler(_ ruler: ZoomableRuler, didTapAreaID areaID: String)
    /// 用户拖动到的值
    func ruler(_ ruler: ZoomableRuler, userDidMoveToValue unitValue: Double)
}

struct ZoomableRulerSelectedArea {
    let id: String
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
    /// 理论上3个屏的内容能通过移动行成用户循环的错觉
    let layerMaxWidth: CGFloat = UIScreen.main.bounds.size.width*3
    /// 最小的layer宽度
    var layerMinWidth: CGFloat = 0
    /// 最小的内容宽度
    var scrollViewContentMinWidth: CGFloat = 0

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
    /// 显示文本的宽度
    let labelWidth: CGFloat
    /// 显示文本的高度
    let labelHeight: CGFloat
    /// 前后的空挡
    let marginWidth: CGFloat

    /// 缩放手势
    var pinchGesture: UIPinchGestureRecognizer?
    /// 点击手势
    var tapGesture: UITapGestureRecognizer?

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
        let attributeString = NSAttributedString.init(string: "00:00:00", attributes: [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 11)])
        labelWidth = attributeString.size().width + 5
        labelHeight = attributeString.size().height
        marginWidth = CGFloat(ceil(Double(labelWidth/2)))
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
        zLayer.dataSource = self
        zLayer.zoomableDelegate = self
        zLayer.totalWidth = scrollViewContentWidth
        zLayer.scale = startScale
        zLayer.marginWidth = marginWidth
        // layer的定位会再layoutSubviews的方法中完成
        zLayer.frame = CGRect(x: 0,
                              y: 0,
                              width: (scrollViewContentWidth > layerMaxWidth ? layerMaxWidth : scrollViewContentWidth) + marginWidth*2,
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
        // 上一刻和这一刻的缩放对比
        let scale = startScale/preScale

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        // 更新屏幕的px对应表达的数值
        let _ = defaultWidthByUpdatePixelPerUnit()

//        // CGFloat的位数是有限的，所以如果小数点前的位数增多，从两位数变到4位数的话，小数后就会自动舍弃
//        // 界面是通过scrollview的contentsize.width和layer的width做对比的，为了尽量保证数据一样，这里先做舍弃
//        let counts: CGFloat = 1000000000
//        let checkWidth = CGFloat(Int(scrollView.contentSize.width*scale*counts)/Int(counts))
        let checkWidth = scrollView.contentSize.width*scale
        zLayer.totalWidth = checkWidth < scrollViewContentMinWidth ? scrollViewContentMinWidth : checkWidth

//        zLayer.totalWidth = scrollView.contentSize.width*scale
        zLayer.scale = startScale

        // 同步初始值在此缩放比率下对应的坐标
        zLayer.update(withStartPoint: CGPoint(x: zLayer.startPoint.x * scale, y: 0),
                      pixelPerUnit: pixelPerUnit)

        let offset = scrollView.frame.size.width - scrollView.contentInset.left

        // 由于layer 和 contentsize.width 的缩放机制不同， layer只能根据自身的限制做缩放
        // CGFloat的位数是有限的，所以如果小数点前的位数增多，从两位数变到4位数的话，小数后就会自动舍弃
        // 这里 增加1px是为了小数的唔差不能精确判定 = < > 而做的
        var layerWidth = (zLayer.frame.size.width + 1 - marginWidth*2) < scrollView.contentSize.width ? zLayer.frame.size.width : zLayer.totalWidth + marginWidth*2
        if layerWidth > layerMaxWidth + marginWidth*2 {
            // 如果一开始就很少数据，不足一个屏，就可以放到到最大3个屏的layer
            layerWidth = layerMaxWidth + marginWidth*2
        } else if layerWidth < layerMinWidth + marginWidth*2 {
            // 在缩小的情况下
            // 缩小的时候，如果比 layerMinWidth（一开始通过判断定下来的）小，就停止
            layerWidth = layerMinWidth + marginWidth*2
        }
        var layerFrame = CGRect(x: (scrollView.contentOffset.x + offset)*scale - offset - zLayer.frame.size.width/2 - marginWidth,
                                y: zLayer.frame.origin.y,
                                width: layerWidth,
                                height: zLayer.frame.size.height)
        // 在缩放的情况下，如果右边超过了滚动区域的范围，强行向左缩放
        // 左边超过了的话，同理
        if layerFrame.maxX - marginWidth*2 > zLayer.totalWidth {
            layerFrame.origin.x = zLayer.totalWidth - zLayer.frame.size.width + marginWidth
        } else if layerFrame.minX < 0 {
            layerFrame.origin.x = -marginWidth
        }
        // 更新layer 的frame
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
        // 根据定义的加载一屏范围，求出中心点的所在的前后一屏
        var leftValue = CGFloat(Int(uintValue/screenUnitValue))*screenUnitValue
        var rightValue: CGFloat = leftValue + screenUnitValue

        // 看看最小值是否在这个范围内，如果在，就缩小展示范围
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
        // 最小的layer的宽度
        layerMinWidth = scrollViewContentWidth > layerMaxWidth ? layerMaxWidth : scrollViewContentWidth
        scrollViewContentMinWidth = scrollViewContentWidth

        return (CGPoint(x: (uintValue - leftValue)*pixelPerUnit, y: 0), scrollViewContentWidth)
    }

    /// 加载跟多左边的内容
    private func lessToGo() {
        guard let zLayer = zoomableLayer else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)

        // 默认三个屏幕的宽度
        var loadMoreWidth = defaultWidthByUpdatePixelPerUnit()

        // 计算增加的距离，理论上是默认距离（3个屏），但是需要根据最小值来做相应调整
        let oldStartPointX = zLayer.startPoint.x
        if let minValue = minUnitValue {
            // 买个保险，如果超出最小值，不增加距离
            if zLayer.centerUnitValue - (oldStartPointX - zLayer.frame.minX + marginWidth)/pixelPerUnit <= minValue {
                loadMoreWidth = 0
            } else {
                // 最小值离当前开始点的距离
                let minXDistance = abs(oldStartPointX - (zLayer.centerUnitValue - minValue)*pixelPerUnit)
                hasLessValue = loadMoreWidth < minXDistance
                loadMoreWidth = hasLessValue ? loadMoreWidth : minXDistance
            }
        }

        // 增加距离后，contentOffset的位置
        let scrollViewOffsetX = self.scrollView.contentOffset.x + loadMoreWidth

        // 增加距离后对应的初始中值的位置
        zLayer.startPoint = CGPoint(x: zLayer.startPoint.x + loadMoreWidth, y: zLayer.startPoint.y)
        zLayer.totalWidth = self.scrollView.contentSize.width + loadMoreWidth

        var layerFrame = zLayer.frame
        let layerWidth = (zLayer.totalWidth > layerMaxWidth ? layerMaxWidth : zLayer.totalWidth) + marginWidth*2
        layerFrame.size.width = layerWidth
        // 根据改变后的layer的宽度和当前Offset的坐标，计算出Layer需要的位置
        layerFrame.origin.x = scrollViewOffsetX - layerFrame.size.width/2 - marginWidth
        if layerFrame.maxX - marginWidth*2 > zLayer.totalWidth {
            // 如果再最后边缘
            layerFrame.origin.x = zLayer.totalWidth - layerFrame.size.width + marginWidth
        } else if layerFrame.minX - marginWidth < 0 {
            // 如果再最左边缘
            layerFrame.origin.x = -marginWidth
        }
        zLayer.frame = layerFrame

        self.scrollView.contentSize = CGSize(width: zLayer.totalWidth,
                                             height: self.scrollView.contentSize.height)
        self.scrollView.contentOffset = CGPoint(x: scrollViewOffsetX, y: self.scrollView.contentOffset.y)

        CATransaction.commit()
    }

    /// 增加右边的值
    /// 相应的注释可以参考lessToGo的方法
    private func moreToGo() {
        guard let zLayer = zoomableLayer else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)

        var loadMoreWidth = defaultWidthByUpdatePixelPerUnit()
        let oldStartPointX = zLayer.startPoint.x
        if let maxValue = maxUnitValue {
            if (zLayer.frame.maxX - marginWidth*2 - oldStartPointX)/pixelPerUnit + zLayer.centerUnitValue >= maxValue {
                loadMoreWidth = 0
            } else {
                // 最大值离当前开始点的距离
                let maxXDistance = (maxValue - zLayer.centerUnitValue)*pixelPerUnit - (zLayer.frame.maxX - marginWidth*2 - oldStartPointX)
                hasMoreValue = loadMoreWidth < maxXDistance
                loadMoreWidth = hasMoreValue ? loadMoreWidth : maxXDistance
            }
        }
        zLayer.totalWidth = self.scrollView.contentSize.width + loadMoreWidth

        var layerFrame = zLayer.frame
        let layerWidth = (zLayer.totalWidth > layerMaxWidth ? layerMaxWidth : zLayer.totalWidth) + marginWidth*2
        layerFrame.size.width = layerWidth
        if layerFrame.maxX - marginWidth*2 > zLayer.totalWidth {
            layerFrame.origin.x = zLayer.totalWidth - layerFrame.size.width + marginWidth
        } else if layerFrame.minX - marginWidth < 0 {
            layerFrame.origin.x = -marginWidth
        }
        zLayer.frame = layerFrame

        // 在右边增加宽度的话，不需要移动contentOffset
        self.scrollView.contentSize = CGSize(width: zLayer.totalWidth,
                                             height: self.scrollView.contentSize.height)

        CATransaction.commit()
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

        if contentOffsetX + scrollView.contentInset.left < 0 {
            if hasLessValue {
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
            } else {
                delegate?.rulerReachMinimumValue(self)
            }
        } else if contentOffsetX - scrollView.contentInset.right > contentSizeWidth - contentScreenWidth {
            if hasMoreValue {
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
            } else {
                delegate?.rulerReachMaximumValue(self)
            }
        }

        if contentOffsetX + contentScreenWidth/2 > zoomableLayer.frame.minX + zoomableLayer.frame.size.width/2 + marginWidth {
            var layerFrame = CGRect(x: (contentOffsetX + contentScreenWidth/2) - zoomableLayer.frame.size.width/2,
                                    y: 0,
                                    width: zoomableLayer.frame.width,
                                    height: zoomableLayer.frame.height)
            if layerFrame.maxX - marginWidth*2 > contentSizeWidth {
                // 如果需要移动的距离到右边边缘了，就按照右边边缘来保持不动
                layerFrame.origin.x = contentSizeWidth - layerFrame.size.width + marginWidth
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
        } else if contentOffsetX + contentScreenWidth/2 < zoomableLayer.frame.minX + marginWidth + zoomableLayer.frame.size.width/(2*3) {
            var layerFrame = CGRect(x: (contentOffsetX + contentScreenWidth/2) - zoomableLayer.frame.size.width/2,
                                    y: 0,
                                    width: zoomableLayer.frame.width,
                                    height: zoomableLayer.frame.height)
            if layerFrame.minX - marginWidth < 0 {
                // 如果需要移动的距离到左边边缘了，就按照左边边缘来保持不动
                layerFrame.origin.x = -marginWidth
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

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            // 用户确定选择的话，不会有 decelerate的
            delegate?.ruler(self, userDidMoveToValue: Double(centerUintValue))
        }
    }
}

extension ZoomableRuler: ZoomableLayerDataSource {
    func layerRequestLabelSize(_ layer: ZoomableLayer) -> CGSize {
        CGSize(width: labelWidth, height: labelHeight)
    }
}

extension ZoomableRuler: ZoomableLayerDelegate {
    func layer(_ layer: ZoomableLayer, didTapAreaID areaID: String) {
        delegate?.ruler(self, didTapAreaID: areaID)
    }
}
