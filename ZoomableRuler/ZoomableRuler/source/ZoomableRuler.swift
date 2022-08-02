//
//  ZoomableRuler.swift
//  ZoomableRuler
//
//  Created by Jin on 2022/7/28.
//

import UIKit

class ZoomableRuler: UIControl {

    var zoomableLayer: ZoomableLayer?

    private(set) var centerUintValue: CGFloat = 0
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

    func setCenterUnitValue(_ value: CGFloat) {
        centerUintValue = value
        resetScrollView(withFrame: frame)
    }

    private func resetScrollView(withFrame frame: CGRect) {
        scrollView.frame = CGRect(x: 0, y: 0, width: frame.size.width, height: frame.size.height)
        let scrollViewContentWidth = scrollView.frame.width * 3
        scrollView.contentSize = CGSize(width: scrollViewContentWidth*3, height: scrollView.frame.size.height)
        scrollView.contentOffset = CGPoint(x: (scrollView.contentSize.width - scrollView.frame.size.width)/2, y: 0)
        curScrollViewOffsetX = scrollView.contentOffset.x
        // layer
        pixelPerUnit = scrollView.frame.size.width/(8*3600)
        let zLayer = ZoomableLayer(withStartPoint: CGPoint(x: (scrollView.contentSize.width - scrollViewContentWidth)/2, y: 0),
                                   centerUnitValue: centerUintValue,
                                   pixelPerUnit: pixelPerUnit,
                                   pixelPerLine: 40,
                                   dataSource: self)
        zLayer.frame = CGRect(x: (scrollView.contentSize.width - scrollViewContentWidth)/2,
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

        let xOffset = scrollView.contentOffset.x - curScrollViewOffsetX
        centerUintValue = centerUintValue + xOffset/pixelPerUnit
//        print("centerUintValue: \(centerUintValue)")
        curScrollViewOffsetX = scrollView.contentOffset.x
        if scrollView.contentOffset.x > zoomableLayer.frame.maxX - scrollView.frame.size.width {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            zoomableLayer.frame = CGRect(x: scrollView.contentOffset.x - scrollView.frame.size.width,
                                         y: 0,
                                         width: zoomableLayer.frame.width,
                                         height: zoomableLayer.frame.height)
            CATransaction.commit()
        } else if scrollView.contentOffset.x < zoomableLayer.frame.minX + scrollView.frame.size.width/2 {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            zoomableLayer.frame = CGRect(x: scrollView.contentOffset.x - scrollView.frame.size.width,
                                         y: 0,
                                         width: zoomableLayer.frame.width,
                                         height: zoomableLayer.frame.height)
            CATransaction.commit()
        }
    }
}

extension ZoomableRuler: ZoomableLayerDataSource {
    func layerRequesetCenterUnitValue(_ layer: ZoomableLayer) -> CGFloat {
        centerUintValue
    }
}
