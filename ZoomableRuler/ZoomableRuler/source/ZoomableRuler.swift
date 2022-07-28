//
//  ZoomableRuler.swift
//  ZoomableRuler
//
//  Created by Jin on 2022/7/28.
//

import UIKit

class ZoomableRuler: UIControl {

    let zoomableLayer = ZoomableLayer()

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
        scrollView.layer.addSublayer(zoomableLayer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        scrollView.frame = bounds
        scrollView.contentSize = CGSize(width: 90 * scrollView.frame.width, height: scrollView.frame.size.height)
        zoomableLayer.frame = CGRect(x: -scrollView.frame.size.width,
                                     y: 0,
                                     width: scrollView.frame.size.width * 3,
                                     height: scrollView.frame.size.height)
    }
}

// MARK: - UIScrollViewDelegate
extension ZoomableRuler: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if scrollView.contentOffset.x > zoomableLayer.frame.maxX - scrollView.frame.size.width {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            zoomableLayer.frame = CGRect(x: scrollView.contentOffset.x - scrollView.frame.size.width,
                                         y: 0,
                                         width: scrollView.frame.size.width * 3,
                                         height: scrollView.frame.size.height)
            CATransaction.commit()
        } else if scrollView.contentOffset.x < zoomableLayer.frame.minX + scrollView.frame.size.width {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            zoomableLayer.frame = CGRect(x: scrollView.contentOffset.x - scrollView.frame.size.width*2,
                                         y: 0,
                                         width: scrollView.frame.size.width * 3,
                                         height: scrollView.frame.size.height)
            CATransaction.commit()
        }
    }
}
