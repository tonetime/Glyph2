import UIKit
import AVFoundation
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

fileprivate func > <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l > r
  default:
    return rhs < lhs
  }
}


class CameraViewController: UIViewController {
    var record:Record!
    var camera:BESwiftCamera!
    fileprivate var bButton:UIButton?
    fileprivate var originalOrientation:UIDeviceOrientation?
    fileprivate var orientations=[1,3,2,4]
    
    var captureDelegate: CaptureBufferDelegate!
    var dataOutput:AVCaptureVideoDataOutput?
    var snapButton:UIButton!
    let pixBuffAttributesPlanar : [String: AnyObject] = [ String(kCVPixelBufferPixelFormatTypeKey) : Int(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange) as AnyObject]
    let pixBufAttributesBRGBA : [String:AnyObject] = [ String(kCVPixelBufferPixelFormatTypeKey) : Int(kCVPixelFormatType_32BGRA) as AnyObject ]
    var count=Int(0)
    
     //var afterInit:((BESwiftCamera!, AVCaptureDevice!, AVCaptureVideoPreviewLayer!,AVCaptureSession! ) -> Void)!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let screenRect = UIScreen.main.bounds
        self.view.backgroundColor = UIColor.black
        self.navigationController?
            .setNavigationBarHidden(true, animated: false)
        
        
        self.camera = BESwiftCamera(withQuality: AVCaptureSessionPreset1280x720, position: .rear, videoEnabled: true)
//        self.camera = BESwiftCamera(withQuality: AVCaptureSessionPresetHigh, position: .Rear, videoEnabled: true)
        self.camera.attachToViewController(self, withFrame: CGRect(x: 0,y: 0,width: screenRect.size.width,height: screenRect.size.height))
        self.record=Record(superview: self.view)
        self.record.recordingStart = {
            [weak self ] in
            self!.setPreferredTransformForCaptureDelegate()
            self!.camera.setFocus(AVCaptureFocusMode.locked)
            self!.captureDelegate.startRecording()
        }
        record.recordingStop={
            [weak self ] in
            
            self!.captureDelegate.stopRecording()
            self!.camera.setFocus(AVCaptureFocusMode.continuousAutoFocus)
            self!.camera.stop()
            let rr=UIApplication.shared.keyWindow?.rootViewController as! NavControllerNoRoate
            rr.allowRotate=false
            self!.dismiss(animated: false, completion: nil)
            rr.goToPostProcessController(MyGlobals.unstabilizedSavedURL)
        }
        let f=positionRecord(screenRect.size)
        record.recordButton.frame = f
        self.setNavbar()
        NotificationCenter.default.addObserver(self, selector: #selector(CameraViewController.orientationChanged), name: NSNotification.Name.UIDeviceOrientationDidChange, object: nil)
        
        self.camera.afterInit = {
                [weak self] camera, device,layer,session in
                    self!.dataOutput=AVCaptureVideoDataOutput()
                    self!.defaultConfiguration(device!,prevLayer: layer!)
                    self!.captureData(session!,device: device!)
                    self?.setStabilization(self!.dataOutput!, device: device!)
                    self!.outputConfiguration(device!,prevLayer: layer!)
                    self!.setDefaultOrientation()
        }
        NotificationCenter.default.addObserver(self, selector: #selector(self.applicationWillResignActive), name: NSNotification.Name.UIApplicationWillResignActive, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.applicationDidBecomeActive), name: NSNotification.Name.UIApplicationDidBecomeActive, object: nil)

    }
    deinit {
        print("DEALLOC CAMERAVIEWCONTROLLER")
        NotificationCenter.default.removeObserver(self)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UIApplicationWillResignActive, object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UIApplicationDidBecomeActive, object: nil)
        self.camera?.stop()
    }
    
    func applicationWillResignActive() {
        print("Stopping!")
        self.record.cancel()
        self.camera?.stop()
    }
    func applicationDidBecomeActive() {
        do {
            try self.camera.start()
        } catch {
            print("cant restart camera")
        }
    }
    
    override var prefersStatusBarHidden : Bool {
        return true
    }
    func orientationChanged(_ notification: Notification ){
        
        let orientation = UIDevice.current.orientation
        if (orientation.rawValue > 4 ) {
            return;
        }
        if (self.originalOrientation?.rawValue > 4) {
            self.originalOrientation=UIDeviceOrientation.landscapeLeft
            print("Original orientation > 4, that's a problem.")
            //return;
        
        }
        
        
        UIView.animate(withDuration: 0.2, animations: { () -> Void in
            //let size=UIScreen.mainScreen().bounds.size
            if (self.originalOrientation==orientation) {
                self.bButton?.transform=CGAffineTransform.identity
            }
            else {
                let d = abs(self.orientations.index(of: orientation.rawValue)! - self.orientations.index(of: self.originalOrientation!.rawValue)!)
                let multiBy = self.originalOrientation?.rawValue > 2 ? -90 : 90
                let t=CGAffineTransform( rotationAngle: ( CGFloat(multiBy) * CGFloat(d)) * (CGFloat(M_PI)/180))
                self.bButton?.transform=t
            }
        }, completion: { (Bool) -> Void in
        }) 
    }
    

//    func recordingStart() {
//        {[weak self] in
//        
//        1+ 1
//        }
////        if UIDevice.currentDevice().orientation == UIDeviceOrientation.PortraitUpsideDown {
////            self.updateOrientation()
////        }
//        setPreferredTransformForCaptureDelegate()
//        camera.setFocus(AVCaptureFocusMode.Locked)
//        captureDelegate.startRecording()
//    }
    //Note default orientation is LandscapeRight
    func setPreferredTransformForCaptureDelegate() {
        let orientation=UIDevice.current.orientation
        var t=CGAffineTransform.identity
        switch orientation {
        case .landscapeLeft:
            t=CGAffineTransform.identity
        case .portrait:
            t=CGAffineTransform(rotationAngle: 90 * (CGFloat(M_PI)/180))
        case .portraitUpsideDown:
            t=CGAffineTransform(rotationAngle: 270 * (CGFloat(M_PI)/180))
        case .landscapeRight:
            t=CGAffineTransform(rotationAngle: 180 * (CGFloat(M_PI)/180))
        default:
            t=CGAffineTransform.identity
        }
        self.captureDelegate.setPreferredTransform(t)
    }

    func getTransformForOrientation() -> CGAffineTransform {
        let orientation=UIDevice.current.orientation
        var t=CGAffineTransform.identity
        switch orientation {
        case .landscapeLeft:
            t=CGAffineTransform.identity
        case .portrait:
            t=CGAffineTransform(rotationAngle: 90 * (CGFloat(M_PI)/180))
        case .portraitUpsideDown:
            t=CGAffineTransform(rotationAngle: 270 * (CGFloat(M_PI)/180))
        case .landscapeRight:
            t=CGAffineTransform(rotationAngle: 180 * (CGFloat(M_PI)/180))
        default:
            t=CGAffineTransform.identity
        }
        return t;
    }
    func setNavbar() {
        //let i=NSBundle.mainBundle().URLForResource("back44", withExtension: "png")
        let i=Bundle.main.url(forResource: "Back-White-50", withExtension: "png")

        let ui = UIImage(data: try! Data(contentsOf: i!))
        let r2=CGRect(x: 0, y: 0, width: 50, height: 50)
        self.bButton=UIButton(frame: r2 )
        self.bButton?.setImage(ui, for: UIControlState())
        self.bButton?.addTarget(self, action: #selector(CameraViewController.backButtonPressed), for: .touchUpInside)
        self.view.addSubview(bButton!)
        self.originalOrientation=UIDevice.current.orientation
    }
    @objc fileprivate func backButtonPressed() {
        if (captureDelegate.recording) {
            print("Too late to go back! Already recording.")
            return
        }
        self.camera.stop()
        let rr=UIApplication.shared.keyWindow?.rootViewController as! NavControllerNoRoate
        rr.allowRotate=true
        self.dismiss(animated: true, completion: nil)
        
    }
//    func recordingStop() {
//        captureDelegate.stopRecording()
//        camera.setFocus(AVCaptureFocusMode.ContinuousAutoFocus)
//        self.camera.stop()
//        let rr=UIApplication.sharedApplication().keyWindow?.rootViewController as! NavControllerNoRoate
//        rr.allowRotate=false
//        self.dismissViewControllerAnimated(false, completion: nil)        
//        rr.goToPostProcessController(MyGlobals.unstabilizedSavedURL)
//    }    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.attachCamera()
    }
    func attachCamera() {
        do {
            try self.camera.start()
        } catch BESwiftCameraErrorCode.cameraPermission {
            self.showCameraPermissionAlert()
        } catch BESwiftCameraErrorCode.microphonePermission {
            self.showMicrophonePermissionAlert()
        } catch {
            self.showUnknownErrorAlert()
        }
    }
    func positionRecord(_ size:CGSize) -> CGRect {
        let orientation = UIDevice.current.orientation
        let b=record.recordButton.bounds
        var r=CGRect(x: 0, y: 0, width: 0, height: 0)
        if (orientation==UIDeviceOrientation.landscapeLeft || orientation==UIDeviceOrientation.landscapeRight) {
            r=CGRect(x: size.width-(b.width), y: size.height/2 - (b.width/2), width: b.height, height: b.width)
        }
        else {
            r=CGRect(x: (size.width/2) - (b.width/2),y: size.height-b.height,width: b.height,height: b.width)
            
        }
        //print("r is \(r) against \(size)")
        return r
    }
    override func viewWillAppear(_ animated: Bool) {
        let rr=UIApplication.shared.keyWindow?.rootViewController as! NavControllerNoRoate
        rr.allowRotate=false
        super.viewWillAppear(true)
    }
    
    override var shouldAutorotate : Bool {
        return false
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        
        if captureDelegate?.recording==false {
            //self.updateOrientation()
//            coordinator.animateAlongsideTransition({ (context) -> Void in
//                //print("Setting record button transition")
//                self.record.recordButton.frame=self.positionRecord(size)
//                }, completion:  nil)
        //   super.viewWillTransitionToSize(size, withTransitionCoordinator: coordinator)
        }
//        else {
//            //this is an undesirable situation...
//            let rr=UIApplication.sharedApplication().keyWindow?.rootViewController as! NavControllerNoRoate
//            rr.allowRotate=false
//        }
    }
    func captureData(_ captureSession:AVCaptureSession,device:AVCaptureDevice) {
        dataOutput!.alwaysDiscardsLateVideoFrames = false
        dataOutput!.videoSettings=pixBuffAttributesPlanar
        captureDelegate=CaptureBufferDelegate(v: self.viewIfLoaded!,d:device)

        dataOutput!.setSampleBufferDelegate(captureDelegate, queue: DispatchQueue.main)
        if (captureSession.canAddOutput(dataOutput)) {
            captureSession.addOutput(dataOutput)
            captureSession.commitConfiguration()
        }
        else {
            print("nope can't add output")
        }
        self.updateOrientation()
    }
    
    func setDefaultOrientation() {
        for connection in dataOutput!.connections as! [AVCaptureConnection] {
            if connection.isVideoOrientationSupported {
                connection.videoOrientation = .landscapeRight
                //print("Connection orientation is \(connection.videoOrientation.rawValue) to \(AVCaptureVideoOrientation.Portrait.rawValue)")
            }
        }
    }
    
    func updateOrientation() {
        for connection in dataOutput!.connections as! [AVCaptureConnection] {
            if connection.isVideoOrientationSupported {
                connection.videoOrientation = transformOrientation()
            }
        }
    }
    func transformOrientation() -> AVCaptureVideoOrientation {
        let f=UIDevice.current.orientation
        switch f {
        case .landscapeLeft:
            //print("Landscape Left")
            return .landscapeRight
        case .landscapeRight:
            //print("Landscape Right")
            return .landscapeLeft
        case .portraitUpsideDown:
            //print("Portrait Update Down")
            return .portraitUpsideDown
        default:
            //print("Set to Portrait")
            return .portrait
        }
    }
    
    func setStabilization(_ dataOutput:AVCaptureVideoDataOutput,device:AVCaptureDevice) {
        if device.activeFormat.isVideoStabilizationModeSupported(AVCaptureVideoStabilizationMode.cinematic ) {
            dataOutput.connection(withMediaType: AVMediaTypeVideo).preferredVideoStabilizationMode=AVCaptureVideoStabilizationMode.cinematic
        }
        else if device.activeFormat.isVideoStabilizationModeSupported(AVCaptureVideoStabilizationMode.standard ) {
            dataOutput.connection(withMediaType: AVMediaTypeVideo).preferredVideoStabilizationMode=AVCaptureVideoStabilizationMode.standard
        }
    }
    
    func defaultConfiguration(_ device:AVCaptureDevice,prevLayer:AVCaptureVideoPreviewLayer) {
        do {
            try device.lockForConfiguration()
            if (device.isWhiteBalanceModeSupported(AVCaptureWhiteBalanceMode.autoWhiteBalance)==true) {
                device.whiteBalanceMode=AVCaptureWhiteBalanceMode.autoWhiteBalance
            }
            if device.isSmoothAutoFocusSupported {
                device.isSmoothAutoFocusEnabled = false
            }
            if (device.isLowLightBoostSupported==true) {
                device.automaticallyEnablesLowLightBoostWhenAvailable=true
            }
            device.focusMode=AVCaptureFocusMode.continuousAutoFocus
            
            let a=device.activeFormat.videoSupportedFrameRateRanges
            //print("supported ranges:")
            //print(a)
            device.activeVideoMinFrameDuration=CMTimeMake(1, 24)
            device.activeVideoMaxFrameDuration=CMTimeMake(1, 24)
            device.automaticallyAdjustsVideoHDREnabled=true
            device.unlockForConfiguration()
        }
        catch {
            print(error)
        }
    }
    
    func outputConfiguration(_ device:AVCaptureDevice,prevLayer:AVCaptureVideoPreviewLayer) {
        var stab=""
        var preferstab=""
        let connection=dataOutput!.connection(withMediaType: AVMediaTypeVideo)
        if connection?.activeVideoStabilizationMode.rawValue==AVCaptureVideoStabilizationMode.standard.rawValue {
            stab="Standard"
        }
        else if connection?.activeVideoStabilizationMode.rawValue==AVCaptureVideoStabilizationMode.cinematic.rawValue {
            stab="Cinematic"
        }
        else if connection?.activeVideoStabilizationMode.rawValue==AVCaptureVideoStabilizationMode.off.rawValue {
            stab="Off"
        }
        if connection?.preferredVideoStabilizationMode.rawValue==AVCaptureVideoStabilizationMode.standard.rawValue {
            preferstab="Standard"
        }
        else if connection?.preferredVideoStabilizationMode.rawValue==AVCaptureVideoStabilizationMode.cinematic.rawValue {
            preferstab="Cinematic"
        }
        else if connection?.preferredVideoStabilizationMode.rawValue==AVCaptureVideoStabilizationMode.off.rawValue {
            preferstab="Off"
        }
        print("AutoHDR:\(device.automaticallyAdjustsVideoHDREnabled)\nWB:\(device.whiteBalanceMode.rawValue)\nactiveVideoStabilizationMode:\(stab) Preferred:\(preferstab)  ")
    }

    
    
    var applicationDocumentsDirectory:URL {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).last!
    }
    func showCameraPermissionAlert() {
        let alertController = UIAlertController(
            title: "Camera Permission Denied",
            message: "You have not allowed access to the camera.",
            preferredStyle: .alert)
        
        let defaultAction = UIAlertAction(title: "OK", style: .default, handler: nil)
        
        alertController.addAction(defaultAction)
        self.camera.present(alertController, animated: true, completion: nil)
    }
    func showMicrophonePermissionAlert() {
        let alertController = UIAlertController(
            title: "Microphone Permission Denied",
            message: "You have not allowed access to the microphone.",
            preferredStyle: .alert)
        
        let defaultAction = UIAlertAction(title: "OK", style: .default, handler: nil)
        
        alertController.addAction(defaultAction)
        self.camera.present(alertController, animated: true, completion: nil)
    }
    func showUnknownErrorAlert() {
        let alertController = UIAlertController(
            title: "Unknown Error",
            message: "An unknown error has occurred with the camera.",
            preferredStyle: .alert)
        
        let defaultAction = UIAlertAction(title: "OK", style: .default, handler: nil)
        
        alertController.addAction(defaultAction)
        self.camera.present(alertController, animated: true, completion: nil)
    }
}
