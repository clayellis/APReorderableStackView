//
//  ExampleViewController.swift
//  ReorderStackView
//
//  Created by Clay Ellis on 10/16/15.
//  Copyright © 2015 Clay Ellis. All rights reserved.
//

import UIKit

class ExampleViewController: UIViewController, APStackViewReorderDelegate {
    
    let exampleView = ExampleView()
    
    override func loadView() {
        self.view = self.exampleView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Attach the delegate
        self.exampleView.rStackView.reorderDelegate = self
    }
    
    // Delegate Methods
    func didBeginReordering() {
        print("Did begin reordering")
    }
    
    func didDragToReorder(inUpDirection up: Bool, maxY: CGFloat, minY: CGFloat) {
        print("Dragging: \(up ? "Up" : "Down")")
    }

    
    func didEndReordering() {
        print("Did end reordering")
    }

    func didReorder(from: Int, to: Int) {
        print("Did reorder subview from \(from) to \(to)")
    }
    
}
