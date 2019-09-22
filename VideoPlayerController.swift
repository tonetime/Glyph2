
import UIKit
import AVFoundation
import Photos



class VideoPlayerController: UIViewController, UIPageViewControllerDataSource {
    
    @IBOutlet weak var gestureView: UIView!
    @IBOutlet weak var navbar3: UINavigationBar!
    
    private var currentIndex=0
    fileprivate var pageViewController : PageViewController!
    let bundle=Bundle.main
    
    let u1=Bundle.main.url(forResource: "moulin480", withExtension: "mov")
    let u2=Bundle.main.url(forResource: "churchsmall", withExtension: "m4v")
    let u4=Bundle.main.url(forResource: "EffelTower480", withExtension: "mov")

    let u3=URL(string: "http://techslides.com/demos/sample-videos/small.mp4")
    
    //var URLs = ["http://www.html5videoplayer.net/videos/toystory.mp4", "http://clips.vorwaerts-gmbh.de/big_buck_bunny.mp4", "http://techslides.com/demos/sample-videos/small.mp4"]
    //var URLs = [URL]()
    var URLs  = [Any]()
    
    override var prefersStatusBarHidden : Bool {
        return true
    }
    func loadURLs() {
        self.URLs = Utilities.getAssetsInAlbum(albumName: "Glyph")
        self.URLs.append(u1)
        self.URLs.append(u2)
        self.URLs.append(u4)
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        //self.URLs=[u3!,u2!,u1!]
        self.loadURLs()
        
        
        
        pageViewController = self.storyboard?.instantiateViewController(withIdentifier: "pagevc") as! PageViewController
        pageViewController.dataSource = self
        
        let startingvc = self.viewControllerAtIndex(0)
        let viewControllers = [startingvc!]
        
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(VideoPlayerController.handleTap(_:)))
        let swipeRecognizerLeft=UISwipeGestureRecognizer(target: self, action: #selector(VideoPlayerController.handleSwipe(_:)))
        swipeRecognizerLeft.direction =  UISwipeGestureRecognizerDirection.left
        let swipeRecognizerRight=UISwipeGestureRecognizer(target: self, action: #selector(VideoPlayerController.handleSwipe(_:)))
        swipeRecognizerRight.direction =  UISwipeGestureRecognizerDirection.right
        
        
        self.gestureView.addGestureRecognizer(tapRecognizer)
        self.gestureView.addGestureRecognizer(swipeRecognizerLeft)
        self.gestureView.addGestureRecognizer(swipeRecognizerRight)
        
        self.pageViewController.setViewControllers(viewControllers, direction: .forward, animated: true, completion: nil)
        self.updateTitle()
        self.addChildViewController(pageViewController)
        self.view.insertSubview(pageViewController.view, at: 0)
        self.pageViewController.didMove(toParentViewController: self)
    }
    @objc fileprivate func handleTap(_ sender: UITapGestureRecognizer) {
        self.navbar3.isHidden = !self.navbar3.isHidden
    }
    @objc fileprivate func handleSwipe(_ sender: UISwipeGestureRecognizer) {
        if sender.direction == .left {
            self.currentIndex+=1
            if self.currentIndex >= (self.URLs.count) {
                self.currentIndex=0
            }
            let qq=self.viewControllerAtIndex(self.currentIndex)
            pageViewController.setViewControllers([qq!], direction: .forward, animated: true, completion: nil)
        }
        if sender.direction == .right {
            self.currentIndex -= 1
            if (self.currentIndex < 0) {
                self.currentIndex = self.URLs.count - 1
            }
            let qq=self.viewControllerAtIndex(self.currentIndex)
            pageViewController.setViewControllers([qq!], direction: .reverse, animated: true, completion: nil)
        }
        self.updateTitle()
    }
    @IBAction func backButton(_ sender: AnyObject) {
        let p=self.parent as! NavControllerNoRoate
        p.goToVideoPickerViewController()
    }
    func updateTitle() {
        self.navbar3.topItem?.title="\(self.currentIndex+1) of \(self.URLs.count)"
        //self.navbar3.topItem?.title="GLYPHS"
    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        var index = (viewController as! PlayerViewController).pageIndex!
        if index == 0 || index == NSNotFound{
            return nil
        }
        index -= 1
        return self.viewControllerAtIndex(index)
    }
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        var index = (viewController as! PlayerViewController).pageIndex!
        if index == NSNotFound{
            return nil
        }
        index += 1
        return self.viewControllerAtIndex(index)
    }
    func presentationCount(for pageViewController: UIPageViewController) -> Int {
        return 0
    }
    func presentationIndex(for pageViewController: UIPageViewController) -> Int {
        return 0
    }
    fileprivate func viewControllerAtIndex(_ index : Int) -> PlayerViewController?{
        let playervc = self.storyboard?.instantiateViewController(withIdentifier: "pagecontent") as! PlayerViewController
        playervc.pageIndex = index
        let u = URLs[index]
        if let u = URLs[index] as? URL {
            playervc.videoURL = u
        }
        else {
            PHImageManager.default().requestAVAsset(forVideo: (u as? PHAsset)!, options: nil, resultHandler: {avAsset,_,_ in
                //print("^ my god apple \(avAsset)")
                playervc.setAVAsset(asset: avAsset!)
            })
        }
        return playervc
    }
}

