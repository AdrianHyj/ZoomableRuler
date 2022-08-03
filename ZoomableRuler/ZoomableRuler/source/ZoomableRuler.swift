//
//  ZoomableRuler.swift
//  ZoomableRuler
//
//  Created by Jin on 2022/7/28.
//

import UIKit

protocol ZoomableRulerDelegate: NSObjectProtocol {
    func ruler(_ ruler: ZoomableRuler, currentCenterValue unitValue: Float)
    func ruler(_ ruler: ZoomableRuler, shouldShowMore: @escaping (Bool)->())
}
protocol ZoomableRulerDataSource: NSObjectProtocol {
}

class ZoomableRuler: UIControl {

    weak var delegate: ZoomableRulerDelegate?
    weak var dataSource: ZoomableRulerDataSource?
    var zoomableLayer: ZoomableLayer?

    var requesting = false

    private(set) var centerUintValue: CGFloat = 0
    private(set) var maxUnitValue: CGFloat = 0
    private(set) var curScrollViewOffsetX: CGFloat = 0
    private(set) var pixelPerUnit: CGFloat = 0

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
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setCenterUnitValue(_ value: Float, maxUnitValue: Float) {
        guard value < maxUnitValue else {
            return
        }
        self.centerUintValue = CGFloat(value)
        self.maxUnitValue = CGFloat(maxUnitValue)
        resetScrollView(withFrame: frame)
    }

    private func resetScrollView(withFrame frame: CGRect) {
        let leftValue = CGFloat(Int(centerUintValue/(24*3600))*24*3600)
        var rightValue: CGFloat = leftValue + 24*3600

        rightValue = rightValue > maxUnitValue ? maxUnitValue : rightValue

        scrollView.frame = CGRect(x: 0, y: 0, width: frame.size.width, height: frame.size.height)
        let scrollViewContentWidth = scrollView.frame.width*3
        pixelPerUnit = scrollViewContentWidth/(24*3600)
        let startPoint = CGPoint(x: (centerUintValue - leftValue)*pixelPerUnit, y: 0)
        let maxX = (rightValue - centerUintValue)*pixelPerUnit
        scrollView.contentSize = CGSize(width: scrollViewContentWidth, height: scrollView.frame.size.height)
        scrollView.contentInset = UIEdgeInsets(top: 0, left: scrollView.frame.width/2, bottom: 0, right: scrollView.frame.width/2)
        scrollView.contentOffset = CGPoint(x: startPoint.x - scrollView.frame.size.width/2, y: 0)
        curScrollViewOffsetX = scrollView.contentOffset.x
        // layer
        let zLayer = ZoomableLayer(withStartPoint: startPoint,
                                   centerUnitValue: centerUintValue,
                                   pixelPerUnit: pixelPerUnit,
                                   pixelPerLine: 40,
                                   maxUnitValue: maxUnitValue,
                                   dataSource: self)
        zLayer.frame = CGRect(x: 0,
                              y: 0,
                              width: scrollViewContentWidth,
                              height: scrollView.frame.size.height)
        scrollView.layer.addSublayer(zLayer)
        zoomableLayer = zLayer
    }
}

// MARK: - UIScrollViewDelegate
extension ZoomableRuler: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard let zoomableLayer = self.zoomableLayer else { return }

//        print("check: \(((scrollView.contentOffset.x + scrollView.frame.size.width/2)/(24*3600)))")
//        if Int.init(exactly: Float((scrollView.contentOffset.x + scrollView.frame.size.width/2)/(24*3600))) != nil {
//            print("load detail")
//        }
        print("eeee - > \(scrollView.contentOffset) ")
//        if scrollView.contentOffset.x < 0 {
//            if !requesting {
//                requesting = true
//                delegate?.ruler(self, shouldShowMore: { [weak self] should in
//                    self?.requesting = false
//                    if should, let self = self {
//                        CATransaction.begin()
//                        CATransaction.setDisableActions(true)
//                        let loadMoreWidth = self.scrollView.frame.size.width*3
//                        if let zLayer = self.zoomableLayer {
//                            zLayer.startPoint = CGPoint(x: zLayer.startPoint.x + loadMoreWidth, y: zLayer.startPoint.y)
//                            var layerFrame = zLayer.frame
//                            layerFrame.origin.x = layerFrame.minX + loadMoreWidth
//                            zLayer.setNeedsDisplay(layerFrame)
//                        }
//
//                        let scrollViewOffsetX = self.scrollView.contentOffset.x + loadMoreWidth
//                        self.curScrollViewOffsetX = scrollViewOffsetX
//                        self.scrollView.contentSize = CGSize(width: self.scrollView.contentSize.width + loadMoreWidth,
//                                                             height: self.scrollView.contentSize.height)
//                        self.scrollView.contentOffset = CGPoint(x: scrollViewOffsetX, y: self.scrollView.contentOffset.y)
//                        print("centerUintValue 111: \(scrollView.contentOffset.x), \(self.curScrollViewOffsetX) - \(self.centerUintValue)")
//                        CATransaction.commit()
//                    }
//                })
//            }
//            return
//        } else if scrollView.contentOffset.x > scrollView.contentSize.width - scrollView.frame.size.width/2 {
//            if !requesting {
//                requesting = true
//                delegate?.ruler(self, shouldShowMore: { [weak self] should in
//                    self?.requesting = false
//                    if should, let self = self {
//                        CATransaction.begin()
//                        CATransaction.setDisableActions(true)
//                        let loadMoreWidth = self.scrollView.frame.size.width*3
//                        if let zLayer = self.zoomableLayer {
//                            zLayer.startPoint = CGPoint(x: zLayer.startPoint.x - loadMoreWidth, y: zLayer.startPoint.y)
//                            var layerFrame = zLayer.frame
//                            layerFrame.origin.x = layerFrame.minX - loadMoreWidth
//                            zLayer.frame = layerFrame
//                        }
//
//                        let scrollViewOffsetX = self.scrollView.contentOffset.x - loadMoreWidth
//                        self.curScrollViewOffsetX = scrollViewOffsetX
//                        self.scrollView.contentSize = CGSize(width: self.scrollView.contentSize.width + loadMoreWidth,
//                                                             height: self.scrollView.contentSize.height)
//                        self.scrollView.contentOffset = CGPoint(x: scrollViewOffsetX, y: self.scrollView.contentOffset.y)
//                        print("centerUintValue 111: \(scrollView.contentOffset.x), \(self.curScrollViewOffsetX) - \(self.centerUintValue)")
//                        CATransaction.commit()
//                    }
//                })
//            }
//            return
//        }

        let xOffset = scrollView.contentOffset.x - curScrollViewOffsetX
        centerUintValue = centerUintValue + xOffset/pixelPerUnit
        print("centerUintValue: \(scrollView.contentOffset.x), \(curScrollViewOffsetX) - \(centerUintValue)")
        curScrollViewOffsetX = scrollView.contentOffset.x
        delegate?.ruler(self, currentCenterValue: Float(centerUintValue))
        if scrollView.contentOffset.x > zoomableLayer.frame.maxX - scrollView.frame.size.width {
            var layerFrame = CGRect(x: scrollView.contentOffset.x - scrollView.frame.size.width,
                                    y: 0,
                                    width: zoomableLayer.frame.width,
                                    height: zoomableLayer.frame.height)
            if layerFrame.maxX > scrollView.contentSize.width {
                layerFrame.origin.x = scrollView.contentSize.width - layerFrame.size.width
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
        } else if scrollView.contentOffset.x < zoomableLayer.frame.minX + scrollView.frame.size.width/2 {
            var layerFrame = CGRect(x: scrollView.contentOffset.x - scrollView.frame.size.width,
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
}

extension ZoomableRuler: ZoomableLayerDataSource {
    func layerRequesetCenterUnitValue(_ layer: ZoomableLayer) -> CGFloat {
        centerUintValue
    }
}
