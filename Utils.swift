import Foundation
import Accelerate
import UIKit
import AVFoundation

class tmpBufferData {
    var tmpBuffer:UnsafeMutableRawPointer?=nil
    var tmpDestData:UnsafeMutablePointer<Pixel_8>?=nil
    var width=0
    var height=0
    
    func didWidthHeightChange(_ width:Int,height:Int) {
        if width != self.width || height != self.height {
            self.width=width
            self.height=height
            free(self.tmpDestData)
            free(self.tmpBuffer)
            self.tmpBuffer=nil
            self.tmpDestData=nil
            //print("Changed width height!")            
        }
    }
}
var tmpData=tmpBufferData()

func isLandscapeOrientation() -> Bool {
    return UIDevice.current.orientation == UIDeviceOrientation.landscapeRight || UIDevice.current.orientation == UIDeviceOrientation.landscapeLeft
}

func filterEdges(_ img:CIImage) -> CIFilter {
    let filter = CIFilter(name: "CIEdges",
        withInputParameters: [kCIInputIntensityKey: 15])!
    filter.setValue(img , forKey: kCIInputImageKey)
    return filter
}
func monochromFilter(_ img:CIImage) -> CIFilter {
    let monochromeFilter=CIFilter(name:"CIColorMonochrome")
    monochromeFilter!.setValue(img,forKey: kCIInputImageKey)
    monochromeFilter!.setValue(CIColor(red:0.5,green:0.5,blue:0.5), forKey:kCIInputColorKey)
    monochromeFilter!.setValue(1.0, forKey: kCIInputIntensityKey)
    return monochromeFilter!
}
func greyscaleImage(_ image:UIImage) -> UIImage {
    let imageRect=CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height)
    let colorSpace=CGColorSpaceCreateDeviceGray()
    let context=CGContext(data: nil, width: Int(image.size.width), height: Int(image.size.height), bitsPerComponent: 8, bytesPerRow: Int(image.size.width)*1, space: colorSpace,bitmapInfo: (CGImageAlphaInfo.none.rawValue))
    context?.draw(image.cgImage!, in: imageRect)
    let imageRef=context?.makeImage()
    let grayscaleImage = UIImage(cgImage: imageRef!)
    return grayscaleImage;
}
func scaleImage(_ image:UIImage,width:Double,height:Double) -> UIImage {
    let newSize=CGSize(width: width, height: height)
    UIGraphicsBeginImageContext( newSize );
    image.draw(in: CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height))
    let newImage=UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext();
    return newImage!;
}
func resizeByWidth(_ img:CIImage,maxWidth:CGFloat) -> CIFilter {
    img.extent.width
    let scale=maxWidth/img.extent.width
    let filter = CIFilter(name: "CILanczosScaleTransform")!
    filter.setValue(img, forKey: "inputImage")
    filter.setValue(scale, forKey: "inputScale")
    filter.setValue(1.0, forKey: "inputAspectRatio")
    return filter
}
func convertCIImageToCGImage(_ inputImage: CIImage) -> CGImage! {
    //let context = CIContext(options: nil)
    //    let eaglContxt=EAGLContext.init(API: EAGLRenderingAPI.OpenGLES2)
    //var context = CIContext(options: [kCIContextWorkingColorSpace: NSNull()])
    //    let context=CIContext.init(EAGLContext: eaglContxt,options: [kCIContextWorkingColorSpace: NSNull()])
    //context.workingColorSpace
    let context=MyContext.sharedContext.coreImageContext
    return context.createCGImage(inputImage, from: inputImage.extent)
}
//134/71
//67/36
//func scalePlanarSampleBuffer(_ sampleBuffer:CMSampleBuffer, destSize:CGSize = CGSize(width: 67,height: 36)) -> CGImage? {
//    let b=Benchmark()
//    let cameraBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)!
//    CVPixelBufferLockBaseAddress(cameraBuffer, CVPixelBufferLockFlags(rawValue: CVOptionFlags(0)))
//    let width = CVPixelBufferGetWidthOfPlane(cameraBuffer, 0)
//    let height = CVPixelBufferGetHeightOfPlane(cameraBuffer, 0)
//    tmpData.didWidthHeightChange(width, height: height)
//    let bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(cameraBuffer, 0)
//    let lumaBuffer = UnsafeMutablePointer<Pixel_8>(CVPixelBufferGetBaseAddressOfPlane(cameraBuffer, 0))
//    var inImage=vImage_Buffer(data: lumaBuffer, height: UInt(height), width: UInt(width), rowBytes: bytesPerRow)
//    let bytesPerPixel = 1
//    let destWidth = destSize.width
//    let destHeight = destSize.height
//     //let destWidth = 134
//    //let destHeight = 71
//    let destPixelCount = Int(destWidth * destHeight)
//    let destBytesPerRow = UInt(destWidth) * UInt(bytesPerPixel)
//    let destByteCount = Int(UInt(destHeight) * destBytesPerRow)
//    if (tmpData.tmpDestData==nil) {
//        tmpData.tmpDestData=UnsafeMutablePointer<Pixel_8>.allocate(capacity: destByteCount)
//    }
////    let destData = UnsafeMutablePointer<Pixel_8>.alloc(destByteCount)
////    defer { destData.dealloc(destByteCount) }
//    var destBuffer = vImage_Buffer(data: tmpData.tmpDestData, height: vImagePixelCount(destHeight), width: vImagePixelCount(destWidth), rowBytes: Int(destBytesPerRow))
//    
//    if (tmpData.tmpBuffer==nil) {
//        let flags = vImage_Flags(kvImageGetTempBufferSize) | vImage_Flags(kvImageEdgeExtend)
//        let tempBufferSize: Int = vImageScale_Planar8(&inImage, &destBuffer, nil, flags)
//        //print(tempBufferSize)
//        tmpData.tmpBuffer=malloc(tempBufferSize)
//    }
//    var error: vImage_Error
//    error=vImageScale_Planar8(&inImage, &destBuffer, tmpData.tmpBuffer, 0)
//    guard error == kvImageNoError else { return nil }
//    
//    let grayColorSpace=CGColorSpaceCreateDeviceGray()
//    let context=CGContext(data: destBuffer.data, width: Int(destWidth), height: Int(destHeight), bitsPerComponent: 8,bytesPerRow: Int(destBytesPerRow),space: grayColorSpace,bitmapInfo: CGBitmapInfo().rawValue)
//    let dstImageFilter = context?.makeImage()
//    let tt=b.timeSinceLast()
//   // print("Time:\(tt)ms DestWidth:\(destWidth) DestHeight:\(destHeight)")
//    return dstImageFilter
//}
//
//
//func vImageScaleTest(_ sampleBuffer:CMSampleBuffer,size:CGSize) -> UIImage? {
//    let bb=Benchmark()
//    
//    let cameraBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)!
//    CVPixelBufferLockBaseAddress(cameraBuffer, CVPixelBufferLockFlags(rawValue: CVOptionFlags(0)))
//    
//    // Source image buffer from camera buffer
//    let sourceBaseAddress = UnsafeMutablePointer<UInt8>(CVPixelBufferGetBaseAddress(cameraBuffer))
//    let sourceBytesPerRow = CVPixelBufferGetBytesPerRow(cameraBuffer);
//    let sourceWidth = UInt(CVPixelBufferGetWidth(cameraBuffer))
//    let sourceHeight = UInt(CVPixelBufferGetHeight(cameraBuffer))
//    var sourceBuffer = vImage_Buffer(data: sourceBaseAddress, height: sourceHeight, width: sourceWidth, rowBytes: sourceBytesPerRow)
//    
//    // Destination image buffer for scaling
//    let bytesPerPixel = 4
//    let destWidth = sourceWidth / 4
//    let destHeight = sourceHeight / 4
//    print("\(destWidth) \(destHeight)")
//    //    let destWidth = UInt(128)
//    //    let destHeight = UInt(128)
//    let destPixelCount = Int(destWidth * destHeight)
//    let destBytesPerRow = destWidth * UInt(bytesPerPixel)
//    let destByteCount = Int(destHeight * destBytesPerRow)
//    let destData = UnsafeMutablePointer<UInt8>.allocate(capacity: destByteCount)
//    defer { destData.deallocate(capacity: destByteCount) }
//    var destBuffer = vImage_Buffer(data: destData, height: vImagePixelCount(destHeight), width: vImagePixelCount(destWidth), rowBytes: Int(destBytesPerRow))
//    // Scale the image
//    
//    
//    //kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
//    var error: vImage_Error
//    error=vImageScale_Planar8(&sourceBuffer, &destBuffer, nil, 0)
//    //error = vImageScale_ARGB8888(&sourceBuffer, &destBuffer, nil,0)
//    guard error == kvImageNoError else { return nil }
//    let bi2=CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue )
//    var format = vImage_CGImageFormat(bitsPerComponent: 8,
//        bitsPerPixel: 32,
//        colorSpace: nil,
//        bitmapInfo: bi2,
//        version: 0,
//        decode: nil,
//        renderingIntent: CGColorRenderingIntent.defaultIntent)
//    guard let destCGImage = vImageCreateCGImageFromBuffer(&destBuffer, &format, nil, nil, numericCast(kvImageNoFlags), &error)?.takeRetainedValue()
//        else { return nil }
//    
//    guard error == kvImageNoError else { return nil }
//    let dataProvider=CGDataProvider(dataInfo: nil, data: &destBuffer, size: destByteCount, releaseData: nil)
//    let cs = CGColorSpaceCreateDeviceRGB()
//    let uu =    UIImage(cgImage: destCGImage)
//    CVPixelBufferUnlockBaseAddress(cameraBuffer, CVPixelBufferLockFlags(rawValue: CVOptionFlags(0)))
//    bb.printTimeSinceStart()
//    return uu
//}

class MyContext {
    let eaglContext=EAGLContext.init(api: EAGLRenderingAPI.openGLES2)
    var coreImageContext:CIContext
    let pixBuffAttributes : [String: AnyObject] = [ String(kCVPixelBufferPixelFormatTypeKey) : Int(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange) as AnyObject]
    
    static let sharedContext=MyContext()
    init() {
        coreImageContext=CIContext(eaglContext: self.eaglContext!,options:pixBuffAttributes)
        //        coreImageContext.re
        //  coreImageContext=CIContext.init(EAGLContext: eaglContext,options: [kCIContextWorkingColorSpace: NSNull()])
        //        coreImageContext=CIContext(options: nil)
        //        coreImageContext=CIContext(options: [kCIContextWorkingColorSpace: NSNull()])
    }
}
class Benchmark {
    var start=Int64(0)
    var tests=0
    var high=Int64(0)
    var low=Int64(99999)
    init() {
        //start=NSDate.timeIntervalSinceReferenceDate()
        start=self.currentTimeMillis()
    }
    func timeSinceLast() -> Int64 {
        tests += 1
        let current=self.currentTimeMillis()
        let x=current - start
        if (x > high) {
            high=x
        }
        if (x < low) {
            low=x
        }
        start=current
        return x
        //return (NSDate.timeIntervalSinceReferenceDate()  - start)*1000
    }
    func printTimeSinceStart()  {
        let x=self.timeSinceLast()
        //print("\(x)ms   high:\(high) low:\(low)")
        print("\(x)ms")
    }
    func currentTimeMillis() -> Int64{
        let nowDouble = Date().timeIntervalSince1970
        return Int64(nowDouble*1000)
    }
}

