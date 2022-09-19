//
//  UIColor+Extension.swift
//  NExT
//
//  Created by Casten on 2017/7/29.
//  Copyright © 2017年 Dinsafer. All rights reserved.
//

import UIKit

extension UIColor {
    
    convenience init(r : CGFloat, g : CGFloat, b : CGFloat, alpha : CGFloat = 1.0) {
        self.init(red: r / 255.0, green: g / 255.0, blue: b / 255.0, alpha: alpha)
    }
    
    convenience init(gray: CGFloat, alpha: CGFloat = 1.0) {
        self.init(r: gray, g: gray, b: gray, alpha: alpha)
    }
    
    convenience init?(hexString : String, alpha : CGFloat = 1.0) {
        var hex = hexString
        // Check for hash and remove the hash
        if hex.hasPrefix("#") {
            let index = hex.index(hex.startIndex, offsetBy: 1)
            hex = String(hex[index...])
        }
        
        guard let hexVal = Int(hex, radix: 16) else {
            self.init()
            return nil
        }
        
        if hex.count == 6 {
            self.init(red:   CGFloat( (hexVal & 0xFF0000) >> 16 ) / 255.0,
                      green: CGFloat( (hexVal & 0x00FF00) >> 8 ) / 255.0,
                      blue:  CGFloat( (hexVal & 0x0000FF) >> 0 ) / 255.0, alpha: alpha)
        } else {
            self.init()
            return nil
        }
    }
    
    var hex: String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        
        if a == 1 {
            return String(format: "%02x%02x%02x", Int(r * 255), Int(g * 255), Int(b * 255))
        } else {
            return String(format: "%02x%02x%02x%02x", Int(r * 255), Int(g * 255), Int(b * 255), Int(a * 255))
        }
    }
}
