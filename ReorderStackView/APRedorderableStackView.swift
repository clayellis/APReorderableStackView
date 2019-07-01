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
    @objc optional func didBeginReordering()
    
    /// Whenever a user drags a subview for a reordering, the delegate is told whether the direction
    /// was up or down, as well as what the max and min Y values are of the subview
    @objc optional func didDragToReorder(inUpDirection up: Bool, maxY: CGFloat, minY: CGFloat)
    
    /// didReorder - called whenever a subview was reordered (returns the new index)
    
    /// didEndReordering - called when reordering ends
    @objc optional func didEndReordering()
}

public class APRedorderableStackView: UIStackView, UIGestureRecognizerDelegate {
    
    /// Setting `reorderdingEnabled` to `true` enables a drag to reorder behavior like `UITableView`
    public var reorderingEnabled = false {
        didSet {
            self.setReorderingEnabled(self.reorderingEnabled)
        }
    }
    public var reorderDelegate: APStackViewReorderDelegate?
    
    // Gesture recognizers
    fileprivate var longPressGRS = [UILongPressGestureRecognizer]()
    
    // Views for reordering
    fileprivate var temporaryView: UIView!
    fileprivate var temporaryViewForShadow: UIView!
    fileprivate var actualView: UIView!
    
    // Values for reordering
    fileprivate var reordering = false
    fileprivate var finalReorderFrame: CGRect!
    fileprivate var originalPosition: CGPoint!
    fileprivate var pointForReordering: CGPoint!
    
    // Appearance Constants
    public var clipsToBoundsWhileReordering = false
    public var cornerRadii: CGFloat = 5
    public var temporaryViewScale: CGFloat = 1.05
    public var otherViewsScale: CGFloat = 0.97
    public var temporaryViewAlpha: CGFloat = 0.9
    /// The gap created once the long press drag is triggered
    public var dragHintSpacing: CGFloat = 5
    public var longPressMinimumPressDuration = 0.2 {
        didSet {
            self.updateMinimumPressDuration()
        }
    }
    
    // MARK:- Reordering Methods
    // ---------------------------------------------------------------------------------------------
    override public func addArrangedSubview(_ view: UIView) {
        super.addArrangedSubview(view)
        self.addLongPressGestureRecognizerForReorderingToView(view)
    }
    
    fileprivate func addLongPressGestureRecognizerForReorderingToView(_ view: UIView) {
        let longPressGR = UILongPressGestureRecognizer(target: self, action: #selector(APRedorderableStackView.handleLongPress(_:)))
        longPressGR.delegate = self
        longPressGR.minimumPressDuration = self.longPressMinimumPressDuration
        longPressGR.isEnabled = self.reorderingEnabled
        view.addGestureRecognizer(longPressGR)
        
        self.longPressGRS.append(longPressGR)
    }
    
    fileprivate func setReorderingEnabled(_ enabled: Bool) {
        for longPressGR in self.longPressGRS {
            longPressGR.isEnabled = enabled
        }
    }
    
    fileprivate func updateMinimumPressDuration() {
        for longPressGR in self.longPressGRS {
            longPressGR.minimumPressDuration = self.longPressMinimumPressDuration
        }
    }
    
    @objc internal func handleLongPress(_ gr: UILongPressGestureRecognizer) {
        
        if gr.state == .began {
            
            self.reordering = true
            self.reorderDelegate?.didBeginReordering?()
            
            self.actualView = gr.view!
            self.originalPosition = gr.location(in: self)
            self.originalPosition.y -= self.dragHintSpacing
            self.pointForReordering = self.originalPosition
            self.prepareForReordering()
            
        } else if gr.state == .changed {
            
            // Drag the temporaryView
            let newLocation = gr.location(in: self)
            let xOffset = newLocation.x - originalPosition.x
            let yOffset = newLocation.y - originalPosition.y
            let translation = CGAffineTransform(translationX: xOffset, y: yOffset)
            // Replicate the scale that was initially applied in perpareForReordering:
            let scale = CGAffineTransform(scaleX: self.temporaryViewScale, y: self.temporaryViewScale)
            self.temporaryView.transform = scale.concatenating(translation)
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
                        UIView.animate(withDuration: 0.2, animations: {
                            self.insertArrangedSubview(nextView, at: index)
                            self.insertArrangedSubview(self.actualView, at: index + 1)
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
                        UIView.animate(withDuration: 0.2, animations: {
                            self.insertArrangedSubview(previousView, at: index)
                            self.insertArrangedSubview(self.actualView, at: index - 1)
                        })
                        self.finalReorderFrame = self.actualView.frame
                        self.pointForReordering.y = self.actualView.frame.midY
                        
                    }
                }
            }
            
        } else if gr.state == .ended || gr.state == .cancelled || gr.state == .failed {
            
            self.cleanupUpAfterReordering()
            self.reordering = false
            self.reorderDelegate?.didEndReordering?()
        }
        
    }
    
    fileprivate func prepareForReordering() {
        
        self.clipsToBounds = self.clipsToBoundsWhileReordering
        
        // Configure the temporary view
        self.temporaryView = self.actualView.snapshotView(afterScreenUpdates: true)
        self.temporaryView.frame = self.actualView.frame
        self.finalReorderFrame = self.actualView.frame
        self.addSubview(self.temporaryView)
        
        // Hide the actual view and grow the temporaryView
        self.actualView.alpha = 0
        
        UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0, options: [.allowUserInteraction, .beginFromCurrentState], animations: {
            
            self.styleViewsForReordering()
            
            }, completion: nil)
    }
    
    fileprivate func cleanupUpAfterReordering() {
        
        UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0, options: [.allowUserInteraction, .beginFromCurrentState], animations: {
            
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
    
    fileprivate func styleViewsForReordering() {
        
        let roundKey = "Round"
        let round = CABasicAnimation(keyPath: "cornerRadius")
        round.fromValue = 0
        round.toValue = self.cornerRadii
        round.duration = 0.1
        round.isRemovedOnCompletion = false
        round.fillMode = CAMediaTimingFillMode.forwards
        
        // Grow, hint with offset, fade, round the temporaryView
        let scale = CGAffineTransform(scaleX: self.temporaryViewScale, y: self.temporaryViewScale)
        let translation = CGAffineTransform(translationX: 0, y: self.dragHintSpacing)
        self.temporaryView.transform = scale.concatenating(translation)
        self.temporaryView.alpha = self.temporaryViewAlpha
        self.temporaryView.layer.add(round, forKey: roundKey)
        self.temporaryView.clipsToBounds = true // Clips to bounds to apply corner radius
        
        // Shadow
        self.temporaryViewForShadow = UIView(frame: self.temporaryView.frame)
        self.insertSubview(self.temporaryViewForShadow, belowSubview: self.temporaryView)
        self.temporaryViewForShadow.layer.shadowColor = UIColor.black.cgColor
        self.temporaryViewForShadow.layer.shadowPath = UIBezierPath(roundedRect: self.temporaryView.bounds, cornerRadius: self.cornerRadii).cgPath
        
        // Shadow animations
        let shadowOpacityKey = "ShadowOpacity"
        let shadowOpacity = CABasicAnimation(keyPath: "shadowOpacity")
        shadowOpacity.fromValue = 0
        shadowOpacity.toValue = 0.2
        shadowOpacity.duration = 0.2
        shadowOpacity.isRemovedOnCompletion = false
        shadowOpacity.fillMode = CAMediaTimingFillMode.forwards
        
        let shadowOffsetKey = "ShadowOffset"
        let shadowOffset = CABasicAnimation(keyPath: "shadowOffset.height")
        shadowOffset.fromValue = 0
        shadowOffset.toValue = 50
        shadowOffset.duration = 0.2
        shadowOffset.isRemovedOnCompletion = false
        shadowOffset.fillMode = CAMediaTimingFillMode.forwards
        
        let shadowRadiusKey = "ShadowRadius"
        let shadowRadius = CABasicAnimation(keyPath: "shadowRadius")
        shadowRadius.fromValue = 0
        shadowRadius.toValue = 20
        shadowRadius.duration = 0.2
        shadowRadius.isRemovedOnCompletion = false
        shadowRadius.fillMode = CAMediaTimingFillMode.forwards
        
        self.temporaryViewForShadow.layer.add(shadowOpacity, forKey: shadowOpacityKey)
        self.temporaryViewForShadow.layer.add(shadowOffset, forKey: shadowOffsetKey)
        self.temporaryViewForShadow.layer.add(shadowRadius, forKey: shadowRadiusKey)
        
        // Scale down and round other arranged subviews
        for subview in self.arrangedSubviews {
            if subview != self.actualView {
                subview.layer.add(round, forKey: roundKey)
                subview.transform = CGAffineTransform(scaleX: self.otherViewsScale, y: self.otherViewsScale)
            }
        }
    }
    
    fileprivate func styleViewsForEndReordering() {
        
        let squareKey = "Square"
        let square = CABasicAnimation(keyPath: "cornerRadius")
        square.fromValue = self.cornerRadii
        square.toValue = 0
        square.duration = 0.1
        square.isRemovedOnCompletion = false
        square.fillMode = CAMediaTimingFillMode.forwards
        
        // Return drag view to original appearance
        self.temporaryView.transform = CGAffineTransform(scaleX: 1.0, y: 1.0)
        self.temporaryView.frame = self.finalReorderFrame
        self.temporaryView.alpha = 1.0
        self.temporaryView.layer.add(square, forKey: squareKey)
        
        // Shadow animations
        let shadowOpacityKey = "ShadowOpacity"
        let shadowOpacity = CABasicAnimation(keyPath: "shadowOpacity")
        shadowOpacity.fromValue = 0.2
        shadowOpacity.toValue = 0
        shadowOpacity.duration = 0.2
        shadowOpacity.isRemovedOnCompletion = false
        shadowOpacity.fillMode = CAMediaTimingFillMode.forwards
        
        let shadowOffsetKey = "ShadowOffset"
        let shadowOffset = CABasicAnimation(keyPath: "shadowOffset.height")
        shadowOffset.fromValue = 50
        shadowOffset.toValue = 0
        shadowOffset.duration = 0.2
        shadowOffset.isRemovedOnCompletion = false
        shadowOffset.fillMode = CAMediaTimingFillMode.forwards
        
        let shadowRadiusKey = "ShadowRadius"
        let shadowRadius = CABasicAnimation(keyPath: "shadowRadius")
        shadowRadius.fromValue = 20
        shadowRadius.toValue = 0
        shadowRadius.duration = 0.4
        shadowRadius.isRemovedOnCompletion = false
        shadowRadius.fillMode = CAMediaTimingFillMode.forwards
        
        self.temporaryViewForShadow.layer.add(shadowOpacity, forKey: shadowOpacityKey)
        self.temporaryViewForShadow.layer.add(shadowOffset, forKey: shadowOffsetKey)
        self.temporaryViewForShadow.layer.add(shadowRadius, forKey: shadowRadiusKey)
        
        // Return other arranged subviews to original appearances
        for subview in self.arrangedSubviews {
            UIView.animate(withDuration: 0.3, animations: {
                subview.layer.add(square, forKey: squareKey)
                subview.transform = CGAffineTransform(scaleX: 1.0, y: 1.0)
            })
        }
    }
    
    
    // MARK:- Stack View Helper Methods
    // ---------------------------------------------------------------------------------------------
    
    fileprivate func indexOfArrangedSubview(_ view: UIView) -> Int {
        for (index, subview) in self.arrangedSubviews.enumerated() {
            if view == subview {
                return index
            }
        }
        return 0
    }
    
    fileprivate func getPreviousViewInStack(usingIndex index: Int) -> UIView? {
        if index == 0 { return nil }
        return self.arrangedSubviews[index - 1]
    }
    
    fileprivate func getNextViewInStack(usingIndex index: Int) -> UIView? {
        if index == self.arrangedSubviews.count - 1 { return nil }
        return self.arrangedSubviews[index + 1]
    }
    
    override public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return !self.reordering
    }

}
