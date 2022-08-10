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
    var startScale: CGFloat = 4
    /// 缩放时上一刻的比例
    var preScale: CGFloat = 4
    /// 用户piching的比例
    var pinchScale: CGFloat = 1.0

    /// 屏幕上每一个px对应的值范围
    let unitPerPixel: CGFloat = 25

    /// 显示在中央的数值
    private(set) var centerUintValue: CGFloat = 0
    /// Ruler最小的值
    private(set) var minUnitValue: CGFloat?
    /// Ruler最大的值
    private(set) var maxUnitValue: CGFloat?
    /// 每一个pixel对应的数值
    private(set) var pixelPerUnit: CGFloat = 1

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
            pinchScale = recoginer.scale
        }
        else if recoginer.state == .changed {
            // 缩放时更新layerFrame
            pinchScale = recoginer.scale / pinchScale
//            print("recoginer.scale: \(recoginer.scale)")
//            print("pinchScale: \(pinchScale)")
            if pinchScale * startScale > 4 {
                pinchScale = 4/startScale
            } else if pinchScale * startScale < 1 {
                pinchScale = 1/startScale
            }
            startScale = pinchScale * startScale
//            print("startScale: \(startScale)")
            setNeedsLayout()
        }
    }
//
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
                                   centerUnitValue: centerUintValue,
                                   pixelPerUnit: pixelPerUnit,
                                   pixelPerLine: 40,
                                   dataSource: self)
        zLayer.frame = CGRect(x: 0,
                              y: startPoint.y,
                              width: scrollViewContentWidth,
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

//        let (startPoint, scrollViewContentWidth) = startPointAndWidth(withCenterUintValue: centerUintValue)

//        scrollView.contentSize = CGSize(width: scrollViewContentWidth,
//                                        height: scrollView.frame.size.height)
//        scrollView.contentOffset = CGPoint(x: startPoint.x - scrollView.frame.size.width/2, y: 0)
//        pixelPerUnit = scrollViewContentWidth/screenUnitValue

//        let scrollViewContentWidth = scrollView.frame.width*screenTimes
        let scale = startScale/preScale
//        let scrollViewContentWidth = scrollView.contentSize.width*pinchScale
//        let startPoint = CGPoint(x: pinchScale*(zoomableLayer?.startPoint.x ?? 0), y: 0)

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        pixelPerUnit = scrollView.frame.size.width*screenTimes/screenUnitValue

//        let layerStartX = zLayer.startPoint.x * scale
        zLayer.update(withStartPoint: CGPoint(x: zLayer.startPoint.x * scale, y: 0),
                      pixelPerUnit: pixelPerUnit,
                      pixelPerLine: 40*startScale/2)

//        let layerX = (zLayer.frame.minX + (zLayer.frame.maxX - zLayer.frame.minX)/2)*pinchScale - zLayer.frame.size.width*pinchScale/2
//        if zLayer.frame.minX <= 0 {
//            layerX = 0
//        } else if zLayer.frame.maxX >= scrollView.contentSize.width {
//            layerX = scrollView.contentSize.width - scrollViewContentWidth
//        }
        zLayer.frame = CGRect(x: zLayer.frame.minX*scale,
                              y: zLayer.frame.origin.y,
                              width: zLayer.frame.size.width*scale,
                              height: zLayer.frame.size.height)

//        print("preScale - \(preScale)")

        let offset = scrollView.frame.size.width - scrollView.contentInset.left
        scrollView.contentOffset = CGPoint(x: (scrollView.contentOffset.x + offset)*scale - offset,
                                           y: 0)

        scrollView.contentSize = CGSize(width: scrollView.contentSize.width*scale,
                                        height: scrollView.contentSize.height)


        print("scale - \(scale)  -  \(zLayer.frame.size.width/zLayer.startPoint.x)")
        print("content changed - \(scrollView.contentSize) - \(scrollView.contentOffset) - \(String(describing: zoomableLayer?.frame)) - startPoint: \(zLayer.startPoint)")

        preScale = startScale

        CATransaction.commit()
    }

    /// 计算起始坐标
    private func startPointAndWidth(withCenterUintValue uintValue: CGFloat) -> (CGPoint, CGFloat){
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
        var scrollViewContentWidth = scrollView.frame.size.width*screenTimes

        pixelPerUnit = scrollViewContentWidth/screenUnitValue
        let maxX = (rightValue - uintValue)*pixelPerUnit
        let minX = (uintValue - leftValue)*pixelPerUnit
        // 是否一开始就小于默认滚动的范围, 如果是，则算出对应的Contentsize, 如果不是，则直接用默认的宽度(后续判断是否询问继续加载更多内容的时候需要)
        scrollViewContentWidth = (maxX + minX) < scrollViewContentWidth ? (maxX + minX) : scrollViewContentWidth

        return (CGPoint(x: (uintValue - leftValue)*pixelPerUnit, y: 0), scrollViewContentWidth)
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
        centerUintValue = zoomableLayer.centerUnitValue + (contentOffsetX + scrollView.contentInset.left - zoomableLayer.startPoint.x)/pixelPerUnit
        delegate?.ruler(self, currentCenterValue: Float(centerUintValue))
        print("11111 - \(contentOffsetX) - \(contentSizeWidth) - \(contentScreenWidth) - \(scrollView.contentInset.left) - start point: \(zoomableLayer.startPoint), frame: \(zoomableLayer.frame) - pixelPerUint: \(pixelPerUnit)")
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
        } else if contentOffsetX > contentSizeWidth - contentScreenWidth {
            guard hasMoreValue else { return }

            var loadMoreWidth = contentScreenWidth*screenTimes
            let oldStartPointX = zoomableLayer.startPoint.x
            if let maxValue = maxUnitValue {
                if (zoomableLayer.frame.maxX - oldStartPointX)/pixelPerUnit + zoomableLayer.centerUnitValue >= maxValue {
                    loadMoreWidth = 0
                } else {
                    // 最大值离当前开始点的距离
                    let maxXDistance = (maxValue - zoomableLayer.centerUnitValue)*pixelPerUnit - (zoomableLayer.frame.maxX - oldStartPointX)
                    loadMoreWidth = loadMoreWidth > maxXDistance ? maxXDistance : loadMoreWidth
                    if !requestingMore {
                        requestingMore = true
                        delegate?.ruler(self, shouldShowMoreInfo: { [weak self] should in
                            self?.requestingMore = false
                            if should {
                                print("moreToGo")
                                self?.moreToGo(withLoadMoreWidth: loadMoreWidth)
                            }
                        }, moreThan: centerUintValue + contentScreenWidth/2*pixelPerUnit)
                    }
                }
                return
            }
        }

        print("22222 - \(contentOffsetX) - \(contentSizeWidth) - \(contentScreenWidth) - \(scrollView.contentInset.left) - start point: \(zoomableLayer.startPoint), frame: \(zoomableLayer.frame) - pixelPerUint: \(pixelPerUnit)")
        if contentOffsetX > zoomableLayer.frame.maxX - contentScreenWidth*3/2 {
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
                print("333333 - \(contentOffsetX) - \(contentSizeWidth) - \(contentScreenWidth) - \(scrollView.contentInset.left) - start point: \(zoomableLayer.startPoint), frame: \(zoomableLayer.frame) - pixelPerUint: \(pixelPerUnit)")
            } else {
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                zoomableLayer.frame = layerFrame
                CATransaction.commit()
                print("55555 - \(contentOffsetX) - \(contentSizeWidth) - \(contentScreenWidth) - \(scrollView.contentInset.left) - start point: \(zoomableLayer.startPoint), frame: \(zoomableLayer.frame) - pixelPerUint: \(pixelPerUnit)")
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
            print("44444 - \(contentOffsetX) - \(contentSizeWidth) - \(contentScreenWidth) - \(scrollView.contentInset.left) - start point: \(zoomableLayer.startPoint), frame: \(zoomableLayer.frame) - pixelPerUint: \(pixelPerUnit)")
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
        layerFrame.origin.x = layerFrame.minX + loadMoreWidth
        zLayer.setNeedsDisplay(layerFrame)

        let scrollViewOffsetX = self.scrollView.contentOffset.x + loadMoreWidth
//        print("ssss - \(scrollViewOffsetX)")
        self.scrollView.contentSize = CGSize(width: self.scrollView.contentSize.width + loadMoreWidth,
                                             height: self.scrollView.contentSize.height)
        self.scrollView.contentOffset = CGPoint(x: scrollViewOffsetX, y: self.scrollView.contentOffset.y)

        print("7777 - \(scrollView.contentOffset.x) - \(scrollView.contentSize.width) - \(contentScreenWidth) - \(scrollView.contentInset.left) - start point: \(zoomableLayer?.startPoint), frame: \(zoomableLayer?.frame) - pixelPerUint: \(pixelPerUnit)")

        CATransaction.commit()
    }

    private func moreToGo(withLoadMoreWidth loadMoreWidth: CGFloat) {
        guard let zLayer = zoomableLayer else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)

//        let contentScreenWidth = scrollView.frame.size.width
//        var loadMoreWidth = contentScreenWidth*screenTimes
//        let oldStartPointX = zLayer.startPoint.x
//        if let maxValue = maxUnitValue {
//            if (zLayer.frame.maxX - oldStartPointX)/pixelPerUnit + zLayer.centerUnitValue >= maxValue {
//                loadMoreWidth = 0
//            } else {
//                // 最大值离当前开始点的距离
//                let maxXDistance = (maxValue - zLayer.centerUnitValue)*pixelPerUnit - (zLayer.frame.maxX - oldStartPointX)
//                loadMoreWidth = loadMoreWidth > maxXDistance ? maxXDistance : loadMoreWidth
//            }
//        }
        self.scrollView.contentSize = CGSize(width: self.scrollView.contentSize.width + loadMoreWidth,
                                             height: self.scrollView.contentSize.height)
        self.scrollView.contentOffset = CGPoint(x: scrollView.contentOffset.x, y: self.scrollView.contentOffset.y)

        print("888 - loadMoreWidth: \(loadMoreWidth) \(scrollView.contentOffset.x) - \(scrollView.contentSize.width) - \(scrollView.frame.size.width) - \(scrollView.contentInset.left) - start point: \(zoomableLayer?.startPoint), frame: \(zoomableLayer?.frame) - pixelPerUint: \(pixelPerUnit)")

        CATransaction.commit()
    }
}

extension ZoomableRuler: ZoomableLayerDataSource {
    func layerRequesetCenterUnitValue(_ layer: ZoomableLayer) -> CGFloat {
        centerUintValue
    }
}
