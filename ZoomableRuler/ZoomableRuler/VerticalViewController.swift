//
//  VerticalViewController.swift
//  ZoomableRuler
//
//  Created by Jin on 2022/8/26.
//

import UIKit

class VerticalViewController: UIViewController {

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
    var ruler: ZoomableVerticalRuler?

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.

        let zoomableRuler = ZoomableVerticalRuler(frame: CGRect(x: 0,
                                                                y: 90,
                                                                width: view.frame.size.width,
                                                                height: view.frame.size.height - 90))
        zoomableRuler.delegate = self
        let centerUnitValue: Double = 1659585600.0
        zoomableRuler.setCenterUnitValue(centerUnitValue, maxUnitValue: 1659609351.0, minUnitValue: 1659561849.0)
//        zoomableRuler.setCenterUnitValue(centerUnitValue, maxUnitValue: 1659592800.0, minUnitValue: 1659578400.0)
//        zoomableRuler.setCenterUnitValue(centerUnitValue, maxUnitValue: 1659609351.0, minUnitValue: 1659578400.0)
//        zoomableRuler.setCenterUnitValue(centerUnitValue, maxUnitValue: 1659592800.0, minUnitValue: 1659561849.0)
//        zoomableRuler.setCenterUnitValue(centerUnitValue, maxUnitValue: centerUnitValue+160, minUnitValue: centerUnitValue-160)

//        let centerUnitValue: Double = 1660276800.0
//        zoomableRuler.setCenterUnitValue(centerUnitValue, maxUnitValue: 1660298767.0, minUnitValue: 1657620367.0)

        zoomableRuler.selectedAreas = [[.init(id: "1", startValue: 1659585600 - 25*15, endValue: 1659585600 - 24*15, icon: UIImage(named: "motion_timeline_icon")),
                                        .init(id: "2", startValue: 1659585600 - 15*10, endValue: 1659585600 - 15*9, icon: UIImage(named: "motion_timeline_icon")),
                                        .init(id: "3", startValue: 1659561849 - 15*6, endValue: 1659561849 - 15*4, icon: UIImage(named: "motion_timeline_icon")),
                                        .init(id: "4", startValue: 1659561849 - 5, endValue: 1659561849 + 10, icon: UIImage(named: "motion_timeline_icon"))],
                                       [.init(id: "5", startValue: 1659585600 - 15*30, endValue: 1659585600 - 15*19),
                                        .init(id: "6", startValue: 1659585600 - 15*15, endValue: 1659585600 - 15*14),
                                        .init(id: "7", startValue: 1659585600 - 15*12, endValue: 1659585600 - 15*11),
                                        .init(id: "8", startValue: 1659585600 - 15*9, endValue: 1659585600 - 15*6),
                                        .init(id: "9", startValue: 1659585600 - 15*2, endValue: 1659585600 - 15*1)],
                                       [.init(id: "10", startValue: 1659585600 + 15*1, endValue: 1659585600 + 15*2),
                                        .init(id: "11", startValue: 1659585600 + 15*15, endValue: 1659585600 + 15*30),
                                        .init(id: "12", startValue: 1659585600 + 15*139, endValue: 1659585600 + 15*140),
                                        .init(id: "13", startValue: 1659585600 + 15*150, endValue: 1659585600 + 15*170),
                                        .init(id: "14", startValue: 1659585600 + 15*200, endValue: 1659585600 + 15*300, icon: UIImage(named: "motion_timeline_icon"))],
                                       [.init(id: "15", startValue: 1659609351 - 15*30, endValue: 1659609351 - 15*19),
                                        .init(id: "16", startValue: 1659609351 - 15*15, endValue: 1659609351 - 15*14),
                                        .init(id: "17", startValue: 1659609351 - 15*12, endValue: 1659609351 - 15*11),
                                        .init(id: "18", startValue: 1659609351 - 15*9, endValue: 1659609351 - 15*6),
                                        .init(id: "19", startValue: 1659609351 + 15*2, endValue: 1659609351 + 15*10)]]

        view.addSubview(zoomableRuler)
        ruler = zoomableRuler

        let line = UIView(frame: CGRect(x: 0,
                                        y: zoomableRuler.frame.size.height/2 - 0.5,
                                        width: zoomableRuler.frame.size.width,
                                        height: 1))
        line.backgroundColor = .white
        zoomableRuler.addSubview(line)

        zoomableRuler.addSubview(centerTitleLabel)
        centerTitleLabel.frame = CGRect(x: 10, y: line.frame.minY - 25, width: 201, height: 20)
        centerTitleLabel.text = formatter.string(from: Date(timeIntervalSince1970: Double(centerUnitValue)))

        view.backgroundColor = .brown
    }
}

extension VerticalViewController: ZoomableVerticalRulerDelegate {
    func ruler(_ ruler: ZoomableVerticalRuler, reachMinimumValue unitValue: Double, offset: CGFloat) {
        print("VR - ZoomableVerticalRuler \(unitValue), offset:\(offset)")
    }

    func ruler(_ ruler: ZoomableVerticalRuler, reachMaximumValue unitValue: Double, offset: CGFloat) {
        print("VR - reachMaximumValue \(unitValue), offset:\(offset)")
    }

    func ruler(_ ruler: ZoomableVerticalRuler, areaID: String, withAction action: ZoomableRuler.AreaAction) {
        print("VR - areaID \(areaID), action:\(action)")
    }

    func ruler(_ ruler: ZoomableVerticalRuler, userDidMoveToValue unitValue: Double, range: ZoomableRuler.RangeState) {
        print("VR - userDidMoveToValue \(unitValue), ZoomableRuler.RangeState:\(range)")
    }

    func ruler(_ ruler: ZoomableVerticalRuler, requestColorWithArea area: ZoomableRuler.SelectedArea) -> UIColor {
        .green
    }

    func userDidDragRuler(_ ruler: ZoomableVerticalRuler) {
        //
    }

    func ruler(_ ruler: ZoomableVerticalRuler, currentCenterValue unitValue: Double) {
        print("aaa ---> \(unitValue)")
        centerTitleLabel.text = formatter.string(from: Date(timeIntervalSince1970: Double(unitValue)))
    }

    func ruler(_ ruler: ZoomableVerticalRuler, shouldShowMoreInfo block: @escaping (Bool) -> (), lessThan unitValue: Double) {
        print("request less value: \(unitValue)")
        DispatchQueue.main.async {
            block(true)
        }
    }

    func rulerReachMinimumValue(_ ruler: ZoomableVerticalRuler) {
        print("V rulerReachMinimumValue")
    }

    func ruler(_ ruler: ZoomableVerticalRuler, shouldShowMoreInfo block: @escaping (Bool) -> (), moreThan unitValue: Double) {
        print("request more value: \(unitValue)")
        DispatchQueue.main.async {
            block(true)
        }
    }

    func rulerReachMaximumValue(_ ruler: ZoomableVerticalRuler) {
        print("V rulerReachMaximumValue")
    }

    func ruler(_ ruler: ZoomableVerticalRuler, didTapAreaID areaID: String) {
        print("V tap area: \(areaID)")
    }

    func ruler(_ ruler: ZoomableVerticalRuler, userDidMoveToValue unitValue: Double) {
        print("V userDidMoveToValue: \(unitValue)")
    }
}

