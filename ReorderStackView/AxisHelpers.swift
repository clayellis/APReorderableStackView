//
//  Axis.swift
//  ReorderStackView
//
//  Created by Oscar Fridh on 09/06/17.
//  Copyright © 2017 Clay Ellis. All rights reserved.
//

import UIKit

struct AxisAwarePoint {
    
    var point: CGPoint
    var axis: UILayoutConstraintAxis
    
    var valueAlongAxis: CGFloat {
        get {
            switch axis {
            case .horizontal: return point.x
            case .vertical: return point.y
            }
        } set {
            switch axis {
            case .horizontal: point.x = newValue
            case .vertical: point.y = newValue
            }
        }
    }
}

struct AxisAwareRect {
    
    var rect: CGRect
    var axis: UILayoutConstraintAxis
    
    var minAlongAxis: CGFloat {
        get {
            switch axis {
            case .horizontal: return rect.minX
            case .vertical: return rect.minY
            }
        }
    }
    
    var midAlongAxis: CGFloat {
        get {
            switch axis {
            case .horizontal: return rect.midX
            case .vertical: return rect.midY
            }
        }
    }
    
    var maxAlongAxis: CGFloat {
        get {
            switch axis {
            case .horizontal: return rect.maxX
            case .vertical: return rect.maxY
            }
        }
    }
}
