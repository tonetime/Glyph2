import Foundation
import AVFoundation


class CaptureBufferDelegate: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    let v:UIView
    let d:AVCaptureDevice
    let stab:Stabilize3
    let writer:SampleBufferWriter
    fileprivate var x = 0
    fileprivate var dropped=0
    fileprivate var hasStarted=false
    var recording=false
    
    init(v:UIView,d:AVCaptureDevice) {
        self.v=v
        self.d=d
        Stabilize3.resetSharedInstance()        
        self.stab=Stabilize3.sharedInstance()
        self.writer=SampleBufferWriter(device: d, frameRate: 24)
        FrameCompare.sharedInstance.reset()
        super.init()
//        self.motion.callBackOnStableFrame = { () -> Void in
//            self.startRecording2()
//        }
    }
    
    func setPreferredTransform(_ t:CGAffineTransform) {
        self.writer.preferredTransform=t
    }
    
    func startRecording() {
        self.writer.startCapture()
        self.recording=true
    }
    func stopRecording() {
        recording=false
        writer.stopCapture()
    }
    func recordSampleBuffer(_ sampleBuffer:CMSampleBuffer) {
        assert(recording==true, "Recording should be true to get here.")
        writer.write(sampleBuffer)
    }
    func captureOutput(_ captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, from connection: AVCaptureConnection!) {

        if recording {
            
            x+=1
            stab.processFrame(sampleBuffer, andSaveImages: false)
            recordSampleBuffer(sampleBuffer)
           // print("frames \(x)")
        }
    }
    func captureOutput(_ captureOutput: AVCaptureOutput!, didDrop sampleBuffer: CMSampleBuffer!, from connection: AVCaptureConnection!) {
        dropped += 1
        print("Dropped Capture Output \(dropped) \(kCMSampleBufferAttachmentKey_DroppedFrameReasonInfo)")
    }
}
