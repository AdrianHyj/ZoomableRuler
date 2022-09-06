//
//  ZoomableRulerUtil.swift
//  ZoomableRuler
//
//  Created by Jin on 2022/8/25.
//

import Foundation
import UIKit

class ZoomableRuler {
    struct SelectedArea {
        let id: String
        let startValue: Double
        let endValue: Double
        var icon: UIImage?
    }

    enum AreaAction {
        case tap
        case longPress
    }

    enum RangeState {
        case minimum
        case normal
        case maximum
    }
}
