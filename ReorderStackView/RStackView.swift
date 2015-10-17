//
//  RStackView.swift
//  ReorderStackView
//
//  Created by Clay Ellis on 10/16/15.
//  Copyright © 2015 Clay Ellis. All rights reserved.
//

import UIKit

class RStackView: UIStackView {
    
    var dragView: UIView!
    var actualView: UIView!
    var originalPosition: CGPoint!
    var originalFrame: CGRect!
    var spacingAmount: CGFloat = 10
    
    override func addArrangedSubview(view: UIView) {
        super.addArrangedSubview(view)
        let longPressGR = UILongPressGestureRecognizer(target: self, action: "handleLongPress:")
        longPressGR.minimumPressDuration = 0.2
        view.addGestureRecognizer(longPressGR)
    }
    
    func handleLongPress(gr: UILongPressGestureRecognizer) {
        
        if gr.state == .Began {
            
            self.actualView = gr.view!
            let index = self.indexOfArrangedSubview(self.actualView)
            
            self.prepareForReordering(withGestureRecognizer: gr)
            
            self.originalPosition = gr.locationInView(self)
            self.originalPosition.y -= 5// -= self.spacingAmount * CGFloat(index)
            
        } else if gr.state == .Changed {
            
            let newLocation = gr.locationInView(self)
            let xOffset = newLocation.x - originalPosition.x
            let yOffset = newLocation.y - originalPosition.y
            let translation = CGAffineTransformMakeTranslation(xOffset, yOffset)
            let scale = CGAffineTransformMakeScale(1.05, 1.05)
            self.dragView.transform = CGAffineTransformConcat(scale, translation)
            
            let midY = self.dragView.frame.midY
            let actualView = gr.view!
            let index = self.indexOfArrangedSubview(actualView)
            
            if midY > self.originalPosition.y {
                // Dragging the view down
                if let nextView = self.getNextViewInStack(usingIndex: index) {
                    if midY > nextView.frame.midY {
                        print("New index = \(index + 1)")
                        
//                        // Swap the two arranged subviews
//                        let adjustedFrame = CGRect(
//                            x: nextView.frame.origin.x,
//                            y: nextView.frame.origin.y,// - self.spacingAmount * CGFloat(index + 1),
//                            width: actualView.frame.width,
//                            height: actualView.frame.height)
//                        
//                        self.originalFrame = adjustedFrame
                        UIView.animateWithDuration(0.2, animations: {
                            self.insertArrangedSubview(nextView, atIndex: index)
                            self.insertArrangedSubview(actualView, atIndex: index + 1)
                        })
                        
//                        // Swap the two arranged subviews
//                        let adjustedFrame = CGRect(
//                            x: actualView.frame.origin.x,
//                            y: actualView.frame.origin.y,// - self.spacingAmount * CGFloat(index + 1),
//                            width: actualView.frame.width,
//                            height: actualView.frame.height)
                        
                        self.originalFrame = actualView.frame
                        
                    }
                }
                
            } else {
                // Dragging the view up
                if let previousView = self.getPreviousViewInStack(usingIndex: index) {
                    if midY < previousView.frame.midY {
                        print("New index = \(index - 1)")
                        
//                        // Swap the two arranged subviews
//                        let adjustedFrame = CGRect(
//                            x: previousView.frame.origin.x,
//                            y: previousView.frame.origin.y,// - self.spacingAmount * CGFloat(index - 1),
//                            width: previousView.frame.width,
//                            height: previousView.frame.height)
//                        self.originalFrame = adjustedFrame
                        UIView.animateWithDuration(0.2, animations: {
                            self.insertArrangedSubview(previousView, atIndex: index)
                            self.insertArrangedSubview(actualView, atIndex: index - 1)
                        })
                        self.originalFrame = actualView.frame
                    }
                }
                
            }


        } else if gr.state == .Ended || gr.state == .Cancelled || gr.state == .Failed {
            
            self.cleanupUpAfterReordering(withGestureRecognizer: gr)
            
        }
        
    }
    
    func prepareForReordering(withGestureRecognizer gr: UILongPressGestureRecognizer) {
//        let actualView = gr.view!
        let index = self.indexOfArrangedSubview(self.actualView)
        
        // Configure the temporary dragging view
        self.dragView = actualView.snapshotViewAfterScreenUpdates(true)
        self.dragView.frame = actualView.frame
        self.originalFrame = actualView.frame
        self.addSubview(self.dragView)
        
        // Hide the actual view and grow the dragView
        actualView.alpha = 0
        
        UIView.animateWithDuration(0.4, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0, options: [.AllowUserInteraction, .BeginFromCurrentState], animations: {
            
            // Increase spacing and grow dragView
//            self.spacing = self.spacingAmount
            let scale = CGAffineTransformMakeScale(1.05, 1.05)
            let translation = CGAffineTransformMakeTranslation(0, 5)// self.spacingAmount * CGFloat(index))
            self.roundCorners()
            self.dragView.transform = CGAffineTransformConcat(scale, translation)
            self.dragView.alpha = 0.9
            
            }, completion: nil)
    }
    
    func cleanupUpAfterReordering(withGestureRecognizer gr: UILongPressGestureRecognizer) {
        UIView.animateWithDuration(0.4, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0, options: [.AllowUserInteraction, .BeginFromCurrentState], animations: {
            
            // Reset spacing and shrink dragView
            self.spacing = 0
//            let scale = CGAffineTransformMakeScale(1.0, 1.0)
//            let translation = CGAffineTransformMakeTranslation(0, 0)
//            self.dragView.transform = CGAffineTransformConcat(scale, translation)
            self.dragView.transform = CGAffineTransformMakeScale(1.0, 1.0)
            self.dragView.frame = self.originalFrame
            self.dragView.alpha = 1.0

            self.squareCorners()

            }, completion: { (Bool) -> Void in
                
                // Bring back the actual view
                let actualView = gr.view!
                actualView.alpha = 1
                
                // Remove the dragView to reveal actualView
                self.dragView.removeFromSuperview()
        })
        
    }
    
    func roundCorners() {
        for subview in self.arrangedSubviews {
            UIView.animateWithDuration(0.3, animations: {
                if subview != self.actualView {
                    subview.layer.cornerRadius = 6
                    subview.transform = CGAffineTransformMakeScale(0.97, 0.97)
                }
            })
            self.dragView.layer.cornerRadius = 6
            self.dragView.clipsToBounds = true
        }
    }
    
    func squareCorners() {
        for subview in self.arrangedSubviews {
            UIView.animateWithDuration(0.3, animations: {
                subview.layer.cornerRadius = 0
                subview.transform = CGAffineTransformMakeScale(1.0, 1.0)
            })
            self.dragView.layer.cornerRadius = 0
        }
    }
    
    func indexOfArrangedSubview(view: UIView) -> Int {
        for (index, subview) in self.arrangedSubviews.enumerate() {
            if view == subview {
                return index
            }
        }
        return 0
    }
    
    func getPreviousViewInStack(usingIndex index: Int) -> UIView? {
        if index == 0 { return nil }
        return self.arrangedSubviews[index - 1]
    }
    
    func getNextViewInStack(usingIndex index: Int) -> UIView? {
        if index == self.arrangedSubviews.count - 1 { return nil }
        return self.arrangedSubviews[index + 1]
    }

    
}
