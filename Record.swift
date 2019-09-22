import Foundation
import UIKit
fileprivate func < <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l < r
  case (nil, _?):
    return true
  default:
    return false
  }
}

fileprivate func >= <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l >= r
  default:
    return !(lhs < rhs)
  }
}


class Record {
    var recordButton : RecordButton!
    var progressTimer : Timer!
    var progress : CGFloat! = 0
    var recording=false
    let d=CGFloat(75.0)
    var recordingStart:(() -> Void)!
    var recordingStop:(() -> Void)!
    var token: Int = 0

    let motion:MotionQuantity

    
    init(superview:UIView) {
        self.motion=MotionQuantity()
        recordButton = RecordButton(frame: CGRect(x: 0,y: 0,width: d,height: d))
        recordButton.center = superview.center
        recordButton.progressColor = .red
        recordButton.closeWhenFinished = false
        recordButton.addTarget(self, action: #selector(Record.touchDown), for: .touchDown)
        recordButton.addTarget(self, action: #selector(Record.stop), for: UIControlEvents.touchUpInside)
        superview.addSubview(recordButton)

    }
    deinit {
        motion.stopMotionManager()
    }
    
    @objc func touchDown() {
        if (recording) {
            stopRecording()
            return
        }
        else {
            self.progressTimer = Timer.scheduledTimer(timeInterval: 0.05, target: self, selector: #selector(Record.updateProgress), userInfo: nil, repeats: true)
            
            self.motion.whenVideoStable({ () -> Void in
                self.motion.stopMotionManager()
                self.recording=true
                self.recordButton.buttonState = .recording
                if (self.recordingStart != nil) {
                    self.recordingStart()
                }
            })
        }
    }
    
    func cancel() {
        motion.stopMotionManager()
        self.progressTimer?.invalidate()
        self.recordButton.buttonState = .idle
        progress=0
        recording=false
    }
    
    func stopRecording() {
        motion.stopMotionManager()
        print("Recording... stopping it.")
        self.progressTimer?.invalidate()
        self.recordButton.buttonState = .idle
        progress=0
        recording=false
        if (recordingStop != nil) {
            recordingStop()
        }
    }
    @objc func stop() {
//        print("stop!")
//        self.progressTimer.invalidate()
//        self.recordButton.buttonState = .Idle
    }
    
    @objc func updateProgress() {
        if (self.recording != true) {
            print("Not recording yet. No progress")
            return
        }
        let maxDuration = CGFloat(5) // max duration of the recordButton
        progress = progress + (CGFloat(0.05) / maxDuration)
        recordButton.setProgress(progress)
        if progress >= 1 {
            stopRecording()
        }
    }
}
