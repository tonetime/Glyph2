import UIKit
import AVFoundation

class VideoPlayerViewController: UIViewController, UIGestureRecognizerDelegate {
    
    var videoUrl:URL!
    var player:LoopPlayerView!
    var staticMovie:URL?

    fileprivate var sliderView:MySlider!
    fileprivate var navbar:UINavigationBar!
    var tmpFilmURL:URL {
        let tempDir = NSTemporaryDirectory()
        let url = URL(fileURLWithPath: tempDir).appendingPathComponent("tmp2.mp4")
        return url
    }
    
    override var shouldAutorotate : Bool {
        return false
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = UIColor.black
        self.navigationController?
            .setNavigationBarHidden(true, animated: false)
        let bounds=UIScreen.main.bounds
        self.player=LoopPlayerView(frame: bounds)
        if staticMovie != nil {
            self.player.setPlayer(AVPlayer(url: staticMovie!))
        }
        else {
            self.player.setPlayer(AVPlayer(url: tmpFilmURL))
        }
        self.view.addSubview(player)

        self.addSlider()
        self.addNavigation()
        self.player.player().play()
    
    }
    
    fileprivate func addNavigation() {
        let screenRect = UIScreen.main.bounds
        let r=CGRect(x: 0,y: 0,width: screenRect.width,height: 50)
        navbar=UINavigationBar.init(frame: r)
        navbar.tag=1
        navbar.setBackgroundImage(UIImage.init(), for: UIBarMetrics.default)
        navbar.shadowImage=UIImage.init()
        navbar.isTranslucent=true
        let item=UINavigationItem.init()
        
//        let backButton=UIBarButtonItem.init(title: "<", style: UIBarButtonItemStyle.Plain, target: self, action: #selector(VideoPlayerViewController.backButtonPressed))
        let i=Bundle.main.url(forResource: "back44", withExtension: "png")
        let ui = UIImage(data: try! Data(contentsOf: i!))
        let backButton=UIBarButtonItem(image: ui, style: UIBarButtonItemStyle.plain, target: self, action: #selector(VideoPlayerViewController.backButtonPressed))
        item.leftBarButtonItems=[backButton]
        
        let i2=Bundle.main.url(forResource: "forward44", withExtension: "png")
        let ui2 = UIImage(data: try! Data(contentsOf: i2!))
        let forwardButton=UIBarButtonItem(image: ui2, style: UIBarButtonItemStyle.plain, target: self, action: #selector(VideoPlayerViewController.forwardButtonPressed))
        item.rightBarButtonItems=[forwardButton]
        navbar.items?=[item]
        self.view.addSubview(navbar)
    }
    @objc fileprivate func backButtonPressed() {
        print("Pressed it yo!")
        let cv=CameraViewController()
        self.navigationController?.pushViewController(cv, animated: true)
    }
    
    @objc fileprivate func forwardButtonPressed() {
        
    }
    
    fileprivate func addSlider() {
        let screenRect = UIScreen.main.bounds
        let sliderW=round(screenRect.width*0.95)
        let sliderBottom=round(screenRect.height*0.88)
        let sliderL=round(screenRect.width-round(screenRect.width*0.95))/2
//        print("\(sliderW) \(sliderL) \(screenRect) \(sliderBottom)")
        sliderView=MySlider(frame: CGRect(x: sliderL,y: sliderBottom,width: sliderW,height: 100), loopPlayer: self.player)
        self.view.addSubview(sliderView)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        let rr=UIApplication.shared.keyWindow?.rootViewController as! NavControllerNoRoate
        rr.allowRotate=false
        super.viewWillAppear(animated)
    }
}







