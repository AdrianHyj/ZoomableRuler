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
        label.textColor = .white
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
        let centerUnitValue: Double = 1659585600.0
        zoomableRuler.setCenterUnitValue(centerUnitValue, maxUnitValue: 1659609351.0, minUnitValue: 1659561849.0)
//        zoomableRuler.setCenterUnitValue(centerUnitValue, maxUnitValue: 1659592800.0, minUnitValue: 1659578400.0)
//        zoomableRuler.setCenterUnitValue(centerUnitValue, maxUnitValue: 1659609351.0, minUnitValue: 1659578400.0)
//        zoomableRuler.setCenterUnitValue(centerUnitValue, maxUnitValue: 1659592800.0, minUnitValue: 1659561849.0)
//        zoomableRuler.setCenterUnitValue(centerUnitValue, maxUnitValue: centerUnitValue+160, minUnitValue: centerUnitValue-160)

//        let centerUnitValue: Double = 1660276800.0
//        zoomableRuler.setCenterUnitValue(centerUnitValue, maxUnitValue: 1660298767.0, minUnitValue: 1657620367.0)

        zoomableRuler.selectedAreas = [[.init(id: "1", startValue: 1659585600 - 25*15, endValue: 1659585600 - 24*15),
                                        .init(id: "2", startValue: 1659585600 - 15*10, endValue: 1659585600 - 15*9),
                                        .init(id: "3", startValue: 1659585600 - 15*6, endValue: 1659585600 - 15*4),
                                        .init(id: "4", startValue: 1659585600 - 5, endValue: 1659585600 + 10)],
                                       [.init(id: "5", startValue: 1659585600 - 15*30, endValue: 1659585600 - 15*19),
                                        .init(id: "6", startValue: 1659585600 - 15*15, endValue: 1659585600 - 15*14),
                                        .init(id: "7", startValue: 1659585600 - 15*12, endValue: 1659585600 - 15*11),
                                        .init(id: "8", startValue: 1659585600 - 15*9, endValue: 1659585600 - 15*6),
                                        .init(id: "9", startValue: 1659585600 - 15*2, endValue: 1659585600 - 15*1)],
                                       [.init(id: "10", startValue: 1659585600 + 15*1, endValue: 1659585600 + 15*2),
                                        .init(id: "11", startValue: 1659585600 + 15*15, endValue: 1659585600 + 15*30),
                                        .init(id: "12", startValue: 1659585600 + 15*139, endValue: 1659585600 + 15*140),
                                        .init(id: "13", startValue: 1659585600 + 15*150, endValue: 1659585600 + 15*170),
                                        .init(id: "14", startValue: 1659585600 + 15*200, endValue: 1659585600 + 15*300)],
                                       [.init(id: "15", startValue: 1659609351 - 15*30, endValue: 1659609351 - 15*19),
                                        .init(id: "16", startValue: 1659609351 - 15*15, endValue: 1659609351 - 15*14),
                                        .init(id: "17", startValue: 1659609351 - 15*12, endValue: 1659609351 - 15*11),
                                        .init(id: "18", startValue: 1659609351 - 15*9, endValue: 1659609351 - 15*6),
                                        .init(id: "19", startValue: 1659609351 - 5, endValue: 1659609351 + 10)]]

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
//        view.addSubview(scrollview)
//        self.scrollview = scrollview

        view.backgroundColor = .brown
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
    func rulerReachMinimumValue(_ ruler: ZoomableRuler) {
//        print("rulerReachMinimumValue")
    }

    func rulerReachMaximumValue(_ ruler: ZoomableRuler) {
//         print("rulerReachMaximumValue")
    }

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

    func ruler(_ ruler: ZoomableRuler, didTapAreaID areaID: String) {
        print("tap area: \(areaID)")
    }
}
