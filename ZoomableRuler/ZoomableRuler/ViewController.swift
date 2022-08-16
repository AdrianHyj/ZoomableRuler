//
//  ViewController.swift
//  ZoomableRuler
//
//  Created by Jin on 2022/7/28.
//

import UIKit

class ViewController: UIViewController {

    lazy var centerTitleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 16.0)
        label.textAlignment = .center
        label.textColor = .black
        return label
    }()

    lazy var formatter: DateFormatter = {
        let fm = DateFormatter()
        fm.dateFormat = "YYYY-MM-dd HH:mm:ss"
        return fm
    }()

    var scrollview: UIScrollView?
    var ruler: ZoomableRuler?

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        title = "Zoomable Ruler"
        view.backgroundColor = .white

        let zoomableRuler = ZoomableRuler(frame: CGRect(x: 0, y: 200, width: view.frame.size.width, height: 180))
        zoomableRuler.delegate = self
        let centerUnitValue: Double = 1660640239.0
//        zoomableRuler.setCenterUnitValue(centerUnitValue, maxUnitValue: 1659609351.0, minUnitValue: 1659561849.0)
//        zoomableRuler.setCenterUnitValue(centerUnitValue, maxUnitValue: 1659592800.0, minUnitValue: 1659578400.0)
//        zoomableRuler.setCenterUnitValue(centerUnitValue, maxUnitValue: 1659609351.0, minUnitValue: 1659578400.0)
//        zoomableRuler.setCenterUnitValue(centerUnitValue, maxUnitValue: 1659592800.0, minUnitValue: 1659561849.0)
        zoomableRuler.setCenterUnitValue(centerUnitValue, maxUnitValue: nil, minUnitValue: 1660640239 - 3*60)

//        let centerUnitValue: Double = 1660276800.0
//        zoomableRuler.setCenterUnitValue(centerUnitValue, maxUnitValue: 1660298767.0, minUnitValue: 1657620367.0)
        view.addSubview(zoomableRuler)
        ruler = zoomableRuler

        let line = UIView(frame: CGRect(x: zoomableRuler.frame.size.width/2 - 0.5,
                                        y: 0,
                                        width: 1,
                                        height: zoomableRuler.frame.size.height))
        line.backgroundColor = .white
        zoomableRuler.addSubview(line)

        zoomableRuler.addSubview(centerTitleLabel)
        centerTitleLabel.frame = CGRect(x: line.frame.minX - 100, y: line.frame.minY - 25, width: 201, height: 20)
        centerTitleLabel.text = formatter.string(from: Date(timeIntervalSince1970: Double(centerUnitValue)))


        let scrollview = UIScrollView(frame: CGRect(x: 0, y: zoomableRuler.frame.maxY + 20, width: view.frame.size.width, height: 180))
        scrollview.delegate = self
        scrollview.backgroundColor = .lightGray
        scrollview.contentSize = CGSize(width: 2250.5, height: 180)
//        scrollview.contentInset = UIEdgeInsets(top: 0, left: 200, bottom: 0, right: scrollview.frame.size.width/2)
        view.addSubview(scrollview)
        self.scrollview = scrollview
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

//        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
//            self.ruler?.scrollView.contentOffset = CGPoint(x: 0, y: 0)
//            UIView.animate(withDuration: 15) {
//                self.ruler?.scrollView.contentOffset = CGPoint(x: (self.ruler?.scrollView.contentSize.width ?? 0) - (self.ruler?.scrollView.frame.size.width ?? 0), y: 0)
//            } completion: { _ in
//                //
//            }
//        }

    }

}

extension ViewController: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {


        let contentOffsetX = scrollView.contentOffset.x
        let contentSizeWidth = scrollView.contentSize.width
        let contentScreenWidth = scrollView.frame.size.width

        print("aaaaaaaaaaaaa1 - \(contentOffsetX) - \(contentSizeWidth) - \(contentScreenWidth) - \(scrollView.contentInset)")

    }
}

extension ViewController: ZoomableRulerDelegate {
    func ruler(_ ruler: ZoomableRuler, shouldShowMoreInfo block: @escaping (Bool) -> (), lessThan unitValue: Double) {
        DispatchQueue.main.async {
            block(true)
        }
    }

    func ruler(_ ruler: ZoomableRuler, shouldShowMoreInfo block: @escaping (Bool) -> (), moreThan unitValue: Double) {
        DispatchQueue.main.async {
            block(true)
        }
    }

    func ruler(_ ruler: ZoomableRuler, currentCenterValue unitValue: Double) {
        centerTitleLabel.text = formatter.string(from: Date(timeIntervalSince1970: Double(unitValue)))
    }
}
