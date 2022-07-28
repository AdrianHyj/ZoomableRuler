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
        view.addSubview(zoomableRuler)
    }

}

