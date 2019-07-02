//
//  ExampleView.swift
//  ReorderStackView
//
//  Created by Clay Ellis on 10/16/15.
//  Copyright © 2015 Clay Ellis. All rights reserved.
//

import UIKit

class ExampleView: UIView {
    
    let rStackView = APRedorderableStackView()
    
    var rViews = [RView]()
    
    convenience init() {
        self.init(frame: CGRect.zero)
        
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
        self.rStackView.axis = .vertical
        self.rStackView.distribution = .fillProportionally
        self.rStackView.alignment = .fill
        self.rStackView.clipsToBounds = false
        
        // ----------------------------------------------------------------------------
        // Set reorderingEnabled to true to, well, enable reordering
        self.rStackView.reorderingEnabled = true
        // ----------------------------------------------------------------------------
        
    }
    
    override func updateConstraints() {
        // Configure Subviews
        self.configureSubviews()
        
        // Add Constraints
        self.rStackView.translatesAutoresizingMaskIntoConstraints = false
        let left    = NSLayoutConstraint(item: self.rStackView, attribute: .left, relatedBy: .equal, toItem: self, attribute: .left, multiplier: 1.0, constant: 15)
        let right   = NSLayoutConstraint(item: self.rStackView, attribute: .right, relatedBy: .equal, toItem: self, attribute: .right, multiplier: 1.0, constant: -15)
        let top     = NSLayoutConstraint(item: self.rStackView, attribute: .top, relatedBy: .equal, toItem: self, attribute: .top, multiplier: 1.0, constant: 40)
        let bottom  = NSLayoutConstraint(item: self.rStackView, attribute: .bottom, relatedBy: .equal, toItem: self, attribute: .bottom, multiplier: 1.0, constant: -40)
        
        self.addConstraint(left)
        self.addConstraint(right)
        self.addConstraint(top)
        self.addConstraint(bottom)

        super.updateConstraints()
    }
}

class RView: UIView {
    
    // Data
    var num = 0
    var color = "000000"
    var height: CGFloat = 150
    
    // Subviews
    let label = UILabel()
    
    convenience init(num: Int, color: String, height: CGFloat) {
        self.init(frame: CGRect.zero)
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
        self.label.textAlignment = .center
        
    }
    
    override func updateConstraints() {
        // Configure Subviews
        self.configureSubviews()
        
        // Add Constraints
        self.label.translatesAutoresizingMaskIntoConstraints = false
        let left    = NSLayoutConstraint(item: self.label, attribute: .left, relatedBy: .equal, toItem: self, attribute: .left, multiplier: 1.0, constant: 0)
        let right   = NSLayoutConstraint(item: self.label, attribute: .right, relatedBy: .equal, toItem: self, attribute: .right, multiplier: 1.0, constant: 0)
        let top     = NSLayoutConstraint(item: self.label, attribute: .top, relatedBy: .equal, toItem: self, attribute: .top, multiplier: 1.0, constant: 0)
        let bottom  = NSLayoutConstraint(item: self.label, attribute: .bottom, relatedBy: .equal, toItem: self, attribute: .bottom, multiplier: 1.0, constant: 0)
        
        self.addConstraint(left)
        self.addConstraint(right)
        self.addConstraint(top)
        self.addConstraint(bottom)
        
        super.updateConstraints()
    }
    
    override var intrinsicContentSize : CGSize {
        return CGSize(width: 10, height: self.height)
    }
    
}
