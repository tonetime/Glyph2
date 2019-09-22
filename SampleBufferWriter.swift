
import Foundation
import AVKit
import AVFoundation

class SampleBufferWriter {
    
    var videoOutputSettings:[String:NSObject]?
    var avAssetWriter: AVAssetWriter?
    var avAssetWriterInput: AVAssetWriterInput?
    var preferredTransform:CGAffineTransform=CGAffineTransform.identity
    fileprivate var device:AVCaptureDevice
    fileprivate var frameRate:Int
    fileprivate var sessionStarted=false

    var tmpFilmURL:URL {
        let tempDir = NSTemporaryDirectory()
        let url = URL(fileURLWithPath: tempDir).appendingPathComponent("tmp2.mp4")
        do {
        try FileManager.default.removeItem(at: url)
        }
        catch {
            //print(error)
        }
        return url
    }
    
    init(device:AVCaptureDevice,frameRate:Int=24) {
        self.frameRate=frameRate
        self.device=device
    }
    
    func setupWriter() {
        let dims=CMVideoFormatDescriptionGetDimensions(device.activeFormat.formatDescription)
        self.videoOutputSettings=SampleBufferWriter.createVideoSettings(Int(dims.width), h: Int(dims.height), frameRate: self.frameRate)
//        if isLandscapeOrientation() {
        
//            self.videoOutputSettings=SampleBufferWriter.createVideoSettings(Int(dims.width), h: Int(dims.height), frameRate: self.frameRate)
//        }
//        else {
//            self.videoOutputSettings=SampleBufferWriter.createVideoSettings(Int(dims.height), h: Int(dims.width), frameRate: self.frameRate)
//        }
        avAssetWriterInput = AVAssetWriterInput(mediaType: AVMediaTypeVideo, outputSettings:
            self.videoOutputSettings)
        let aa=preferredTransform
       // print("Here's the transform that im going with: a:\(aa.a) b:\(aa.b) c:\(aa.c) d:\(aa.d) tx:\(aa.tx) ty:\(aa.ty)")
        avAssetWriterInput?.transform=preferredTransform
        
        
        
        //let aa=CGAffineTransformMakeRotation(90 * (CGFloat(M_PI)/180));
        //print("Here's the transform that im going with: a:\(aa.a) b:\(aa.b) c:\(aa.c) d:\(aa.d) tx:\(aa.tx) ty:\(aa.ty)")
        //avAssetWriterInput?.transform=CGAffineTransformMakeRotation(90 * (CGFloat(M_PI)/180));
        
        
        avAssetWriterInput!.expectsMediaDataInRealTime = true
        do {
            
            avAssetWriter = try AVAssetWriter(outputURL: tmpFilmURL, fileType: AVFileTypeAppleM4V)
            avAssetWriter!.add(avAssetWriterInput!)

        }
        catch {
            print(error)
        }
    }
    
    func CGAffineTransformMakeDegreeRotation(_ rotation: CGFloat) -> CGAffineTransform {
        return CGAffineTransform(rotationAngle: rotation * CGFloat(M_PI / 100))
    }
    
    
    func write(_ sampleBuffer:CMSampleBuffer) {
        if sessionStarted==false {
            avAssetWriter!.startSession(atSourceTime: CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
            sessionStarted=true
        }
        if avAssetWriterInput!.isReadyForMoreMediaData {
            var appended = avAssetWriterInput!.append(sampleBuffer)
            let status = avAssetWriter!.status
            let error = avAssetWriter!.error
        }
        else {
            print("Well avassetWriter not ready for more data..")
        }

    }
    func startCapture() {
        self.setupWriter()
        print("Capture Starting")
        avAssetWriter!.startWriting()
        print("assetWriterStatus:\(avAssetWriter!.status.rawValue)")
    }
    func stopCapture() {
        sessionStarted=false
        let outputUrl = avAssetWriter!.outputURL
        print("\(outputUrl)")
        avAssetWriterInput!.markAsFinished()
        avAssetWriter!.finishWriting { () -> Void in
            print("Done Writing !")
        }
    }
    
    //https://github.com/mmohsin991/RosyWriter2.1-Swift-Mohsin-addition-/blob/2643510cc251c2c410774842fbca4fe1bd98ec6d/Classes/MovieRecorder.swift
    static func createVideoSettings(_ w:Int,h:Int,frameRate:Int) -> [String:NSObject] {
        let numPixels = w*h
        var bitsPerSecond: Int
        var bitsPerPixel: Float
        if numPixels < 640 * 480 {
            bitsPerPixel = 4.05; // This bitrate approximately matches the quality produced by AVCaptureSessionPresetMedium or Low.
        } else {
            bitsPerPixel = 10.1; // This bitrate approximately matches the quality produced by AVCaptureSessionPresetHigh.
        }
        bitsPerSecond = Int(Float(numPixels) * bitsPerPixel)
        bitsPerSecond = Int(Double(bitsPerSecond)*0.2)
        
        
        
        let compressionProperties: NSDictionary = [AVVideoAverageBitRateKey : bitsPerSecond,
            AVVideoExpectedSourceFrameRateKey : frameRate,
            AVVideoMaxKeyFrameIntervalKey : 20]
        let settings = [AVVideoCodecKey : AVVideoCodecH264,
            AVVideoWidthKey : w,
            AVVideoHeightKey : h,
            AVVideoCompressionPropertiesKey : compressionProperties] as [String : Any]
        print("create video settings \(settings)")
        return settings as! [String : NSObject]
    }
    
}
