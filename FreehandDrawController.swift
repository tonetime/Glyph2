//
//  FreehandDrawController.swift
//  FreehandDrawing-iOS
//
//  Created by Miguel Angel Quinones on 03/06/2015.
//  Copyright (c) 2015 badoo. All rights reserved.
//
import UIKit

protocol FreehandDrawGestureDeleagate: class  {
    func pan(_ sender: UIPanGestureRecognizer)
    func tap(_ sender: UITapGestureRecognizer)
}
class FreehandDrawController : NSObject,UIGestureRecognizerDelegate {
   // var color: UIColor = UIColor.blackColor()
    var color: UIColor = UIColor.white

    var width: CGFloat = 25.0
    weak var delegate:FreehandDrawGestureDeleagate?
    fileprivate var panCount=0
    fileprivate var tapCount=0
    fileprivate var debug=true
    
    required init(canvas: Canvas & DrawCommandReceiver,
                  gestureView: UIView) {
        self.canvas = canvas
        super.init()
        self.setupGestureRecognizersInView(gestureView)
    }
    func reset() {
        self.canvas.reset()
    }
    // MARK: API
    func undo() {
        if self.commandQueue.count > 0{
            self.commandQueue.removeLast()
            self.canvas.reset()
            self.canvas.executeCommands(self.commandQueue)
        }
    }
    

    
    // MARK: Gestures
    
    fileprivate func setupGestureRecognizersInView(_ view: UIView) {
        //self.view=view
        // Pan gesture recognizer to track lines
        let pan=UIPanGestureRecognizer(target: self, action: #selector(FreehandDrawController.handlePan(_:)))
        view.addGestureRecognizer(pan)
        // Tap gesture recognizer to track points
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(FreehandDrawController.handleTap(_:)))
        view.addGestureRecognizer(tapRecognizer)
    }
    @objc fileprivate func handlePan(_ sender: UIPanGestureRecognizer) {
        if debug==true {
            if panCount % 50 == 0 {
                print("Panning \(panCount)")
            }
            panCount+=1
        }
        delegate?.pan(sender)
        
        let point = sender.location(in: sender.view)
        switch sender.state {
        case .began:
            self.startAtPoint(point)
        case .changed:
            self.continueAtPoint(point, velocity: sender.velocity(in: sender.view))
        case .ended:
            self.endAtPoint(point)
        case .failed:
            self.endAtPoint(point)
        default:
            assert(false, "State not handled")
        }
    }
    @objc fileprivate func handleTap(_ sender: UITapGestureRecognizer) {
        if debug==true {
            if tapCount % 10 == 0 {
                print("Tapping \(tapCount)")
            }
            tapCount+=1
        }
        delegate?.tap(sender)
//        let point = sender.locationInView(sender.view)
//        if sender.state == .Ended {
//            self.tapAtPoint(point)
//        }
    }
    // MARK: Draw commands
    fileprivate func startAtPoint(_ point: CGPoint) {
        self.lastPoint = point
        self.lineStrokeCommand = ComposedCommand(commands: [])
    }
    fileprivate func continueAtPoint(_ point: CGPoint, velocity: CGPoint) {
       // let segmentWidth = modulatedWidth(self.width, velocity: velocity, previousVelocity: self.lastVelocity, previousWidth: self.lastWidth ?? self.width)
        let segmentWidth=self.width
        let segment = Segment(a: self.lastPoint, b: point, width: segmentWidth)
        
        let lineCommand = LineDrawCommand(current: segment, previous: lastSegment, width: segmentWidth, color: self.color)
        
        self.canvas.executeCommands([lineCommand])

        self.lineStrokeCommand?.addCommand(lineCommand)
        self.lastPoint = point
        self.lastSegment = segment
        self.lastVelocity = velocity
        self.lastWidth = segmentWidth
    }
    
    fileprivate func endAtPoint(_ point: CGPoint) {
        if let lineStrokeCommand = self.lineStrokeCommand {
            self.commandQueue.append(lineStrokeCommand)
        }
        
        self.lastPoint = CGPoint.zero
        self.lastSegment = nil
        self.lastVelocity = CGPoint.zero
        self.lastWidth = nil
        self.lineStrokeCommand = nil
    }
    fileprivate func tapAtPoint(_ point: CGPoint) {
        let circleCommand = CircleDrawCommand(center: point, radius: self.width/2.0, color: self.color)
        self.canvas.executeCommands([circleCommand])
        self.commandQueue.append(circleCommand)
    }
    fileprivate let canvas: Canvas & DrawCommandReceiver
    fileprivate var lineStrokeCommand: ComposedCommand?
    fileprivate var commandQueue: Array<DrawCommand> = []
    fileprivate var lastPoint: CGPoint = CGPoint.zero
    fileprivate var lastSegment: Segment?
    fileprivate var lastVelocity: CGPoint = CGPoint.zero
    fileprivate var lastWidth: CGFloat?
    fileprivate var view:UIView?
    fileprivate var panGesture:UIPanGestureRecognizer?
    fileprivate var tapGesture:UITapGestureRecognizer?
}
