
import UIKit

struct LineDrawCommand : DrawCommand {
    let current: Segment
    let previous: Segment?
    
    let width: CGFloat
    let color: UIColor

    // MARK: DrawCommand
    
    func execute(_ canvas: Canvas) {
        self.configure(canvas)

        if let previous = self.previous {
            self.drawQuadraticCurve(canvas)
        } else {
            self.drawLine(canvas)
        }
    }
    
    fileprivate func configure(_ canvas: Canvas) {
        canvas.context.setStrokeColor(self.color.cgColor)
        canvas.context.setLineWidth(self.width)
        canvas.context.setLineCap(CGLineCap.round)
    }
    
    fileprivate func drawLine(_ canvas: Canvas) {
        canvas.context.move(to: CGPoint(x: self.current.a.x, y: self.current.a.y))
        canvas.context.addLine(to: CGPoint(x: self.current.b.x, y: self.current.b.y))
        canvas.context.strokePath()
    }
    
    fileprivate func drawQuadraticCurve(_ canvas: Canvas) {
        if let previousMid = self.previous?.midPoint {
            let currentMid = self.current.midPoint
            
            canvas.context.move(to: CGPoint(x: previousMid.x, y: previousMid.y))
            
//            CGContextAddQuadCurveToPoint(canvas.context, current.a.x, current.a.y, currentMid.x, currentMid.y)
            let p = CGPoint(x: current.a.x, y: current.a.y)
            let p2 = CGPoint(x: currentMid.x, y: currentMid.y)
            
            canvas.context.addQuadCurve(to: p, control: p2)
            
            canvas.context.strokePath()
            
            
        }
    }
}
