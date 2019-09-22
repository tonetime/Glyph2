import Foundation


class MaskSandwich {
    var sandwichHidden=false
    fileprivate var frontView:UIView
    fileprivate var backView:UIView
    fileprivate var superV:UIView
    var drawView:DrawView
    fileprivate var tint:UIView
    fileprivate var tintTag=44
    var freehandDrawController:FreehandDrawController

    init(superV:UIView, frontView:UIView, backView:UIView) {
        self.superV=superV
        self.frontView=frontView
        self.backView=backView
        self.drawView=DrawView(frame: self.frontView.frame, viewToMask: nil)
        self.drawView.frame=self.frontView.bounds
        self.frontView.isUserInteractionEnabled=false
        self.backView.isUserInteractionEnabled=true
        self.freehandDrawController=FreehandDrawController(canvas: self.drawView, gestureView: self.backView)
        //self.freehandDrawController=FreehandDrawController(canvas: self.drawView, gestureView: superV)

        self.tint=UIView(frame: self.frontView.frame)
        self.tint.frame=self.frontView.bounds
        self.tint.backgroundColor=UIColor.blue.withAlphaComponent(0.3)
        self.tint.isUserInteractionEnabled=false
        self.tint.tag=tintTag
        
        
        assert(self.backView.frame==self.frontView.frame, "Backview frame must match frontview frame \(self.frontView.frame) \(self.backView.frame)")
        assert(self.backView.bounds==self.frontView.bounds, "Backview bounds must match frontview bounds")
        self.backView.mask=self.drawView
        self.superV.insertSubview(backView, at: 0)
        self.superV.insertSubview(self.frontView, aboveSubview: self.backView)
       // self.superV.addSubview(self.backView)
        //self.addTintToBackView()
       // self.superV.insertSubview(self.frontView, atIndex: 0)
    }
    deinit {
        print("MASK SANDWICH CLEANED UP")
    }
    
    func isLandscapeOrientation() -> Bool {
        return self.backView.frame.size.width > self.backView.frame.size.height
    }
    
    func getFullFrontView() -> UIImage {
        let f=self.frontView as! UIImageView
        return f.image!
    }
    
    func getFullMaskingView() -> UIImage {
        let f=getFullFrontView()
        let size=f.size
        var buf=self.drawView.buffer
        if buf == nil {
            self.drawView.firstDraw()
            buf=self.drawView.buffer
        }
        return (buf?.scaledToSize(size))!
    }
    
    func hideFrontView() {
        self.tint.isHidden=true
        self.frontView.isHidden=true
        self.backView.isUserInteractionEnabled=false
        self.backView.mask=nil
        self.sandwichHidden=true
    }
    func showFrontView() {
        self.tint.isHidden=false
        self.frontView.isHidden=false
        self.backView.mask=self.drawView
        self.backView.isUserInteractionEnabled=true
        self.sandwichHidden=false
    }
    func addTintToBackView() {
        self.removeTintFromSuperView()
        self.tint.frame=self.backView.bounds
        self.backView.addSubview(self.tint)
    }
    func addTintToFrontView() {
        self.removeTintFromSuperView()
        self.tint.frame=self.frontView.frame
        self.tint.bounds=self.frontView.bounds
        self.superV.insertSubview(self.tint, aboveSubview: self.frontView)
    }
    func removeTintFromSuperView() {
        self.superV.viewWithTag(tintTag)?.removeFromSuperview()
    }
    func clearMask() {
        self.drawView.reset()
    }
    func eraseDrawing(_ erase:Bool) {
        if (erase) {
            print("Setting to erase")
            self.drawView.erase=true
        }
        else {
            //self.freehandDrawController.color=UIColor.blackColor()
            self.freehandDrawController.color=UIColor.white
            self.drawView.erase=false
        }
    }
    func updateFrontView(_ view:UIView) {
        assert(self.frontView.frame==view.frame, "Backview frame must match frontview frame \(self.backView.frame) \(view.frame)")
        assert(self.frontView.bounds==view.bounds, "Backview bounds must match frontview bounds")
        self.frontView.removeFromSuperview()
        self.frontView=view
        self.superV.insertSubview(self.frontView, at: 0)
        self.frontView.isUserInteractionEnabled=false
    }
    func cleanUp() {
        self.removeTintFromSuperView()
        self.frontView.removeFromSuperview()
        self.backView.removeFromSuperview()
    }
    static func tint(_ img:UIImage) -> UIImage {
        return img.tint(UIColor.blue.withAlphaComponent(0.9))
    }
    static func createImage(_ rect:CGRect,fillColor:UIColor=UIColor.gray) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(rect.size, false, 0)
        let context = UIGraphicsGetCurrentContext();
        fillColor.setFill()
        context?.fill(rect)
        let image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        return image!
    }
    
    
    
    let pixBuffAttributesPlanar : [String: AnyObject] = [ String(kCVPixelBufferPixelFormatTypeKey) : Int(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange) as AnyObject]
    
    
    /*
     1. Wind player to starting position.
     
     2. Create an interator (go backwards if bounce = true )
     
     https://github.com/FlexMonkey/VideoEffects/blob/master/VideoEffects/FilteredVideoWriter.swift
     https://github.com/objcio/core-image-video/blob/master/CoreImageVideo/VideoSampleBufferSource.swift
     */
    func saveVideo(_ player:LoopPlayerView) -> UIImage {
        player.player().pause()
        player.stopLink()
        
        let videoOutput = AVPlayerItemVideoOutput(pixelBufferAttributes: pixBuffAttributesPlanar)
        player.player().currentItem!.add(videoOutput)
        let asset=player.player().currentItem?.asset
        let assetTrack = asset!.tracks(withMediaType: AVMediaTypeVideo).first!
        let size = assetTrack.naturalSize
        let drawBuf=self.drawView.buffer?.scaledToSize(size)
        return drawBuf!
    }
    
    func createVideoSettings(_ asset:AVAsset) -> [String:NSObject] {
        let assetTrack = asset.tracks(withMediaType: AVMediaTypeVideo).first!
        let size = assetTrack.naturalSize
        let frameRate=assetTrack.nominalFrameRate
        let w=size.width
        let h=size.height
        let numPixels = w*h
        var bitsPerSecond: Int
        var bitsPerPixel: Float
        if numPixels < 640 * 480 {
            bitsPerPixel = 4.05; // This bitrate approximately matches the quality produced by AVCaptureSessionPresetMedium or Low.
        } else {
            bitsPerPixel = 10.1; // This bitrate approximately matches the quality produced by AVCaptureSessionPresetHigh.
        }
        bitsPerSecond = Int(Float(numPixels) * bitsPerPixel)
        bitsPerSecond = Int(Double(bitsPerSecond))
        let compressionProperties: NSDictionary = [AVVideoAverageBitRateKey : bitsPerSecond,
                                                   AVVideoExpectedSourceFrameRateKey : frameRate,
                                                   AVVideoMaxKeyFrameIntervalKey : 20]
        let settings = [AVVideoCodecKey : AVVideoCodecH264,
                        AVVideoWidthKey : w,
                        AVVideoHeightKey : h,
                        AVVideoCompressionPropertiesKey : compressionProperties] as [String : Any]
        print("Settings for saving final movie: \(settings)")
        return settings as! [String : NSObject]
    }
}
