//
//  ZoomableRuler.swift
//  ZoomableRuler
//
//  Created by Jin on 2022/7/28.
//

import UIKit

protocol ZoomableRulerDelegate: NSObjectProtocol {
    func ruler(_ ruler: ZoomableRuler, currentCenterValue unitValue: Float)
    func ruler(_ ruler: ZoomableRuler, shouldShowMoreInfo block: @escaping (Bool)->(), lessThan unitValue: CGFloat)
    func ruler(_ ruler: ZoomableRuler, shouldShowMoreInfo block: @escaping (Bool)->(), moreThan unitValue: CGFloat)
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
    var startScale: CGFloat = 2
    /// 用户piching的比例
    var pichScale: CGFloat = 1.0

    /// 显示在中央的数值
    private(set) var centerUintValue: CGFloat = 0
    /// Ruler最小的值
    private(set) var minUnitValue: CGFloat?
    /// Ruler最大的值
    private(set) var maxUnitValue: CGFloat?
    /// 每一个pixel对应的数值
    private(set) var pixelPerUnit: CGFloat = 0

    /// 内容基于滚动页面大小来刷新的宽度倍数，默认是3
    var screenTimes: CGFloat {
        startScale * 3
    }
    /// 一屏内容所表达的大小
    let screenUnitValue: CGFloat = 8*3600.0

    /// 缩放手势
    var pinchGesture: UIPinchGestureRecognizer?

    lazy var scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.delegate = self
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never
        return scrollView
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(scrollView)
        scrollView.backgroundColor = .lightGray

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
        if let maxValue = maxUnitValue, value < maxValue {
            self.maxUnitValue = CGFloat(maxValue)
        }
        if let minValue = minUnitValue, value > minValue {
            self.minUnitValue = CGFloat(minValue)
        }
        self.centerUintValue = CGFloat(value)
        resetScrollView(withFrame: frame)
    }

    @objc private func pinchAction(recoginer: UIPinchGestureRecognizer) -> Void {
        // 每一次 recognizer.scale 都是从大概1.0的左右开始缩小或者放大
        if recoginer.state == .began {
            pichScale = recoginer.scale
        }
        else if recoginer.state == .changed {
            // 缩放时更新layerFrame
            pichScale = recoginer.scale / pichScale
//            print("pichScale: \(pichScale)")
            if pichScale * startScale > 4 {
                pichScale = 4/startScale
            } else if pichScale * startScale < 1 {
                pichScale = 1/startScale
            }
            startScale = pichScale * startScale
//            print("scorllview scale: \(startScale)")
            setNeedsLayout()
        }
    }

    private func resetScrollView(withFrame frame: CGRect) {

        let scrollViewContentWidth = frame.size.width*screenTimes
        let contentInsetLeft = CGFloat(floor(Double(frame.size.width/2)))
        scrollView.contentInset = UIEdgeInsets(top: 0, left: contentInsetLeft, bottom: 0, right: contentInsetLeft)
        scrollView.frame = CGRect(x: 0, y: 0, width: frame.size.width, height: frame.size.height)
        scrollView.contentSize = CGSize(width: scrollViewContentWidth,
                                        height: scrollView.frame.size.height)

        let startPoint = startPoint(withCenterUintValue: centerUintValue)
        scrollView.contentOffset = CGPoint(x: startPoint.x - scrollView.frame.size.width/2, y: 0)

        pixelPerUnit = scrollViewContentWidth/screenUnitValue
        // layer
        let zLayer = ZoomableLayer(withStartPoint: startPoint,
                                   centerUnitValue: centerUintValue,
                                   pixelPerUnit: pixelPerUnit,
                                   pixelPerLine: 40,
                                   dataSource: self)
        scrollView.layer.addSublayer(zLayer)
        zoomableLayer = zLayer

        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let scrollViewContentWidth = scrollView.frame.width*screenTimes
        let scale = scrollViewContentWidth/scrollView.contentSize.width
        let startPoint = CGPoint(x: scale*(zoomableLayer?.startPoint.x ?? 0), y: 0)

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        pixelPerUnit = scrollViewContentWidth/screenUnitValue

        if let zLayer = zoomableLayer {
            zLayer.update(withStartPoint: startPoint,
                                  pixelPerUnit: pixelPerUnit,
                                  pixelPerLine: 40*startScale/2)

            zLayer.frame = CGRect(x: zLayer.frame.minX*scale,
                                  y: startPoint.y,
                                  width: scrollViewContentWidth,
                                  height: scrollView.frame.size.height)
        }

        scrollView.contentSize = CGSize(width: scrollViewContentWidth,
                                        height: scrollView.frame.size.height)

        scrollView.contentOffset = CGPoint(x: scale*(scrollView.contentOffset.x + scrollView.frame.size.width/2) - scrollView.frame.size.width/2,
                                           y: 0)
//        scrollView.delegate?.scrollViewDidScroll!(scrollView)
        print("content changed - \(scrollView.contentSize) - \(scrollView.contentOffset) - \(String(describing: zoomableLayer?.frame))")
        CATransaction.commit()
    }

    /// 计算起始坐标
    private func startPoint(withCenterUintValue uintValue: CGFloat) -> CGPoint {
        var leftValue = CGFloat(Int(uintValue/screenUnitValue))*screenUnitValue
        var rightValue: CGFloat = leftValue + screenUnitValue

        if let minValue = minUnitValue {
            hasLessValue = leftValue >= minValue
            leftValue = hasLessValue ? leftValue: minValue
        }
        if let maxValue = maxUnitValue {
            hasMoreValue = maxValue > rightValue
            rightValue = hasMoreValue ? rightValue : maxValue
        }
        var scrollViewContentWidth = scrollView.frame.width*screenTimes

        pixelPerUnit = scrollViewContentWidth/screenUnitValue
        let maxX = (rightValue - centerUintValue)*pixelPerUnit
        let minX = (centerUintValue - leftValue)*pixelPerUnit
        // 是否一开始就小于默认滚动的范围, 如果是，则算出对应的Contentsize, 如果不是，则直接用默认的宽度(后续判断是否询问继续加载更多内容的时候需要)
        scrollViewContentWidth = (maxX + minX) < scrollViewContentWidth ? (maxX + minX) : scrollViewContentWidth

        return CGPoint(x: (centerUintValue - leftValue)*pixelPerUnit, y: 0)
    }
}

// MARK: - UIScrollViewDelegate
extension ZoomableRuler: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        // 保证有Layer
        guard let zoomableLayer = self.zoomableLayer else { return }

        let contentOffsetX = scrollView.contentOffset.x
        let contentSizeWidth = scrollView.contentSize.width
        let contentScreenWidth = scrollView.frame.size.width

        // 同步当前时间戳
        centerUintValue = zoomableLayer.centerUnitValue + (contentOffsetX + scrollView.frame.width/2 - zoomableLayer.startPoint.x)/pixelPerUnit
        delegate?.ruler(self, currentCenterValue: Float(centerUintValue))
        print("aaaaaaaaaaaaa1 - \(contentOffsetX) - \(contentSizeWidth) - \(contentScreenWidth) - \(scrollView.contentInset.left)")
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
                }, lessThan: centerUintValue - contentScreenWidth/2*pixelPerUnit)
            }
            return
        } else if contentOffsetX > scrollView.contentSize.width - scrollView.frame.size.width {
            guard hasMoreValue else { return }
            if !requestingMore {
                requestingMore = true
                delegate?.ruler(self, shouldShowMoreInfo: { [weak self] should in
                    self?.requestingMore = false
                    if should {
                        self?.moreToGo()
                    }
                }, moreThan: centerUintValue + contentScreenWidth/2*pixelPerUnit)
            }
            return
        }

        if contentOffsetX > zoomableLayer.frame.maxX - contentScreenWidth {
            var layerFrame = CGRect(x: contentOffsetX - contentScreenWidth,
                                    y: 0,
                                    width: zoomableLayer.frame.width,
                                    height: zoomableLayer.frame.height)
            if layerFrame.maxX > contentSizeWidth {
                layerFrame.origin.x = contentSizeWidth - layerFrame.size.width
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                zoomableLayer.frame = layerFrame
                CATransaction.commit()
            } else {
                CATransaction.begin()
                CATransaction.setDisableActions(true)
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
                zoomableLayer.frame = layerFrame
                CATransaction.commit()

            } else {
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                zoomableLayer.frame = layerFrame
                CATransaction.commit()
            }
        }
    }

    private func lessToGo() {
        guard let zLayer = zoomableLayer else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)

        let contentScreenWidth = scrollView.frame.size.width

        var loadMoreWidth = contentScreenWidth*screenTimes
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

        zLayer.startPoint = CGPoint(x: zLayer.startPoint.x + loadMoreWidth, y: zLayer.startPoint.y)
        var layerFrame = zLayer.frame
        layerFrame.origin.x = layerFrame.minX - loadMoreWidth
        zLayer.setNeedsDisplay(layerFrame)

        let scrollViewOffsetX = self.scrollView.contentOffset.x + loadMoreWidth
        print("ssss - \(scrollViewOffsetX)")
        self.scrollView.contentSize = CGSize(width: self.scrollView.contentSize.width + loadMoreWidth,
                                             height: self.scrollView.contentSize.height)
        self.scrollView.contentOffset = CGPoint(x: scrollViewOffsetX, y: self.scrollView.contentOffset.y)

        CATransaction.commit()
    }

    private func moreToGo() {
        guard let zLayer = zoomableLayer else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)

        let contentScreenWidth = scrollView.frame.size.width
        var loadMoreWidth = contentScreenWidth*screenTimes
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
        self.scrollView.contentSize = CGSize(width: self.scrollView.contentSize.width + loadMoreWidth,
                                             height: self.scrollView.contentSize.height)
        self.scrollView.contentOffset = CGPoint(x: scrollView.contentOffset.x, y: self.scrollView.contentOffset.y)

        CATransaction.commit()
    }
}

extension ZoomableRuler: ZoomableLayerDataSource {
    func layerRequesetCenterUnitValue(_ layer: ZoomableLayer) -> CGFloat {
        centerUintValue
    }
}
