//
//  APRedorderableStackView.swift
//  ReorderStackView
//
//  Created by Clay Ellis on 10/16/15.
//  Copyright © 2015 Appsidian. All rights reserved.
//

import UIKit

@objc
public protocol APStackViewReorderDelegate {
    /// didBeginReordering - called when reordering begins
    optional func didBeginReordering()
    
    /// Whenever a user drags a subview for a reordering, the delegate is told whether the direction
    /// was up or down, as well as what the max and min Y values are of the subview
    optional func didDragToReorder(inUpDirection up: Bool, maxY: CGFloat, minY: CGFloat)
    
    /// didReorder - called whenever a subview was reordered (returns the new index)
    
    /// didEndReordering - called when reordering ends
    optional func didEndReordering()
}

class APRedorderableStackView: UIStackView, UIGestureRecognizerDelegate {
    
    /// Setting `reorderdingEnabled` to `true` enables a drag to reorder behavior like `UITableView`
    var reorderingEnabled = false {
        didSet {
            self.setReorderingEnabled(self.reorderingEnabled)
        }
    }
    var reorderDelegate: APStackViewReorderDelegate?
    
    // Gesture recognizers
    private var longPressGRS = [UILongPressGestureRecognizer]()
    
    // Views for reordering
    private var temporaryView: UIView!
    private var temporaryViewForShadow: UIView!
    private var actualView: UIView!
    
    // Values for reordering
    private var reordering = false
    private var finalReorderFrame: CGRect!
    private var originalPosition: CGPoint!
    private var pointForReordering: CGPoint!
    
    // Appearance Constants
    var clipsToBoundsWhileReordering = false
    var cornerRadii: CGFloat = 5
    var temporaryViewScale: CGFloat = 1.05
    var otherViewsScale: CGFloat = 0.97
    var temporaryViewAlpha: CGFloat = 0.9
    /// The gap created once the long press drag is triggered
    var dragHintSpacing: CGFloat = 5
    var longPressMinimumPressDuration = 0.2 {
        didSet {
            self.updateMinimumPressDuration()
        }
    }
    
    // MARK:- Reordering Methods
    // ---------------------------------------------------------------------------------------------
    override func addArrangedSubview(view: UIView) {
        super.addArrangedSubview(view)
        self.addLongPressGestureRecognizerForReorderingToView(view)
    }
    
    private func addLongPressGestureRecognizerForReorderingToView(view: UIView) {
        let longPressGR = UILongPressGestureRecognizer(target: self, action: "handleLongPress:")
        longPressGR.delegate = self
        longPressGR.minimumPressDuration = self.longPressMinimumPressDuration
        longPressGR.enabled = self.reorderingEnabled
        view.addGestureRecognizer(longPressGR)
        
        self.longPressGRS.append(longPressGR)
    }
    
    private func setReorderingEnabled(enabled: Bool) {
        for longPressGR in self.longPressGRS {
            longPressGR.enabled = enabled
        }
    }
    
    private func updateMinimumPressDuration() {
        for longPressGR in self.longPressGRS {
            longPressGR.minimumPressDuration = self.longPressMinimumPressDuration
        }
    }
    
    internal func handleLongPress(gr: UILongPressGestureRecognizer) {
        
        if gr.state == .Began {
            
            self.reordering = true
            self.reorderDelegate?.didBeginReordering?()
            
            self.actualView = gr.view!
            self.originalPosition = gr.locationInView(self)
            self.originalPosition.y -= self.dragHintSpacing
            self.pointForReordering = self.originalPosition
            self.prepareForReordering()
            
        } else if gr.state == .Changed {
            
            // Drag the temporaryView
            let newLocation = gr.locationInView(self)
            let xOffset = newLocation.x - originalPosition.x
            let yOffset = newLocation.y - originalPosition.y
            let translation = CGAffineTransformMakeTranslation(xOffset, yOffset)
            // Replicate the scale that was initially applied in perpareForReordering:
            let scale = CGAffineTransformMakeScale(self.temporaryViewScale, self.temporaryViewScale)
            self.temporaryView.transform = CGAffineTransformConcat(scale, translation)
            self.temporaryViewForShadow.transform = translation
            
            // Use the midY of the temporaryView to determine the dragging direction, location
            // maxY and minY are used in the delegate call didDragToReorder
            let maxY = self.temporaryView.frame.maxY
            let midY = self.temporaryView.frame.midY
            let minY = self.temporaryView.frame.minY
            let index = self.indexOfArrangedSubview(self.actualView)
            
            if midY > self.pointForReordering.y {
                // Dragging the view down
                self.reorderDelegate?.didDragToReorder?(inUpDirection: false, maxY: maxY, minY: minY)
                
                if let nextView = self.getNextViewInStack(usingIndex: index) {
                    if midY > nextView.frame.midY {
                        
                        // Swap the two arranged subviews
                        UIView.animateWithDuration(0.2, animations: {
                            self.insertArrangedSubview(nextView, atIndex: index)
                            self.insertArrangedSubview(self.actualView, atIndex: index + 1)
                        })
                        self.finalReorderFrame = self.actualView.frame
                        self.pointForReordering.y = self.actualView.frame.midY
                    }
                }
                
            } else {
                // Dragging the view up
                self.reorderDelegate?.didDragToReorder?(inUpDirection: true, maxY: maxY, minY: minY)
                
                if let previousView = self.getPreviousViewInStack(usingIndex: index) {
                    if midY < previousView.frame.midY {
                        
                        // Swap the two arranged subviews
                        UIView.animateWithDuration(0.2, animations: {
                            self.insertArrangedSubview(previousView, atIndex: index)
                            self.insertArrangedSubview(self.actualView, atIndex: index - 1)
                        })
                        self.finalReorderFrame = self.actualView.frame
                        self.pointForReordering.y = self.actualView.frame.midY
                        
                    }
                }
            }
            
        } else if gr.state == .Ended || gr.state == .Cancelled || gr.state == .Failed {
            
            self.cleanupUpAfterReordering()
            self.reordering = false
            self.reorderDelegate?.didEndReordering?()
        }
        
    }
    
    private func prepareForReordering() {
        
        self.clipsToBounds = self.clipsToBoundsWhileReordering
        
        // Configure the temporary view
        self.temporaryView = self.actualView.snapshotViewAfterScreenUpdates(true)
        self.temporaryView.frame = self.actualView.frame
        self.finalReorderFrame = self.actualView.frame
        self.addSubview(self.temporaryView)
        
        // Hide the actual view and grow the temporaryView
        self.actualView.alpha = 0
        
        UIView.animateWithDuration(0.4, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0, options: [.AllowUserInteraction, .BeginFromCurrentState], animations: {
            
            self.styleViewsForReordering()
            
            }, completion: nil)
    }
    
    private func cleanupUpAfterReordering() {
        
        UIView.animateWithDuration(0.4, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0, options: [.AllowUserInteraction, .BeginFromCurrentState], animations: {
            
            self.styleViewsForEndReordering()
            
            }, completion: { (Bool) -> Void in
                // Hide the temporaryView, show the actualView
                self.temporaryViewForShadow.removeFromSuperview()
                self.temporaryView.removeFromSuperview()
                self.actualView.alpha = 1
                self.clipsToBounds = !self.clipsToBoundsWhileReordering
        })
        
    }
    
    
    // MARK:- View Styling Methods
    // ---------------------------------------------------------------------------------------------
    
    private func styleViewsForReordering() {
        
        let roundKey = "Round"
        let round = CABasicAnimation(keyPath: "cornerRadius")
        round.fromValue = 0
        round.toValue = self.cornerRadii
        round.duration = 0.1
        round.removedOnCompletion = false
        round.fillMode = kCAFillModeForwards
        
        // Grow, hint with offset, fade, round the temporaryView
        let scale = CGAffineTransformMakeScale(self.temporaryViewScale, self.temporaryViewScale)
        let translation = CGAffineTransformMakeTranslation(0, self.dragHintSpacing)
        self.temporaryView.transform = CGAffineTransformConcat(scale, translation)
        self.temporaryView.alpha = self.temporaryViewAlpha
        self.temporaryView.layer.addAnimation(round, forKey: roundKey)
        self.temporaryView.clipsToBounds = true // Clips to bounds to apply corner radius
        
        // Shadow
        self.temporaryViewForShadow = UIView(frame: self.temporaryView.frame)
        self.insertSubview(self.temporaryViewForShadow, belowSubview: self.temporaryView)
        self.temporaryViewForShadow.layer.shadowColor = UIColor.blackColor().CGColor
        self.temporaryViewForShadow.layer.shadowPath = UIBezierPath(roundedRect: self.temporaryView.bounds, cornerRadius: self.cornerRadii).CGPath
        
        // Shadow animations
        let shadowOpacityKey = "ShadowOpacity"
        let shadowOpacity = CABasicAnimation(keyPath: "shadowOpacity")
        shadowOpacity.fromValue = 0
        shadowOpacity.toValue = 0.2
        shadowOpacity.duration = 0.2
        shadowOpacity.removedOnCompletion = false
        shadowOpacity.fillMode = kCAFillModeForwards
        
        let shadowOffsetKey = "ShadowOffset"
        let shadowOffset = CABasicAnimation(keyPath: "shadowOffset.height")
        shadowOffset.fromValue = 0
        shadowOffset.toValue = 50
        shadowOffset.duration = 0.2
        shadowOffset.removedOnCompletion = false
        shadowOffset.fillMode = kCAFillModeForwards
        
        let shadowRadiusKey = "ShadowRadius"
        let shadowRadius = CABasicAnimation(keyPath: "shadowRadius")
        shadowRadius.fromValue = 0
        shadowRadius.toValue = 20
        shadowRadius.duration = 0.2
        shadowRadius.removedOnCompletion = false
        shadowRadius.fillMode = kCAFillModeForwards
        
        self.temporaryViewForShadow.layer.addAnimation(shadowOpacity, forKey: shadowOpacityKey)
        self.temporaryViewForShadow.layer.addAnimation(shadowOffset, forKey: shadowOffsetKey)
        self.temporaryViewForShadow.layer.addAnimation(shadowRadius, forKey: shadowRadiusKey)
        
        // Scale down and round other arranged subviews
        for subview in self.arrangedSubviews {
            if subview != self.actualView {
                subview.layer.addAnimation(round, forKey: roundKey)
                subview.transform = CGAffineTransformMakeScale(self.otherViewsScale, self.otherViewsScale)
            }
        }
    }
    
    private func styleViewsForEndReordering() {
        
        let squareKey = "Square"
        let square = CABasicAnimation(keyPath: "cornerRadius")
        square.fromValue = self.cornerRadii
        square.toValue = 0
        square.duration = 0.1
        square.removedOnCompletion = false
        square.fillMode = kCAFillModeForwards
        
        // Return drag view to original appearance
        self.temporaryView.transform = CGAffineTransformMakeScale(1.0, 1.0)
        self.temporaryView.frame = self.finalReorderFrame
        self.temporaryView.alpha = 1.0
        self.temporaryView.layer.addAnimation(square, forKey: squareKey)
        
        // Shadow animations
        let shadowOpacityKey = "ShadowOpacity"
        let shadowOpacity = CABasicAnimation(keyPath: "shadowOpacity")
        shadowOpacity.fromValue = 0.2
        shadowOpacity.toValue = 0
        shadowOpacity.duration = 0.2
        shadowOpacity.removedOnCompletion = false
        shadowOpacity.fillMode = kCAFillModeForwards
        
        let shadowOffsetKey = "ShadowOffset"
        let shadowOffset = CABasicAnimation(keyPath: "shadowOffset.height")
        shadowOffset.fromValue = 50
        shadowOffset.toValue = 0
        shadowOffset.duration = 0.2
        shadowOffset.removedOnCompletion = false
        shadowOffset.fillMode = kCAFillModeForwards
        
        let shadowRadiusKey = "ShadowRadius"
        let shadowRadius = CABasicAnimation(keyPath: "shadowRadius")
        shadowRadius.fromValue = 20
        shadowRadius.toValue = 0
        shadowRadius.duration = 0.4
        shadowRadius.removedOnCompletion = false
        shadowRadius.fillMode = kCAFillModeForwards
        
        self.temporaryViewForShadow.layer.addAnimation(shadowOpacity, forKey: shadowOpacityKey)
        self.temporaryViewForShadow.layer.addAnimation(shadowOffset, forKey: shadowOffsetKey)
        self.temporaryViewForShadow.layer.addAnimation(shadowRadius, forKey: shadowRadiusKey)
        
        // Return other arranged subviews to original appearances
        for subview in self.arrangedSubviews {
            UIView.animateWithDuration(0.3, animations: {
                subview.layer.addAnimation(square, forKey: squareKey)
                subview.transform = CGAffineTransformMakeScale(1.0, 1.0)
            })
        }
    }
    
    
    // MARK:- Stack View Helper Methods
    // ---------------------------------------------------------------------------------------------
    
    private func indexOfArrangedSubview(view: UIView) -> Int {
        for (index, subview) in self.arrangedSubviews.enumerate() {
            if view == subview {
                return index
            }
        }
        return 0
    }
    
    private func getPreviousViewInStack(usingIndex index: Int) -> UIView? {
        if index == 0 { return nil }
        return self.arrangedSubviews[index - 1]
    }
    
    private func getNextViewInStack(usingIndex index: Int) -> UIView? {
        if index == self.arrangedSubviews.count - 1 { return nil }
        return self.arrangedSubviews[index + 1]
    }
    
    override func gestureRecognizerShouldBegin(gestureRecognizer: UIGestureRecognizer) -> Bool {
        return !self.reordering
    }

}
