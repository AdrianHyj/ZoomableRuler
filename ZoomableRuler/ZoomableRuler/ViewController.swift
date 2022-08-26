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

        let vBtn = UIButton(frame: CGRect(x: 50, y: 100, width: (view.frame.size.width - 100 - 50)/2, height: 80))
        vBtn.setTitle("Vertical", for: .normal)
        vBtn.setTitleColor(.white, for: .normal)
        vBtn.addTarget(self, action: #selector(didTapVertical), for: .touchUpInside)

        let hBtn = UIButton(frame: CGRect(x: vBtn.frame.maxX + 50, y: 100, width: (view.frame.size.width - 100 - 50)/2, height: 80))
        hBtn.setTitle("horizontal", for: .normal)
        hBtn.setTitleColor(.white, for: .normal)
        hBtn.addTarget(self, action: #selector(didTapHorizontal), for: .touchUpInside)

        view.addSubview(vBtn)
        view.addSubview(hBtn)

//        let scrollview = UIScrollView(frame: CGRect(x: 0, y: zoomableRuler.frame.maxY + 20, width: view.frame.size.width, height: 180))
//        scrollview.delegate = self
//        scrollview.backgroundColor = .lightGray
//        scrollview.contentSize = CGSize(width: view.frame.size.width, height: 2250.5)
//        scrollview.contentInset = UIEdgeInsets(top: 0, left: 200, bottom: 0, right: scrollview.frame.size.width/2)
//        view.addSubview(scrollview)
//        self.scrollview = scrollview

        view.backgroundColor = .brown
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }

    @objc func didTapVertical() {
        navigationController?.pushViewController(VerticalViewController(), animated: true)
    }

    @objc func didTapHorizontal() {
        navigationController?.pushViewController(HorizontalViewController(), animated: true)
    }
}

extension ViewController: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let contentOffsetY = scrollView.contentOffset.y
        let contentSizeHeight = scrollView.contentSize.height
        let contentScreenHeight = scrollView.frame.size.height

        print("aaaaaaaaaaaaa1 - \(contentOffsetY) - \(contentSizeHeight) - \(contentScreenHeight) - \(scrollView.contentInset)")
    }
}

