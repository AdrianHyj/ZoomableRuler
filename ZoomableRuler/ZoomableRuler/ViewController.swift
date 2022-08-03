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

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        title = "Zoomable Ruler"
        view.backgroundColor = .white

        let zoomableRuler = ZoomableRuler(frame: CGRect(x: 0, y: 200, width: view.frame.size.width, height: 180))
        zoomableRuler.delegate = self
        zoomableRuler.dataSource = self
        zoomableRuler.setCenterUnitValue(1653816942.0, maxUnitValue: 1659423359.0)
        view.addSubview(zoomableRuler)

        let line = UIView(frame: CGRect(x: zoomableRuler.frame.size.width/2 - 0.5,
                                        y: 0,
                                        width: 1,
                                        height: zoomableRuler.frame.size.height))
        line.backgroundColor = .white
        zoomableRuler.addSubview(line)

        zoomableRuler.addSubview(centerTitleLabel)
        centerTitleLabel.frame = CGRect(x: line.frame.minX - 100, y: line.frame.minY - 25, width: 201, height: 20)
        centerTitleLabel.text = formatter.string(from: Date(timeIntervalSince1970: Double(1653816942.0)))
    }

}

extension ViewController: ZoomableRulerDelegate {
    func ruler(_ ruler: ZoomableRuler, currentCenterValue unitValue: Float) {
        centerTitleLabel.text = formatter.string(from: Date(timeIntervalSince1970: Double(unitValue)))
    }

    func ruler(_ ruler: ZoomableRuler, shouldShowMore: @escaping (Bool) -> ()) {
        DispatchQueue.main.async {
            shouldShowMore(true)
        }
    }
}

extension ViewController: ZoomableRulerDataSource {

}
