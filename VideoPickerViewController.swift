import UIKit
import AVFoundation
import MobileCoreServices

class VideoPickerViewController: UIViewController,UINavigationControllerDelegate,UIImagePickerControllerDelegate {
    
//    override func viewWillAppear(animated: Bool) {
//        print("view will appear")
//        UIDevice.currentDevice().setValue(UIInterfaceOrientation.Portrait.rawValue, forKey: "orientation")
//        super.viewWillAppear(animated)
//
//    }
    override func viewDidLoad() {
      //  UIDevice.currentDevice().setValue(UIInterfaceOrientation.Portrait.rawValue, forKey: "orientation")

        super.viewDidLoad()

        if self.navigationController != nil {
            let q = self.navigationController as? NavControllerNoRoate
            print(q?.allowRotate)
        }
        
        
        let v=Bundle.main.loadNibNamed("VideoPicker", owner: nil, options: nil)?[0] as! UIView
      //  v.frame=UIScreen.mainScreen().bounds
      //  v.frame=UIScreen.mainScreen().nativeBounds
        let r=CGRect(x: 0, y: 0, width: 414, height:736)
        v.frame=r
        self.view.frame=r
        print(UIScreen.main.nativeBounds)
        print(UIScreen.main.bounds)
        self.view.addSubview(v)
        UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")

    }
    override var preferredInterfaceOrientationForPresentation : UIInterfaceOrientation {
        return .portrait
    }
    override var shouldAutorotate : Bool {
        return false
    }
//    override func supportedInterfaceOrientations() -> UIInterfaceOrientationMask {
//        return UIInterfaceOrientationMask.Portrait
//    }
    override var prefersStatusBarHidden : Bool {
        return true
    }
    
    
     @IBAction func picker(_ sender: UIButton) {
        let videoPicker=UIImagePickerController()
        videoPicker.delegate=self
        videoPicker.sourceType=UIImagePickerControllerSourceType.photoLibrary
        videoPicker.mediaTypes = [String(kUTTypeMovie)]
        videoPicker.videoMaximumDuration=10.0
        videoPicker.allowsEditing=true
        videoPicker.videoQuality=UIImagePickerControllerQualityType.typeHigh
        present(videoPicker, animated: true, completion: nil)

    }
    @IBAction func inspiration(_ sender: UIButton) {
        print("Insipre yo")
        let p=self.parent as! NavControllerNoRoate
        p.goToYourGlyphs()
    }
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        let f = info[UIImagePickerControllerMediaURL] as! URL
        self.dismiss(animated: false, completion: {})
        let p=self.parent as! NavControllerNoRoate
        p.goToPostProcessController(f)
    }
    @IBAction func recordVideo(_ sender: UIButton) {        
        let p=self.parent as! NavControllerNoRoate
        p.goToCameraView()        
    }
}
