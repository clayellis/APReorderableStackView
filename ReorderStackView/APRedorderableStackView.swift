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
    override func addArrangedSubview(_ view: UIView) {
        super.addArrangedSubview(view)
        self.addLongPressGestureRecognizerForReorderingToView(view)
    }
    
    private func addLongPressGestureRecognizerForReorderingToView(_ view: UIView) {
        let longPressGR = UILongPressGestureRecognizer(target: self, action: #selector(APRedorderableStackView.handleLongPress(_:)))
        longPressGR.delegate = self
        longPressGR.minimumPressDuration = self.longPressMinimumPressDuration
        longPressGR.isEnabled = self.reorderingEnabled
        view.addGestureRecognizer(longPressGR)
        
        self.longPressGRS.append(longPressGR)
    }
    
    private func setReorderingEnabled(_ enabled: Bool) {
        for longPressGR in self.longPressGRS {
            longPressGR.isEnabled = enabled
        }
    }
    
    private func updateMinimumPressDuration() {
        for longPressGR in self.longPressGRS {
            longPressGR.minimumPressDuration = self.longPressMinimumPressDuration
        }
    }
    
    internal func handleLongPress(_ gr: UILongPressGestureRecognizer) {
        
        switch gr.state {
        case .began:
            
            self.reordering = true
            self.reorderDelegate?.didBeginReordering?()
            
            self.actualView = gr.view!
            self.originalPosition = gr.location(in: self)
            
            let axisAwareOriginalPosition = createAxisAwarePoint(originalPosition)
            axisAwareOriginalPosition.valueAlongAxis -= self.dragHintSpacing
            self.originalPosition = axisAwareOriginalPosition.point
            
            self.pointForReordering = self.originalPosition
            self.prepareForReordering()
            
        case .changed:
            dragTemporaryView(to: gr.location(in: self))
            swapViewsIfNeeded()
            
        case .ended, .cancelled, .failed:
            
            self.cleanupUpAfterReordering()
            self.reordering = false
            self.reorderDelegate?.didEndReordering?()
            
        default:
            break
        }
    }
    
    private func dragTemporaryView(to newLocation: CGPoint) {
        let xOffset = newLocation.x - originalPosition.x
        let yOffset = newLocation.y - originalPosition.y
        let translation = CGAffineTransform(translationX: xOffset, y: yOffset)
        let scale = replicateScalieInitiallyAppliedInPrepareForReordering()
        self.temporaryView.transform = scale.concatenating(translation)
        self.temporaryViewForShadow.transform = translation
    }
    
    private func replicateScalieInitiallyAppliedInPrepareForReordering() -> CGAffineTransform {
        return CGAffineTransform(scaleX: self.temporaryViewScale, y: self.temporaryViewScale)
    }
    
    private func swapViewsIfNeeded() {
        // Use the midY of the temporaryView to determine the dragging direction, location
        // maxY and minY are used in the delegate call didDragToReorder
        
        let axisAwareTemporaryViewFrame = createAxisAwareRect(temporaryView.frame)
        let alongAxisMax = axisAwareTemporaryViewFrame.maxAlongAxis
        let alongAxisMid = axisAwareTemporaryViewFrame.midAlongAxis
        let alongAxisMin = axisAwareTemporaryViewFrame.minAlongAxis
        let index = self.indexOfArrangedSubview(self.actualView)
        
        
        if alongAxisMid > createAxisAwarePoint(self.pointForReordering).valueAlongAxis {
            // Dragging the view down
            self.reorderDelegate?.didDragToReorder?(inUpDirection: false, maxY: alongAxisMax, minY: alongAxisMin)
            
            if let nextView = self.getNextViewInStack(usingIndex: index) {
                if alongAxisMid > createAxisAwareRect(nextView.frame).midAlongAxis {
                    swapActualView(with: nextView)
                }
            }
            
        } else {
            // Dragging the view up
            self.reorderDelegate?.didDragToReorder?(inUpDirection: true, maxY: alongAxisMax, minY: alongAxisMin)
            
            if let previousView = self.getPreviousViewInStack(usingIndex: index) {
                if alongAxisMid < createAxisAwareRect(previousView.frame).midAlongAxis {
                    swapActualView(with: previousView)
                }
            }
        }
    }
    
    private func createAxisAwareRect(_ rect: CGRect) -> AxisAwareRect {
        return AxisAwareRect(rect: rect, axis: axis)
    }
    
    private func createAxisAwarePoint(_ point: CGPoint) -> AxisAwarePoint {
        return AxisAwarePoint(point: point, axis: axis)
    }
    
    
    private func swapActualView(with otherView: UIView) {
        
        let newIndexOfActualView = indexOfArrangedSubview(otherView)
        let newIndexOfOtherView = indexOfArrangedSubview(self.actualView)
        
        UIView.animate(withDuration: 0.2, animations: {
            self.insertArrangedSubview(self.actualView, at: newIndexOfActualView)
            self.insertArrangedSubview(otherView, at: newIndexOfOtherView)
        })
        self.finalReorderFrame = self.actualView.frame
        self.pointForReordering = self.actualView.center
    }
    
    
    private func prepareForReordering() {
        
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
    
    private func cleanupUpAfterReordering() {
        
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
    
    private func styleViewsForReordering() {
        
        let roundKey = "Round"
        let round = createBasicAnimation(keyPath: "cornerRadius", fromValue: 0, toValue: self.cornerRadii, duration: 0.1)
        
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
        let shadowOpacity = createBasicAnimation(keyPath: "shadowOpacity", fromValue: 0, toValue: 0.2, duration: 0.2)
        
        let shadowOffsetKey = "ShadowOffset"
        let shadowOffset = createBasicAnimation(keyPath: "shadowOffset.height", fromValue: 0, toValue: 50, duration: 0.2)
        
        let shadowRadiusKey = "ShadowRadius"
        let shadowRadius = createBasicAnimation(keyPath: "shadowRadius", fromValue: 0, toValue: 20, duration: 0.2)
        
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
    
    private func createBasicAnimation(keyPath: String, fromValue: CGFloat, toValue: CGFloat, duration: CFTimeInterval) -> CABasicAnimation {
        let result = CABasicAnimation(keyPath: keyPath)
        result.fromValue = fromValue
        result.toValue = toValue
        result.duration = duration
        result.isRemovedOnCompletion = false
        result.fillMode = kCAFillModeForwards
        return result
    }
    
    private func styleViewsForEndReordering() {
        
        let squareKey = "Square"
        let square = createBasicAnimation(keyPath: "cornerRadius", fromValue: self.cornerRadii, toValue: 0, duration: 0.1)
        
        // Return drag view to original appearance
        self.temporaryView.transform = CGAffineTransform(scaleX: 1.0, y: 1.0)
        self.temporaryView.frame = self.finalReorderFrame
        self.temporaryView.alpha = 1.0
        self.temporaryView.layer.add(square, forKey: squareKey)
        
        // Shadow animations
        let shadowOpacityKey = "ShadowOpacity"
        let shadowOpacity = createBasicAnimation(keyPath: "shadowOpacity", fromValue: 0.2, toValue: 0, duration: 0.2)
        
        let shadowOffsetKey = "ShadowOffset"
        let shadowOffset = createBasicAnimation(keyPath: "shadowOffset.height", fromValue: 50, toValue: 0, duration: 0.2)
        
        let shadowRadiusKey = "ShadowRadius"
        let shadowRadius = createBasicAnimation(keyPath: "shadowRadius", fromValue: 20, toValue: 0, duration: 0.4)
        
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
    
    private func indexOfArrangedSubview(_ view: UIView) -> Int {
        for (index, subview) in self.arrangedSubviews.enumerated() {
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
    
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return !self.reordering
    }

}
