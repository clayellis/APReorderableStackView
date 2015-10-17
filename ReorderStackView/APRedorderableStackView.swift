//
//  APRedorderableStackView.swift
//  ReorderStackView
//
//  Created by Clay Ellis on 10/16/15.
//  Copyright © 2015 Appsidian. All rights reserved.
//

import UIKit

class APRedorderableStackView: UIStackView {
    
    // Views for reordering
    var temporaryView: UIView!
    var actualView: UIView!
    
    // Values for reordering
    var finalReorderFrame: CGRect!
    var originalPosition: CGPoint!
    
    // Constants
    let dragHintSpacing: CGFloat = 5
    
    override func addArrangedSubview(view: UIView) {
        super.addArrangedSubview(view)
        let longPressGR = UILongPressGestureRecognizer(target: self, action: "handleLongPress:")
        longPressGR.minimumPressDuration = 0.2
        view.addGestureRecognizer(longPressGR)
    }
    
    func handleLongPress(gr: UILongPressGestureRecognizer) {
        
        if gr.state == .Began {
            
            self.actualView = gr.view!
            self.originalPosition = gr.locationInView(self)
            self.originalPosition.y -= self.dragHintSpacing
            self.prepareForReordering()
            
        } else if gr.state == .Changed {
            
            // Drag the temporaryView
            let newLocation = gr.locationInView(self)
            let xOffset = newLocation.x - originalPosition.x
            let yOffset = newLocation.y - originalPosition.y
            let translation = CGAffineTransformMakeTranslation(xOffset, yOffset)
            // Replicate the scale that was initially applied in perpareForReordering:
            let scale = CGAffineTransformMakeScale(1.05, 1.05)
            self.temporaryView.transform = CGAffineTransformConcat(scale, translation)
            
            // Use the midY of the temporaryView to determine the dragging direction, location
            let midY = self.temporaryView.frame.midY
            let actualView = gr.view!
            let index = self.indexOfArrangedSubview(actualView)
            
            if midY > self.originalPosition.y {
                // Dragging the view down
                if let nextView = self.getNextViewInStack(usingIndex: index) {
                    if midY > nextView.frame.midY {
                        
                        // Swap the two arranged subviews
                        UIView.animateWithDuration(0.2, animations: {
                            self.insertArrangedSubview(nextView, atIndex: index)
                            self.insertArrangedSubview(actualView, atIndex: index + 1)
                        })
                        self.finalReorderFrame = actualView.frame
                        
                    }
                }
                
            } else {
                // Dragging the view up
                if let previousView = self.getPreviousViewInStack(usingIndex: index) {
                    if midY < previousView.frame.midY {
                        
                        // Swap the two arranged subviews
                        UIView.animateWithDuration(0.2, animations: {
                            self.insertArrangedSubview(previousView, atIndex: index)
                            self.insertArrangedSubview(actualView, atIndex: index - 1)
                        })
                        self.finalReorderFrame = actualView.frame
                        
                    }
                }
            }

        } else if gr.state == .Ended || gr.state == .Cancelled || gr.state == .Failed {
            
            self.cleanupUpAfterReordering()
            
        }
        
    }
    
    func prepareForReordering() {
        
        // Configure the temporary view
        self.temporaryView = actualView.snapshotViewAfterScreenUpdates(true)
        self.temporaryView.frame = actualView.frame
        self.finalReorderFrame = actualView.frame
        self.addSubview(self.temporaryView)
        
        // Hide the actual view and grow the temporaryView
        actualView.alpha = 0
        
        UIView.animateWithDuration(0.4, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0, options: [.AllowUserInteraction, .BeginFromCurrentState], animations: {

            self.styleViewsForReordering()
            
            }, completion: nil)
    }
    
    func cleanupUpAfterReordering() {
        UIView.animateWithDuration(0.4, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0, options: [.AllowUserInteraction, .BeginFromCurrentState], animations: {

            self.styleViewForEndReordering()

            }, completion: { (Bool) -> Void in
                // Hide the temporaryView, show the actualView
                self.temporaryView.removeFromSuperview()
                self.actualView.alpha = 1
        })
        
    }
    
    
    // MARK:- View Styling Methods
    // ---------------------------------------------------------------------------------------------
    
    func styleViewsForReordering() {
        
        // Grow, hint with offset, fade, round the temporaryView
        let scale = CGAffineTransformMakeScale(1.05, 1.05)
        let translation = CGAffineTransformMakeTranslation(0, self.dragHintSpacing)
        self.temporaryView.transform = CGAffineTransformConcat(scale, translation)
        self.temporaryView.alpha = 0.9
        self.temporaryView.layer.cornerRadius = 6
        self.temporaryView.clipsToBounds = true // Clips to bounds to apply corner radius
        
        // Scale down and round other arranged subviews
        for subview in self.arrangedSubviews {
            if subview != self.actualView {
                subview.layer.cornerRadius = 6
                subview.transform = CGAffineTransformMakeScale(0.97, 0.97)
            }
        }
    }
    
    func styleViewForEndReordering() {
        
        // Return drag view to original appearance
        self.temporaryView.transform = CGAffineTransformMakeScale(1.0, 1.0)
        self.temporaryView.frame = self.finalReorderFrame
        self.temporaryView.alpha = 1.0
        self.temporaryView.layer.cornerRadius = 0
        
        // Return other arranged subviews to original appearances
        for subview in self.arrangedSubviews {
            UIView.animateWithDuration(0.3, animations: {
                subview.layer.cornerRadius = 0
                subview.transform = CGAffineTransformMakeScale(1.0, 1.0)
            })
        }
    }
    
    
    // MARK:- Stack View Helper Methods
    // ---------------------------------------------------------------------------------------------
    
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
