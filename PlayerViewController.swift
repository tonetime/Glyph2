//
//  PlayerViewController.swift
//  VideoPageView
//
//  Created by Ethan Fan on 9/3/15.
//  Copyright © 2015 Ethan Fan. All rights reserved.
//

import UIKit
import AVFoundation
import AVKit

class PlayerViewController: AVPlayerViewController {
    
    var pageIndex : Int!
    var videoURL : URL?
    var obs:NSObjectProtocol?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.showsPlaybackControls=false
        if videoURL != nil {
            player = AVPlayer(url: videoURL!)
            self.setupObserver()
        }
    }
    deinit {
        self.player?.pause()
        NotificationCenter.default.removeObserver(self.obs)
    }
    func setAVAsset(asset:AVAsset) {
        self.player=AVPlayer(playerItem: AVPlayerItem(asset: asset))
        self.setupObserver()
    }
    func setupObserver() {
        self.obs=NotificationCenter.default.addObserver(forName: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: player?.currentItem, queue: nil)
        { [weak self] notification in
            self!.player?.pause()
            let s=CMTimeMakeWithSeconds(Float64(0),600)
            self!.player?.seek(to: s, toleranceBefore: kCMTimeZero, toleranceAfter: kCMTimeZero,
                               completionHandler: { (result) -> Void in
                                self!.player?.play()
            })
        }
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        player!.play()
    
    }
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.player!.pause()
    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
        player = nil
    }
}
