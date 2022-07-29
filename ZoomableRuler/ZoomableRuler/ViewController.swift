//
//  ViewController.swift
//  ZoomableRuler
//
//  Created by Jin on 2022/7/28.
//

import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        title = "Zoomable Ruler"
        view.backgroundColor = .white

        let zoomableRuler = ZoomableRuler(frame: CGRect(x: 0, y: 200, width: view.frame.size.width, height: 180))
        zoomableRuler.setCenterUnitValue(1653816942)
        view.addSubview(zoomableRuler)

        let line = UIView(frame: CGRect(x: zoomableRuler.frame.size.width/2 - 0.5,
                                        y: 0,
                                        width: 1,
                                        height: zoomableRuler.frame.size.height))
        line.backgroundColor = .white
        zoomableRuler.addSubview(line)
    }

}

