
import UIKit

class DrawView : UIView, Canvas, DrawCommandReceiver {
    
    init(frame: CGRect,viewToMask:UIView?) {
        super.init(frame: frame)
        self.viewToMask=viewToMask
    }
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    // MARK: Canvas
    var context: CGContext {
        return UIGraphicsGetCurrentContext()!
    }
    
    /*
     If the event is not a PanGesture pass it along.
     Otherwise it's mine.
     */
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        return overridePoint
    }
    
    func reset() {
        self.buffer = nil
        self.layer.contents = nil
    }
    // MARK: DrawCommandReceiver
    func executeCommands(_ commands: [DrawCommand]) {
        autoreleasepool {
            self.buffer = drawInContext { context in
                commands.map { $0.execute(self) }
            }
            //self.layer.contents = self.buffer?.CGImage ?? nil
            layoutBufferImage()
        }
    }
    
    func layoutBufferImage() {
        if (viewToMask != nil) {
            //if self.maskedDrawView==nil {
//            let f=CGRect(x: 0, y: 0, width: 300, height: 400)
//            let z=CGRect(x: 50, y: 150, width: 300, height: 400)
//            let g=MaskDrawController.createImage(f, fillColor: UIColor.redColor())
            self.maskedDrawView=UIImageView(image: self.buffer)
            
               // self.maskedDrawView!.frame=self.frame
               // print("Uimage is \(self.frame)  \(self.maskedDrawView!.frame) \(self.maskedDrawView!.bounds)")
            //self.maskedDrawView!.frame=CGRect(x: 50, y: 150, width: 300, height: 400)
            
            
            //self.maskedDrawView!.backgroundColor=UIColor.yellowColor()
                viewToMask?.mask=self.maskedDrawView
                //self.maskedDrawView?.maskView=viewToMask
            //}
            //else {
             //   self.maskedDrawView?.image=self.buffer
            //}
        }
        else {
            //self.layer.backgroundColor=UIColor.clearColor().CGColor
            self.layer.contents = self.buffer?.cgImage ?? nil
        }
    }
    func firstDraw() {
        self.maskedDrawView=nil
        self.buffer=drawInContext(nil)
        layoutBufferImage()
    }
    // MARK: General setup to draw. Reusing a buffer and returning a new one
    
    fileprivate func drawInContext(_ code:((_ context: CGContext) -> Void)? ) -> UIImage {
        let size = self.bounds.size
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        let context = UIGraphicsGetCurrentContext()
        if erase==true {
            context?.setBlendMode(CGBlendMode.clear)
        }
        // Draw previous buffer first
        if let buffer = buffer {
            buffer.draw(in: self.bounds)
        }
        
        if (code != nil) {
            // Execute draw code
            code!(context!)
        }
        // Grab updated buffer and return it
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image!
    }
    var times=0
    var buffer: UIImage?
    var viewToMask:UIView?
    var maskedDrawView:UIImageView?
    var overridePoint=true
    var erase=false
}
