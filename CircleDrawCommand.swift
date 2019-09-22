
import UIKit

struct CircleDrawCommand : DrawCommand {
    
    let center: CGPoint
    let radius: CGFloat
    let color: UIColor
    
    // MARK: DrawCommand
    
    func execute(_ canvas: Canvas) {
        canvas.context.setFillColor(self.color.cgColor)
        let p1 = CGPoint(x: self.center.x, y: self.center.y)
        canvas.context.addArc(center: p1, radius: self.radius, startAngle: 0, endAngle: 2 * CGFloat(M_PI), clockwise: true)
        (canvas.context).fillPath()
    }
}
