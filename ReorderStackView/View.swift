//
//  MainView.swift
//  ReorderStackView
//
//  Created by Clay Ellis on 10/16/15.
//  Copyright © 2015 Clay Ellis. All rights reserved.
//

import UIKit
import APKit

class RView: UIView {
    
    // Data
    var num = 0
    var color = "000000"
    var height: CGFloat = 150
    
    // Subviews
    let label = UILabel()
    
    convenience init(num: Int, color: String, height: CGFloat) {
        self.init(frame: CGRectZero)
        self.num = num
        self.color = color
        self.height = height
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.setNeedsUpdateConstraints()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func configureSubviews() {
        // Add Subviews
        self.addSubview(self.label)
        
        // Style View
        self.backgroundColor = UIColor(hexString: self.color)
        
        // Style Subviews
        self.label.text = "\(self.num)"
        self.label.textColor = .black
        self.label.textAlignment = .Center
        
    }
    
    override func updateConstraints() {
        // Configure Subviews
        self.configureSubviews()
        
        // Add Constraints
        self.label.fillSuperview()
        
        super.updateConstraints()
    }
    
    override func intrinsicContentSize() -> CGSize {
        return CGSize(width: 10, height: self.height)
    }

}

class MainView: UIView {
    
    let rStackView = APRedorderableStackView()
    
    var rViews = [RView]()
    
    convenience init() {
        self.init(frame: CGRectZero)
        
        for index in 1 ... 4 {
            var color: String!
            var height: CGFloat!
            switch index {
            case 1: color = "385C69"; height = 100
            case 2: color = "5993A9"; height = 130
            case 3: color = "619FB6"; height = 50
            default: color = "81D6F5"; height = 70
            }
            self.rViews.append(RView(num: index, color: color, height: height))
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.setNeedsUpdateConstraints()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func configureSubviews() {
        // Add Subviews
        self.addSubview(self.rStackView)
        for rView in self.rViews {
            self.rStackView.addArrangedSubview(rView)
        }
        
        // Style View
        self.backgroundColor = .white
        
        // Style Subviews
        self.rStackView.axis = .Vertical
        self.rStackView.distribution = UIStackViewDistribution.FillProportionally
        self.rStackView.alignment = .Fill
        self.rStackView.clipsToBounds = false

        
    }
    
    override func updateConstraints() {
        // Configure Subviews
        self.configureSubviews()
        
        // Add Constraints
        self.rStackView.constrainUsing(constraints: [
            Constraint.llrr : (of: self, offset: 15),
            Constraint.ttbb : (of: self, offset: 40)])
        
        super.updateConstraints()
    }
}
