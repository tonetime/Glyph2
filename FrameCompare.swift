import Foundation

class FrameCompare {
    let maxFrames=300
    let matchThreshold=UInt64(3)
    let osdhash:OSDHash
    var hashes:[OSHashType]=[]
    var distances:[Dictionary<String,Any>]=[]  //[frames:[0,1], distance:12]
    static let recommenedFrameDistance=21  //e.g. don't look for matches less than 21 frames apart.
    var frameCompareQueue:OperationQueue = {
        var queue = OperationQueue()
        queue.name = "frameCompareQueue"
        //queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = .utility
        return queue
    }()
    
    static let sharedInstance=FrameCompare()
    init() {
        osdhash=OSDHash.init()
    }
    func addImage(_ image:UIImage) ->Int {
        if (hashes.count > maxFrames) {
            print("Cannot add any more hashes!")
            return -1
        }
        let h=osdhash.hashImage(image)
        hashes.append(h)
        return hashes.count-1
    }
    func addImageAndCalcDistance(_ image:UIImage, dispatchToAsyncQ:Bool=true,
        minimumFrameDistance:Int=recommenedFrameDistance) {
            let frame=self.addImage(image)
            if (frame > 0) {
                if (dispatchToAsyncQ) {
                    frameCompareQueue.addOperation { () -> Void in
                        self.calcDistanceForFrameIndex(frame,
                            minimumDistance: minimumFrameDistance)
                    }
                }
                else {
                    self.calcDistanceForFrameIndex(frame,
                        minimumDistance: minimumFrameDistance)
                }
            }
    }
    func calcDistanceForFrameIndex(_ index:Int,
        minimumDistance:Int=recommenedFrameDistance) {
            //print("index:\(index) minDist:\(minimumDistance)")
            let startFrame=hashes[index]
            let startCompare=index-minimumDistance
            if (startCompare > 0) {
                for frameIndex in stride(from: startCompare, to: 0, by: -1) {
                    let f=hashes[frameIndex]
                    let dist=osdhash.hashDistance(startFrame,to:f)
                    let distDict:[String:Any]=["hashDistance":dist,
                        "startFrame":startFrame,
                        "compareFrame":f,
                        "frameDistance":(index-frameIndex),
                        "frames":[index,frameIndex]]
                    distances.append(distDict)
                    //print(distDict)
                }
            }
    }
    func getBestMatches() -> [[String:Any]] {
        var d = distances.sorted {
            item1,item2 in
            let h1=item1["hashDistance"] as! UInt64
            let h2=item2["hashDistance"] as! UInt64
            let fd1=item1["frameDistance"] as! Int
            let fd2=item2["frameDistance"] as! Int
            if (h1==h2) {
                return fd1 > fd2
            }
            else {
                return h1 < h2
            }
        }
        d=d.filter { (item) in (item["hashDistance"] as! UInt64) <= matchThreshold }
        return d
    }
    func reset() {
        hashes.removeAll()
        distances.removeAll()
        frameCompareQueue.cancelAllOperations()
    }
}
