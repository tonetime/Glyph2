

import UIKit

struct Segment {
    let a: CGPoint
    let b: CGPoint
    let width: CGFloat
    
    var midPoint: CGPoint {
        return CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
    }
}
