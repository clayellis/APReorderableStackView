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
            setReorderingEnabled(reorderingEnabled)
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
            updateMinimumPressDuration()
        }
    }
    
    // MARK:- Reordering Methods
    // ---------------------------------------------------------------------------------------------
    override func addArrangedSubview(_ view: UIView) {
        super.addArrangedSubview(view)
        addLongPressGestureRecognizerForReorderingToView(view)
    }
    
    private func addLongPressGestureRecognizerForReorderingToView(_ view: UIView) {
        let longPressGR = UILongPressGestureRecognizer(target: self, action: #selector(APRedorderableStackView.handleLongPress(_:)))
        longPressGR.delegate = self
        longPressGR.minimumPressDuration = longPressMinimumPressDuration
        longPressGR.isEnabled = reorderingEnabled
        view.addGestureRecognizer(longPressGR)
        
        longPressGRS.append(longPressGR)
    }
    
    private func setReorderingEnabled(_ enabled: Bool) {
        for longPressGR in longPressGRS {
            longPressGR.isEnabled = enabled
        }
    }
    
    private func updateMinimumPressDuration() {
        for longPressGR in longPressGRS {
            longPressGR.minimumPressDuration = longPressMinimumPressDuration
        }
    }
    
    internal func handleLongPress(_ gr: UILongPressGestureRecognizer) {
        
        switch gr.state {
        case .began:
            
            reordering = true
            reorderDelegate?.didBeginReordering?()
            
            actualView = gr.view!
            originalPosition = gr.location(in: self)
            
            var axisAwareOriginalPosition = createAxisAwarePoint(originalPosition)
            axisAwareOriginalPosition.valueAlongAxis -= dragHintSpacing
            originalPosition = axisAwareOriginalPosition.point
            
            pointForReordering = originalPosition
            prepareForReordering()
            
        case .changed:
            dragTemporaryView(to: gr.location(in: self))
            swapViewsIfNeeded()
            
        case .ended, .cancelled, .failed:
            
            cleanupUpAfterReordering()
            reordering = false
            reorderDelegate?.didEndReordering?()
            
        default:
            break
        }
    }
    
    private func dragTemporaryView(to newLocation: CGPoint) {
        let translation = createTranslationForTemporaryView(at: newLocation)
        let scale = replicateScaleInitiallyAppliedInPrepareForReordering()
        temporaryView.transform = scale.concatenating(translation)
        temporaryViewForShadow.transform = translation
    }
    
    private func createTranslationForTemporaryView(at newLocation: CGPoint) -> CGAffineTransform {
        let xOffset = newLocation.x - originalPosition.x
        let yOffset = newLocation.y - originalPosition.y
        return CGAffineTransform(translationX: xOffset, y: yOffset)
    }
    
    private func replicateScaleInitiallyAppliedInPrepareForReordering() -> CGAffineTransform {
        return CGAffineTransform(scaleX: temporaryViewScale, y: temporaryViewScale)
    }
    
    private func swapViewsIfNeeded() {
        // Use the midY of the temporaryView to determine the dragging direction, location
        // maxY and minY are used in the delegate call didDragToReorder
        
        let axisAwareTemporaryViewFrame = createAxisAwareRect(temporaryView.frame)
        let alongAxisMax = axisAwareTemporaryViewFrame.maxAlongAxis
        let alongAxisMid = axisAwareTemporaryViewFrame.midAlongAxis
        let alongAxisMin = axisAwareTemporaryViewFrame.minAlongAxis
        let index = indexOfArrangedSubview(actualView)
        
        
        if alongAxisMid > createAxisAwarePoint(pointForReordering).valueAlongAxis {
            // Dragging the view down
            reorderDelegate?.didDragToReorder?(inUpDirection: false, maxY: alongAxisMax, minY: alongAxisMin)
            
            if let nextView = getNextViewInStack(usingIndex: index) {
                if alongAxisMid > createAxisAwareRect(nextView.frame).midAlongAxis {
                    swapActualView(with: nextView)
                }
            }
            
        } else {
            // Dragging the view up
            reorderDelegate?.didDragToReorder?(inUpDirection: true, maxY: alongAxisMax, minY: alongAxisMin)
            
            if let previousView = getPreviousViewInStack(usingIndex: index) {
                if alongAxisMid < createAxisAwareRect(previousView.frame).midAlongAxis {
                    swapActualView(with: previousView)
                }
            }
        }
    }
    
    
    private func swapActualView(with otherView: UIView) {
        
        let newIndexOfActualView = indexOfArrangedSubview(otherView)
        let newIndexOfOtherView = indexOfArrangedSubview(actualView)
        
        UIView.animate(withDuration: 0.2, animations: {
            self.insertArrangedSubview(self.actualView, at: newIndexOfActualView)
            self.insertArrangedSubview(otherView, at: newIndexOfOtherView)
        })
        finalReorderFrame = actualView.frame
        pointForReordering = actualView.center
    }
    
    
    private func prepareForReordering() {
        
        clipsToBounds = clipsToBoundsWhileReordering
        
        // Configure the temporary view
        temporaryView = actualView.snapshotView(afterScreenUpdates: true)
        temporaryView.frame = actualView.frame
        finalReorderFrame = actualView.frame
        addSubview(temporaryView)
        
        // Hide the actual view and grow the temporaryView
        actualView.alpha = 0
        
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
        let round = createBasicAnimation(keyPath: "cornerRadius", fromValue: 0, toValue: cornerRadii, duration: 0.1)
        
        // Grow, hint with offset, fade, round the temporaryView
        let scale = CGAffineTransform(scaleX: temporaryViewScale, y: temporaryViewScale)
        let translation = CGAffineTransform(translationX: 0, y: dragHintSpacing)
        temporaryView.transform = scale.concatenating(translation)
        temporaryView.alpha = temporaryViewAlpha
        temporaryView.layer.add(round, forKey: roundKey)
        temporaryView.clipsToBounds = true // Clips to bounds to apply corner radius
        
        // Shadow
        temporaryViewForShadow = UIView(frame: temporaryView.frame)
        insertSubview(temporaryViewForShadow, belowSubview: temporaryView)
        temporaryViewForShadow.layer.shadowColor = UIColor.black.cgColor
        temporaryViewForShadow.layer.shadowPath = UIBezierPath(roundedRect: temporaryView.bounds, cornerRadius: cornerRadii).cgPath
        
        // Shadow animations
        let shadowOpacityKey = "ShadowOpacity"
        let shadowOpacity = createBasicAnimation(keyPath: "shadowOpacity", fromValue: 0, toValue: 0.2, duration: 0.2)
        
        let shadowOffsetKey = "ShadowOffset"
        let shadowOffset = createBasicAnimation(keyPath: "shadowOffset.height", fromValue: 0, toValue: 50, duration: 0.2)
        
        let shadowRadiusKey = "ShadowRadius"
        let shadowRadius = createBasicAnimation(keyPath: "shadowRadius", fromValue: 0, toValue: 20, duration: 0.2)
        
        temporaryViewForShadow.layer.add(shadowOpacity, forKey: shadowOpacityKey)
        temporaryViewForShadow.layer.add(shadowOffset, forKey: shadowOffsetKey)
        temporaryViewForShadow.layer.add(shadowRadius, forKey: shadowRadiusKey)
        
        // Scale down and round other arranged subviews
        for subview in arrangedSubviews {
            if subview != actualView {
                subview.layer.add(round, forKey: roundKey)
                subview.transform = CGAffineTransform(scaleX: otherViewsScale, y: otherViewsScale)
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
        let square = createBasicAnimation(keyPath: "cornerRadius", fromValue: cornerRadii, toValue: 0, duration: 0.1)
        
        // Return drag view to original appearance
        temporaryView.transform = CGAffineTransform(scaleX: 1.0, y: 1.0)
        temporaryView.frame = finalReorderFrame
        temporaryView.alpha = 1.0
        temporaryView.layer.add(square, forKey: squareKey)
        
        // Shadow animations
        let shadowOpacityKey = "ShadowOpacity"
        let shadowOpacity = createBasicAnimation(keyPath: "shadowOpacity", fromValue: 0.2, toValue: 0, duration: 0.2)
        
        let shadowOffsetKey = "ShadowOffset"
        let shadowOffset = createBasicAnimation(keyPath: "shadowOffset.height", fromValue: 50, toValue: 0, duration: 0.2)
        
        let shadowRadiusKey = "ShadowRadius"
        let shadowRadius = createBasicAnimation(keyPath: "shadowRadius", fromValue: 20, toValue: 0, duration: 0.4)
        
        temporaryViewForShadow.layer.add(shadowOpacity, forKey: shadowOpacityKey)
        temporaryViewForShadow.layer.add(shadowOffset, forKey: shadowOffsetKey)
        temporaryViewForShadow.layer.add(shadowRadius, forKey: shadowRadiusKey)
        
        // Return other arranged subviews to original appearances
        for subview in arrangedSubviews {
            UIView.animate(withDuration: 0.3, animations: {
                subview.layer.add(square, forKey: squareKey)
                subview.transform = CGAffineTransform(scaleX: 1.0, y: 1.0)
            })
        }
    }
    
    
    // MARK:- Stack View Helper Methods
    // ---------------------------------------------------------------------------------------------
    
    private func indexOfArrangedSubview(_ view: UIView) -> Int {
        for (index, subview) in arrangedSubviews.enumerated() {
            if view == subview {
                return index
            }
        }
        return 0
    }
    
    private func getPreviousViewInStack(usingIndex index: Int) -> UIView? {
        if index == 0 { return nil }
        return arrangedSubviews[index - 1]
    }
    
    private func getNextViewInStack(usingIndex index: Int) -> UIView? {
        if index == arrangedSubviews.count - 1 { return nil }
        return arrangedSubviews[index + 1]
    }
    
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return !reordering
    }
    
    private func createAxisAwareRect(_ rect: CGRect) -> AxisAwareRect {
        return AxisAwareRect(rect: rect, axis: axis)
    }
    
    private func createAxisAwarePoint(_ point: CGPoint) -> AxisAwarePoint {
        return AxisAwarePoint(point: point, axis: axis)
    }

}
