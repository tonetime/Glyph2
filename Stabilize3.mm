#include <iostream>
#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "Points.h"
#import "OpenCV.h"
#import "FrameFeature.h"
#import "Stabilize3.h"
#import "StatusWrapper.h"
#import "NSArray+Statistics.h"
#import "Trim.hpp"
#import "CEMovieMaker.h"

@implementation Stabilize3  {
    cv::Mat startingMat;
    std::vector<cv::Point2f> startPoints;
    std::vector<cv::Point2f> originalStartingPoints;

    std::vector<cv::Mat>  startingPyramid;
    std::vector<cv::Mat>  currentPyramid;
    std::vector<cv::Mat>  transforms;
    Trim trim;
    int maxCorners;
    int frameCount;
    int skippedFrames;
    float maxTrim;
    float scaleFactor;
    dispatch_queue_t queue;
    dispatch_group_t goodPointsGroup;
    dispatch_group_t opticalFlowGroup;
    NSMutableArray *frames;
    Points *startingPoints;
    std::vector<PyramidHold> pyramids;
    std::vector< std::vector <cv::Point2f>>  reducedPoints;
    cv::Size frameSize;
    cv::Size realFrameSize;
    EAGLContext *myEAGLContext;
    CIContext *context;
    NSArray *stdMask;
    NSArray *offsetMask;
}


static Stabilize3  *sharedInstance = nil;
// Get the shared instance and create it if necessary.
+ (Stabilize3 *)sharedInstance {
    if (sharedInstance == nil) {
        sharedInstance = [[Stabilize3 alloc] init];
    }
    return sharedInstance;
}

+ (void)resetSharedInstance {
    sharedInstance = nil;
}

- (void) cleanUp {
    pyramids.clear();
    reducedPoints.clear();
    pyramids.shrink_to_fit();
    reducedPoints.shrink_to_fit();
    self->context=nil;
    self->myEAGLContext=nil;
    self->queue=nil;
}


- (id) init {
    self->queue=dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    self.frameFeatures=[[NSMutableArray alloc] init];
    self->scaleFactor=0.5;
    self.postProcessDone=false;
    self->myEAGLContext= [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    self->context=[CIContext contextWithEAGLContext:self->myEAGLContext options: @{kCIContextWorkingColorSpace:[NSNull null]} ];
    maxCorners=500;
    frameCount=0;
    skippedFrames=0;
    maxTrim=0;
    self->pyramids.reserve(1024*1024);
    self->goodPointsGroup=dispatch_group_create();
    self->opticalFlowGroup=dispatch_group_create();
    self->startingPoints=[[Points alloc] init];
    return self;
}
-(NSArray *) processVideo:(NSURL *) url andSaveImages:(bool) saveImages {
    NSMutableArray *images= [[NSMutableArray alloc] init];
    int ccc=0;
    AVAsset *asset = [AVURLAsset URLAssetWithURL:url options:nil];
    AVAssetReader *assetReader = [[AVAssetReader alloc] initWithAsset:asset error:NULL];
    AVAssetTrack *videoTrack = [[asset tracksWithMediaType:AVMediaTypeVideo] firstObject];
    NSDictionary *outputSettings = @{(__bridge NSString *)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_420YpCbCr8Planar)};
    //NSDictionary *outputSettings = @{(__bridge NSString *)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA)};
    AVAssetReaderTrackOutput *assetReaderOutput=[[AVAssetReaderTrackOutput alloc] initWithTrack:videoTrack outputSettings:outputSettings];
    assetReaderOutput.alwaysCopiesSampleData=false;
    [assetReader addOutput:assetReaderOutput];
    [assetReader startReading];
    CMSampleBufferRef sample=[assetReaderOutput copyNextSampleBuffer];
    while (sample != nil) {
        long long m1 = (long long)([[NSDate date] timeIntervalSince1970] * 1000.0);
        UIImage *i=nil;
        //if ((ccc==0 || ccc==150 || ccc==200)) {
            i=[self processFrame:sample andSaveImages:saveImages];
        //}
        long long m2 = (long long)([[NSDate date] timeIntervalSince1970] * 1000.0);
        //NSLog(@"Time to process frame %llu ms", (m2-m1));
        CFRelease(sample);
        sample=[assetReaderOutput copyNextSampleBuffer];
        if (saveImages && ccc < 100 && i != nil) {
            [images addObject:i];
        }
        ccc++;
    }
    return images;
}

-(NSArray *) processVideo:(NSArray *) images {
    for (id image in images) {
        cv::Mat img;
        UIImageToMat(image, img);
        cv::Mat grayMat;
        cv::cvtColor(img, grayMat, CV_BGR2GRAY);
        [self processFrameMat:grayMat];
    }
    return nil;
}

//assuming a planar buffer.
- (UIImage *) processFrame:(CMSampleBufferRef) ref andSaveImages:(bool) saveImages {
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(ref);
    CVPixelBufferLockBaseAddress(imageBuffer, kCVPixelBufferLock_ReadOnly);
    void *grayscalePixels = CVPixelBufferGetBaseAddressOfPlane(imageBuffer, 0);
    int bufferWidth = (int)CVPixelBufferGetWidth(imageBuffer);
    int bufferHeight = (int)CVPixelBufferGetHeight(imageBuffer);
    cv::Mat grayMat = cv::Mat(bufferHeight,bufferWidth,CV_8UC1,grayscalePixels); //put buffer in open cv, no memory copied
   // long long m1 = (long long)([[NSDate date] timeIntervalSince1970] * 1000.0)
    [self processFrameMat:grayMat];
    //long long m2 = (long long)([[NSDate date] timeIntervalSince1970] * 1000.0);
    //NSLog(@"Time to resize %llu ms", (m2-m1));
    CVPixelBufferUnlockBaseAddress(imageBuffer, kCVPixelBufferLock_ReadOnly);
    grayMat.release();
    //scaledMat.release();
    return nil;
}



static std::vector<cv::Point2f> adjustPoints(std::vector<cv::Point2f> points, float scaleFactor) {
    std::vector<cv::Point2f> newPoints;
    
    for (int i=0; i < points.size();i++) {
        cv::Point2f p=points[i];
        float nx= p.x * (1/scaleFactor);
        float ny= p.y * (1/scaleFactor);
        // std::cout << "x was:" << p.x << " now: " << nx << " y was:" << p.y << " now:" << ny << "\n";
        cv::Point2f np=cv::Point2f(nx,ny);
        newPoints.push_back(np);
    }
    return newPoints;
}
- (void)processFrameMat:(cv::Mat )mat {
    if (scaleFactor != 1.0) {
        cv::Mat scaledMat;
        cv::Size scaledSize=cv::Size(mat.cols*scaleFactor,mat.rows*scaleFactor);
        cv::resize(mat, scaledMat, scaledSize);
        mat=scaledMat;
    }
    if (self->frameSize.height==0) {
        self->frameSize=cv::Size(mat.cols, mat.rows);
        if (scaleFactor != 1.0) {
            realFrameSize=cv::Size(frameSize.width*(1/scaleFactor), frameSize.height*(1/scaleFactor));
        }
        else {
            realFrameSize=frameSize;
        }
    }
    if (frameCount==0) {
        startingMat=mat.clone();
       dispatch_group_async(goodPointsGroup, queue, ^{
            long long m1 = (long long)([[NSDate date] timeIntervalSince1970] * 1000.0);
            cv::buildOpticalFlowPyramid(self->startingMat, self->startingPyramid,cv::Size(21,21), 3);
            //self->startPoints=[self goodFeaturesToTrack:self->startingMat];
           self->originalStartingPoints=[self goodFeaturesToTrack:self->startingMat];
          // self->startPoints=[self adjustPointsToScale:self->originalStartingPoints];
           self->startPoints=adjustPoints(self->originalStartingPoints, scaleFactor);
            self->startingMat.release();
            self->startingMat=NULL;
            [startingPoints setPoints:startPoints];
            long long m2 = (long long)([[NSDate date] timeIntervalSince1970] * 1000.0);
            //std::cout << self->startPoints.size() <<"\n";
            NSLog(@"Time to build startingPyramid and get starting features: %llu ms", m2-m1);
        });
    }   
    else {
        std::vector<cv::Mat> cc;
        long long m1 = (long long)([[NSDate date] timeIntervalSince1970] * 1000.0);
        cv::buildOpticalFlowPyramid(mat, cc,cv::Size(21,21), 3);
        PyramidHold p=PyramidHold(frameCount, cc);
        @synchronized(self) {
            //std::cout <<"Pyramids size:" << pyramids.size() << "\n";
            self->pyramids.push_back(p);
        }
        dispatch_group_async(opticalFlowGroup, queue, ^{
            dispatch_group_wait(goodPointsGroup, DISPATCH_TIME_FOREVER);
            long long mm1 = (long long)([[NSDate date] timeIntervalSince1970] * 1000.0);

            PyramidHold pp;
            @synchronized(self) {
                if (self->pyramids.size() >0) {
                    pp=self->pyramids.back();
                    self->pyramids.pop_back();
                    //NSLog(@"Just popeed a pyramid");
                }
            }
            std::vector<cv::Point2f> pts(maxCorners);
            std::vector<unsigned char> status;
            std::vector<float> errors;


            cv::calcOpticalFlowPyrLK(startingPyramid, pp.pyramid, originalStartingPoints, pts, status, errors);
            pp.pyramid.clear();
            pp.pyramid.shrink_to_fit();
            
            StatusWrapper *s=[[StatusWrapper alloc] init];
            [s setFstatus:status];
            Points *p1=[[Points alloc] init];
            pts=adjustPoints(pts, scaleFactor);
            [p1 setPoints:pts];
            FrameFeature * f=[[FrameFeature alloc] initWithFeatureData:p1 andStartingPoints:startingPoints andPointStatus:s andFrameIndex:pp.indx];
            //f.distances= [FrameFeature calcDistanceForPoints:f.points a:f.startingPoints];
            [self.frameFeatures addObject:f];
            long long mm2 = (long long)([[NSDate date] timeIntervalSince1970] * 1000.0);
            if (frameCount % 50 ==0 ){
               NSLog(@"Time to calcOpticalFlow: %llu ms", mm2-mm1);
            }
        });
        
        long long m2 = (long long)([[NSDate date] timeIntervalSince1970] * 1000.0);
        if (frameCount % 50 == 0 ) {
            NSLog(@"Build current opt pyramid: %llu ms", m2-m1);
        }
    }
    frameCount++;
}

- (void) postProcess {
    dispatch_group_wait(opticalFlowGroup, DISPATCH_TIME_FOREVER);
    if (self.postProcessDone==true) {
        NSLog(@"Post process already done!");
        return;
    }
    if ([self.frameFeatures count]==0) {
        NSLog(@"No frames have been processed!");
        return;
    }
    long long m1 = (long long)([[NSDate date] timeIntervalSince1970] * 1000.0);
    
    NSArray *sortedArray = [self.frameFeatures sortedArrayUsingSelector:@selector(compare:)];
    self.frameFeatures=sortedArray;
    
    [self calculateDistances];
    
    
    //wait for queue to finish->
    self->stdMask=[self stdDeviationMask];   //might be able to do this in real time as well.  When deviation hits a threshold it's flagged.
    self->offsetMask=[Stabilize3 calcOffscreenMask:self.frameFeatures];  //this could be done in real time..
    self->reducedPoints=[self getReducedPoints];
    NSLog(@"Total Frames: %i", self->reducedPoints.size());
    self.postProcessDone=true;
    [self calcTransforms];
    long long m2 = (long long)([[NSDate date] timeIntervalSince1970] * 1000.0);
    NSLog(@"Time to post process %i ms", m2-m1);
}

- (float) skippedFramesPct {
    return float(skippedFrames)/float(frameCount);
}

- (NSArray *) applyVideoTransformCI:(NSURL *) sourceUrl  andMovie:(CEMovieMaker *) movie andShowPoints:(bool) showPoints {
    long long m1 = (long long)([[NSDate date] timeIntervalSince1970] * 1000.0);
    int fCount=0;
    if (movie) {
        [movie startWriter];
    }
    NSMutableArray *transformedImages=[[NSMutableArray alloc] init];
    if (self.postProcessDone==false) {
        NSLog(@"Need to post processes!");
        return transformedImages;
    }
    AVAsset *asset = [AVURLAsset URLAssetWithURL:sourceUrl options:nil];
    AVAssetReader *assetReader = [[AVAssetReader alloc] initWithAsset:asset error:NULL];
    AVAssetTrack *videoTrack = [[asset tracksWithMediaType:AVMediaTypeVideo] firstObject];
    NSDictionary *outputSettings = @{(__bridge NSString *)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA)};
    AVAssetReaderTrackOutput *assetReaderOutput=[[AVAssetReaderTrackOutput alloc] initWithTrack:videoTrack outputSettings:outputSettings];
    assetReaderOutput.alwaysCopiesSampleData=false;
    [assetReader addOutput:assetReaderOutput];
    [assetReader startReading];
    CMSampleBufferRef sample=[assetReaderOutput copyNextSampleBuffer];
    while (sample != nil) {
        CVImageBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sample);
        CVPixelBufferLockBaseAddress( pixelBuffer, 0 );
        int bufferWidth = (int)CVPixelBufferGetWidth(pixelBuffer);
        int bufferHeight = (int)CVPixelBufferGetHeight(pixelBuffer);
        unsigned char *pixel = (unsigned char *)CVPixelBufferGetBaseAddress(pixelBuffer);
        cv::Mat image = cv::Mat(bufferHeight,bufferWidth,CV_8UC4,pixel);

        @autoreleasepool {
            CIImage *cii = [CIImage imageWithCVPixelBuffer:pixelBuffer];
            UIImage *outputImage;
            CGImageRef resultRef;
            if (fCount !=0 ) {
                cv::Mat transform=self->transforms[fCount-1];
                cv::Mat transInv;
                cv::invertAffineTransform(transform, transInv);
                CGAffineTransform tt=convertToCGAffine(transInv);
                cii=[cii imageByApplyingTransform:tt];
                
                CGRect r2= CGRectMake(1, -62, realFrameSize.width, realFrameSize.height);
                resultRef = [context createCGImage:cii fromRect:r2];
                
                //UIImage *ou2 = [UIImage imageWithCGImage:resultRef];
                //outputImage=[self imageWithImage:ou2 scaledToSize:CGSizeMake(realFrameSize.width, realFrameSize.height)];
            
               // NSLog(@"look x:%f y:%f", ci2.extent.origin.x, ci2.extent.origin.y);
                //NSLog(@"ou2 %@ and w:%f h:%f",ou2, ci2.extent.size.width, ci2.extent.size.height);
            }
            else {
                CGRect r2=CGRectMake(0, 0, realFrameSize.width, realFrameSize.height);
                resultRef = [context createCGImage:cii fromRect:r2];
            }
            
            trimFrameCopy(maxTrim, image);
            CGRect r2=CGRectMake(0, 0, realFrameSize.width, realFrameSize.height);

            CGRect trimTo=[Stabilize3 trimFrameRect:maxTrim andRect:r2];
            resultRef=CGImageCreateWithImageInRect(resultRef, trimTo);
            
            if (fCount==0) {
                resultRef=[self scaleImage:resultRef scaledToSize:CGSizeMake(1279, 720)];
                
                outputImage = [UIImage imageWithCGImage:resultRef];
                [movie appendImage:outputImage];
            }
        }
        image.release();
        CVPixelBufferUnlockBaseAddress( pixelBuffer, 0 );
        CFRelease(sample);
        sample=[assetReaderOutput copyNextSampleBuffer];
        fCount++;
    }
    long long m2 = (long long)([[NSDate date] timeIntervalSince1970] * 1000.0);
    NSLog(@"Time to encode video %llu ms", (m2-m1));
    return transformedImages;
}


- (NSArray *) applyVideoTransform:(NSURL *) sourceUrl  andMovie:(CEMovieMaker *) movie andShowPoints:(bool) showPoints {


    long long m1 = (long long)([[NSDate date] timeIntervalSince1970] * 1000.0);
    int fCount=0;
    if (movie) {
        [movie startWriter];
    }
    NSMutableArray *transformedImages=[[NSMutableArray alloc] init];
    if (self.postProcessDone==false) {
        NSLog(@"Need to post processes!");
        return transformedImages;
    }
    //INTER_LINEAR OK? FAST
    //INTER_LANCZOS4  OK SLOW 20S
    //INTER_NEAREST HORRIBLE  9.6S
    //INTER_AREA  OK?  9.3ms
    //INTER_CUBIC OK 11.8MS
    
    int flags =  cv::INTER_LINEAR |  cv::WARP_INVERSE_MAP;
    //int flags=cv::WARP_INVERSE_MAP;
    AVAsset *asset = [AVURLAsset URLAssetWithURL:sourceUrl options:nil];
    AVAssetReader *assetReader = [[AVAssetReader alloc] initWithAsset:asset error:NULL];
    AVAssetTrack *videoTrack = [[asset tracksWithMediaType:AVMediaTypeVideo] firstObject];
    NSDictionary *outputSettings = @{(__bridge NSString *)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA)};
    AVAssetReaderTrackOutput *assetReaderOutput=[[AVAssetReaderTrackOutput alloc] initWithTrack:videoTrack outputSettings:outputSettings];
    assetReaderOutput.alwaysCopiesSampleData=false;
    [assetReader addOutput:assetReaderOutput];
    [assetReader startReading];
    CMSampleBufferRef sample=[assetReaderOutput copyNextSampleBuffer];
    while (sample != nil) {
        if (fCount!=0) {
            FrameFeature *f=self.frameFeatures[fCount-1];
            if (f.validFrame==false) {
                NSLog(@"Skip this bad boy %i", fCount);
                CFRelease(sample);
                sample=[assetReaderOutput copyNextSampleBuffer];
                fCount++;
                continue;
            }
        }                
        CVImageBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sample);
        CVPixelBufferLockBaseAddress( pixelBuffer, 0 );
        int bufferWidth = (int)CVPixelBufferGetWidth(pixelBuffer);
        int bufferHeight = (int)CVPixelBufferGetHeight(pixelBuffer);
        unsigned char *pixel = (unsigned char *)CVPixelBufferGetBaseAddress(pixelBuffer);
        cv::Mat image = cv::Mat(bufferHeight,bufferWidth,CV_8UC4,pixel);
        
        if (showPoints) {
            image=[self drawFeat:image andIndex:(fCount-1)];
        }
        @autoreleasepool {

            if (fCount!=0) {
                cv::Mat outputMat;
                cv::warpAffine(image, outputMat, self->transforms[fCount-1], self->realFrameSize,flags);
                image=outputMat;
            }
            UIImage *outputImage;
            cv::Mat trimmedMat=trimFrameCopy(maxTrim, image);
            cv::Mat resizeMat;
            cv::resize(trimmedMat,resizeMat,self->realFrameSize);
            outputImage=UIImageFromCVMat(resizeMat);
            if (movie) {
                [movie appendImage:outputImage];
            }
//            if (fCount < 100) {
//                [transformedImages addObject:outputImage];
//            }
  //          resizeMat.release();
 //           trimmedMat.release();
        }
        if (fCount % 50==0 || fCount > 270) {
            NSLog(@"Processing frame %i",fCount);
        }
        CVPixelBufferUnlockBaseAddress( pixelBuffer, 0 );
        CFRelease(sample);
        sample=[assetReaderOutput copyNextSampleBuffer];
        fCount++;
    }

    long long m2 = (long long)([[NSDate date] timeIntervalSince1970] * 1000.0);
    NSLog(@"Time to encode video %llu ms", (m2-m1));
    return transformedImages;
}
- (void) calculateDistances {
    
    int framesFlaggedFalse=0;
    
    for (int i=0; i < [self.frameFeatures count]; i++) {
        NSMutableArray *dist;
        FrameFeature *f=self.frameFeatures[i];
        if (i==0) {
            dist=[FrameFeature calcDistanceForPoints:f.points a:f.startingPoints];
        }
        else {
            FrameFeature *prevFeature=self.frameFeatures[i-1];
            dist=[FrameFeature calcDistanceForPoints:f.points a:prevFeature.points];
        }
        f.distances=dist;
        double m=[f getDistanceMean];
        if (framesFlaggedFalse > 2 || m > 20) {
            //three frames over 20 have been flagged. Shut down any future frames.
            f.validFrame=false;
            skippedFrames++;
            framesFlaggedFalse++;
        }
        else {
            f.validFrame=true;
        }
    }
    NSLog(@"Frames tagged false: %i of %i",framesFlaggedFalse,[self.frameFeatures count]);
}
- (NSArray *) stdDeviationMask {
    //NSLog(@"Buliding std mask");
    if (self.stdDeviations == NULL) {
        [self calcStdDeviation];
    }
    //double median = [self.stdDeviations median].doubleValue;
//    double precision=0.3;
    double precision=0.3;
    for (int i=0; i < 30; i++) {
        precision = 0.3 * (2*i);
        if (precision <=0 ) precision=0.3;
        int stdCounter=0;
        for (int z=0; z < [self.stdDeviations count]; z++) {
            NSNumber  *n1 =self.stdDeviations[z];
            if (n1.doubleValue < precision) {
                stdCounter++;
            }
        }
        
        
        //NSLog(@"Stds %i", stdCounter);
        if (stdCounter > ([self.stdDeviations count] * 0.25)) {
            break;
        }
    }
    int matches=0;
    NSMutableArray *mask=[NSMutableArray arrayWithCapacity:[self.stdDeviations count]];
    for (int z=0; z < [self.stdDeviations count]; z++) {
        NSNumber  *n1 =self.stdDeviations[z];
        if (n1.doubleValue < precision) {
            matches++;
            [mask addObject:[NSNumber numberWithInt:1]];
        }
        else {
            [mask addObject:[NSNumber numberWithInt:0]];
        }
    }
    NSLog(@"Std precision %f with matches %i", precision,matches);
    //    NSLog(@"Maks %@", mask);
    return mask;
}

- (void) calcStdDeviation {
    long long m1 = (long long)([[NSDate date] timeIntervalSince1970] * 1000.0);
    self.stdDeviations=[Stabilize3 calcStdDeviation:self.frameFeatures];
    long long m2 = (long long)([[NSDate date] timeIntervalSince1970] * 1000.0);
#if Benchmarks
    NSLog(@"Time for standard deviation: %lld ms", m2-m1);
#endif
}

- (void) printStdStats {
    NSNumber *mm=[self.stdDeviations mean];
    int lowDeviations=0;
    for (id object in self.stdDeviations) {
        NSNumber *n= object;
        if ([n floatValue] < 0.3) {
            lowDeviations++;
        }
    }
    float highQualityPoints= lowDeviations/ float([self.stdDeviations count]) * 100;
    NSString* formattedNumber = [NSString stringWithFormat:@"%.02f", highQualityPoints];
    NSLog(@"Standard Deviations: Total:%ld Mean: %f  LowDev:%i HighQualityPointPct:%@%%", [self.stdDeviations count],[mm floatValue],lowDeviations, formattedNumber);
    NSLog(@"MaxTrim:%f",maxTrim);
}
- (void) dumpPoints:(std::vector<cv::Point2f>) points {
    //std::vector<cv::Point2f> points = ff.points.point2;
    for (int z=0; z < points.size(); z++) {
        cv::Point2f p=points[z];
        std::cout << "x:" << p.x << " y:" << p.y << "\n";
    }
}
- (void) calcTransforms {
    if (self.postProcessDone != true) {
        NSLog(@"Can't exec getTransforms without postprocess");
        return;
    }
    long long m1 = (long long)([[NSDate date] timeIntervalSince1970] * 1000.0);
    for (int z=0; z < [self.frameFeatures count]; z++) {
        FrameFeature *f=self.frameFeatures[z];
        if (f.validFrame==false) {
            cv::Mat m;
            transforms.push_back(m);
            NSLog(@"Lets skip %i",z);
            continue;
        }
        std::vector< std::vector <cv::Point2f>> matchingPoints = [self getReducedPointsForFeature:f];   //umm....
        //NSLog(@"m1: %i m2:%i", matchingPoints[0].size(), matchingPoints[1].size());
        std::vector <cv::Point2f> mmm=matchingPoints[0];
        std::vector <cv::Point2f> mmm2=matchingPoints[1];
        
        if (matchingPoints[0].size()==0 || matchingPoints[1].size()==0) {
            NSLog(@"Cannot find any matching points skipping");
            cv::Mat m;
            transforms.push_back(m);
            skippedFrames++;
            f.validFrame=false;
            continue;
        }
        
        //std::cout << mmm[0] << " -> " << mmm2[0] << "\n";
        
        cv::Mat mask;
        cv::Mat rigid=cv::estimateRigidTransform(matchingPoints[0], matchingPoints[1], false);
        
        if (rigid.cols==0) {
            NSLog(@"Frame could not calculate rigid transform.  Skipping: %i",z);
            cv::Mat m;
            transforms.push_back(m);
            skippedFrames++;
            f.validFrame=false;
            continue;
        }
        cv::Mat homo=cv::findHomography(matchingPoints[0], matchingPoints[1],  cv::RANSAC,5,mask);
        cv::Mat homo2;
        cv::Mat rigid2;
        homo.convertTo(homo2, CV_32F);
        rigid.convertTo(rigid2, CV_32F);
        // homo.reshape(2,0);
        float trimmed=trim.estimateOptimalTrimRatio(homo2, self->realFrameSize);
        // std::cout << homo2 << " and frame size " << self->frameSize << "\n";
        
        cv::Mat C = (cv::Mat_<float>(1,3) << 0, 0,  1);
        rigid2.push_back(C);
        //std::cout << rigid << "\n";
        //std::cout << homo2 << "\n";
        float trimmed2=trim.estimateOptimalTrimRatio(rigid2, self->realFrameSize);
        if (trimmed > 0.1) {
            NSLog(@"Too much trim, skip this frame. %i t: %f",z,trimmed);
            cv::Mat m;
            transforms.push_back(m);
            f.validFrame=false;
            continue;
        }
        //NSLog(@"Trim %f & trim2: %f",trim,trim2);
        //        cv::Mat B_new(3,3,CV_32F);
        //        B_new.row(0) = rigid2.row(0);
        //        B_new.row(1) = rigid2.row(1);
        //        B_new.row(2) = cv::Mat::ones(1,3,CV_32F);
        transforms.push_back(rigid);
        //if (trimmed > maxTrim) maxTrim=trimmed;
        if (trimmed2 > maxTrim) maxTrim=trimmed2;
        //maxTrim=0.05;
    

    }
    long long m2 = (long long)([[NSDate date] timeIntervalSince1970] * 1000.0);
#if Benchmarks
    NSLog(@"Time to post process %llu ms", m2-m1);
#endif
}


- (std::vector<cv::Point2f>) goodFeaturesToTrack:(cv::Mat) grayMat {
    std::vector<cv::Point2f> points;
    cv::goodFeaturesToTrack(grayMat, points, maxCorners, 0.01, 10);
    cv::cornerSubPix(grayMat, points, cv::Size(5, 5), cv::Size(-1, -1), cv::TermCriteria(CV_TERMCRIT_EPS + CV_TERMCRIT_ITER,100,0.001) );
    return points;
}




- (std::vector< std::vector <cv::Point2f>>) getReducedPointsForFeature:(FrameFeature *) f {
    if (f.reducedPoints.size()  > 0) {
        return f.reducedPoints;
    }
    NSArray *reduceMask=[Stabilize3 reduceMask:f andStdMask:stdMask andOffsetMask:offsetMask];
    std::vector< std::vector <cv::Point2f>> reduceArr;
    std::vector<cv::Point2f>  reducedPointsF;
    std::vector<cv::Point2f>  reducedStartingPoints;
    std::vector<cv::Point2f>  points=f.points.point2;
    std::vector<cv::Point2f>  startingPointsF=f.startingPoints.point2;
    for (int i=0; i < [reduceMask count]; i++ ) {
        NSNumber *r = reduceMask[i];
        if (r.intValue==1) {
            reducedPointsF.push_back(points[i]);
            reducedStartingPoints.push_back(startingPointsF[i]);
        }
    }
    
    reduceArr.push_back(reducedStartingPoints);
    reduceArr.push_back(reducedPointsF);
    //NSLog(@"Points reduced is %i Reduce mask size:%i", reducedPointsF.size(), [reduceMask count]);
    [f setReductedPoints:reduceArr];
    return reduceArr;
}
-  (std::vector< std::vector <cv::Point2f>>) getReducedPoints {
    std::vector< std::vector <cv::Point2f>> reduceArrA;
    for (int z=0; z < [self.frameFeatures count]; z++) {
        FrameFeature *f=self.frameFeatures[z];
        std::vector< std::vector <cv::Point2f>> matchingPoints = [self getReducedPointsForFeature:f];
        reduceArrA.push_back(matchingPoints[1]);
    }
    return reduceArrA;
}

+ (NSArray *) reduceMask:(FrameFeature *) f andStdMask:(NSArray *) stdMask andOffsetMask:(NSArray *) offsetMask {
    NSMutableArray *statusArray=[f.pointStatus statusArray];
    int reduced=0;
    for (int i=0; i < [statusArray count];i++) {
        NSNumber *n=statusArray[i];
        if (n.intValue > 0) {
            if (  ((NSNumber *)stdMask[i]).intValue == 0) {
                reduced++;
                [statusArray replaceObjectAtIndex:i withObject:[NSNumber numberWithInt:0]];
            }
            if (  ((NSNumber *)offsetMask[i]).intValue == 0) {
                reduced++;
                [statusArray replaceObjectAtIndex:i withObject:[NSNumber numberWithInt:0]];
            }
        }
    }
    std::vector<cv::Point2f> ppp = f.points.point2;
    return statusArray;
}
+ (NSMutableArray *) calcStdDeviation:(NSArray *) frameFeatures {
    if(![frameFeatures count]) return nil;
    FrameFeature *f=frameFeatures[0];
    int size=f.points.point2.size();
    NSMutableArray *stdDeviationArray = [NSMutableArray arrayWithCapacity:size];
    for (int i=0; i < size; i++) {
        NSArray *distanceRow=[Stabilize3 getDistanceRow:frameFeatures andRow:i];
        NSNumber *std=[Stabilize3 standardDeviationOf:distanceRow];
        [stdDeviationArray addObject:std];
    }
    
    return stdDeviationArray;
}
+ (NSArray *) getDistanceRow:(NSArray *) frameFeatures andRow:(int) row {
    NSMutableArray *myArray = [NSMutableArray arrayWithCapacity:[frameFeatures count]];
    for (id object in frameFeatures) {
        FrameFeature *f=object;
        if (f.validFrame==true) {
            [myArray addObject: f.distances[row]];
        }
//        else {
//            NSLog(@"LOOK I SKIPPED %i, %i", f.validFrame, f.frameIndex);
//        }
    }
    return myArray;
}

+ (NSNumber *)standardDeviationOf:(NSArray *)array {
    if(![array count]) return nil;
    double mean = [[Stabilize3 meanOf:array] doubleValue];
    double sumOfSquaredDifferences = 0.0;
    for(NSNumber *number in array) {
        double valueOfNumber = [number doubleValue];
        double difference = valueOfNumber - mean;
        sumOfSquaredDifferences += difference * difference;
    }
    return [NSNumber numberWithDouble:sqrt(sumOfSquaredDifferences / [array count])];
}
+ (NSNumber *)meanOf:(NSArray *)array {
    double runningTotal = 0.0;
    for(NSNumber *number in array) {
        runningTotal += [number doubleValue];
    }
    return [NSNumber numberWithDouble:(runningTotal / [array count])];
}
+ (NSArray *) calcOffscreenMask:(NSArray *) frameFeatures {
    //long long m1 = (long long)([[NSDate date] timeIntervalSince1970] * 1000.0);
    if(![frameFeatures count]) return nil;
    FrameFeature *f=frameFeatures[0];
    int size=f.points.point2.size();
    NSMutableArray *offscreenMask = [NSMutableArray arrayWithCapacity:size];
    for (int i=0; i < size; i++) {
        [offscreenMask addObject:[NSNumber numberWithInt:1]];
    }
    
    //for every feature.
    for (int i=0; i < [frameFeatures count]; i++) {
        FrameFeature *ff=frameFeatures[i];
        bool isOffset=false;
        std::vector<cv::Point2f> points = ff.points.point2;
        for (int z=0; z < points.size(); z++) {
            if (points[z].x <= 0 || points[z].y <=0 ) {
                isOffset=true;
                [offscreenMask replaceObjectAtIndex:z withObject:[NSNumber numberWithInt:0]];
                // NSLog(@"Any offsets? %f %f index %i:%i", points[z].x, points[z].y, i,z);
                //break;
            }
        }
    }
    long long m2 = (long long)([[NSDate date] timeIntervalSince1970] * 1000.0);
    // NSLog(@"Time for offset: %i ms", m2-m1);
    // NSLog(@"Off screern %i", [offscreenMask count]);
    return offscreenMask;
}


static void UIImageToMat(UIImage *image, cv::Mat &mat) {
    
    // Create a pixel buffer.
    NSInteger width = CGImageGetWidth(image.CGImage);
    NSInteger height = CGImageGetHeight(image.CGImage);
    CGImageRef imageRef = image.CGImage;
    cv::Mat mat8uc4 = cv::Mat((int)height, (int)width, CV_8UC4);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef contextRef = CGBitmapContextCreate(mat8uc4.data, mat8uc4.cols, mat8uc4.rows, 8, mat8uc4.step, colorSpace, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrderDefault);
    CGContextDrawImage(contextRef, CGRectMake(0, 0, width, height), imageRef);
    CGContextRelease(contextRef);
    CGColorSpaceRelease(colorSpace);
    
    // Draw all pixels to the buffer.
    cv::Mat mat8uc3 = cv::Mat((int)width, (int)height, CV_8UC3);
    cv::cvtColor(mat8uc4, mat8uc3, CV_RGBA2BGR);
    
    mat = mat8uc3;
}


static UIImage *MatToUIImage(cv::Mat &mat) {
    
    // Create a pixel buffer.
    assert(mat.elemSize() == 1 || mat.elemSize() == 3);
    cv::Mat matrgb;
    if (mat.elemSize() == 1) {
        cv::cvtColor(mat, matrgb, CV_GRAY2RGB);
    } else if (mat.elemSize() == 3) {
        cv::cvtColor(mat, matrgb, CV_BGR2RGB);
    }
    
    // Change a image format.
    NSData *data = [NSData dataWithBytes:matrgb.data length:(matrgb.elemSize() * matrgb.total())];
    CGColorSpaceRef colorSpace;
    if (matrgb.elemSize() == 1) {
        colorSpace = CGColorSpaceCreateDeviceGray();
    } else {
        colorSpace = CGColorSpaceCreateDeviceRGB();
    }
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
    CGImageRef imageRef = CGImageCreate(matrgb.cols, matrgb.rows, 8, 8 * matrgb.elemSize(), matrgb.step.p[0], colorSpace, kCGImageAlphaNone|kCGBitmapByteOrderDefault, provider, NULL, false, kCGRenderingIntentDefault);
    UIImage *image = [UIImage imageWithCGImage:imageRef];
    CGImageRelease(imageRef);
    CGDataProviderRelease(provider);
    CGColorSpaceRelease(colorSpace);
    
    return image;
}



- (NSArray *) applyTransforms:(NSArray *) images {
    if ( ([images count]-1) != [self.frameFeatures count]) {
        NSLog(@"Images and frame features do not match up! %lu, %lu", (unsigned long)[images count], (unsigned long)[self.frameFeatures count]);
        return NULL;
    }
    if (self.postProcessDone==false) {
        NSLog(@"Need to post processes!");
        return NULL;
    }
    NSMutableArray *transformedImages=[NSMutableArray arrayWithCapacity:[images count]];
    for (int i=0; i < [images count];i++) {
        UIImage *img=images[i];
        cv::Mat imgMat;
        cv::Mat outputMat;
        UIImageToMat(img, imgMat);
        if (i==0) {
            
            cv::Mat trimmedMat=trimFrame(maxTrim, imgMat);
            UIImage *outputImage=MatToUIImage(trimmedMat);
            //   UIImage *outputImage=MatToUIImage(imgMat);
            [transformedImages addObject:outputImage];
        }
        else {
            int flags =  cv::INTER_CUBIC |  cv::WARP_INVERSE_MAP;
            
            
           // std::cout << "Warping with frame size " << self->realFrameSize << " and transform " << self->transforms[i-1] << " and trim:" << maxTrim << " \n";
            
            cv::warpAffine(imgMat, outputMat, self->transforms[i-1], realFrameSize,flags);
            cv::Mat trimmedMat=trimFrame(maxTrim, outputMat);
            UIImage *outputImage=MatToUIImage(trimmedMat);
            [transformedImages addObject:outputImage];
        }
    }
    return transformedImages;
}

static cv::Mat trimFrame(float trimRatio, cv::Mat frame) {
    int dx = static_cast<int>(floor(trimRatio * frame.cols));
    int dy = static_cast<int>(floor(trimRatio * frame.rows));
    return frame(cv::Rect(dx, dy, frame.cols - 2*dx, frame.rows - 2*dy));
}
static cv::Mat trimFrameCopy(float trimRatio, cv::Mat frame) {
    int dx = static_cast<int>(floor(trimRatio * frame.cols));
    int dy = static_cast<int>(floor(trimRatio * frame.rows));
    cv::Mat frameCopy;
    frame(cv::Rect(dx, dy, frame.cols - 2*dx, frame.rows - 2*dy)).copyTo(frameCopy);
    return frameCopy;
}

+ (CGRect) trimFrameRect:(float) trimRatio andRect:(CGRect) rect {
    int dx = floor(trimRatio * rect.size.width);
    int dy = floor(trimRatio * rect.size.height);
    CGRect r=CGRectMake(dx, dy, rect.size.width, rect.size.height);
    return r;
}


- (cv::Mat) drawFeat:(cv::Mat) mat andIndex:(int) i {
    if (i==-1) {
        FrameFeature *f=self.frameFeatures[0];
        Points *p=f.startingPoints;
        std::vector<cv::Point2f> pp=p.point2;
        CvScalar yellow = CV_RGB(255,255,0);
        for (int z=0; z < pp.size(); z++) {
            cv::circle(mat, pp[z], 3, yellow);
        }
    }
    else {
        if (i >= reducedPoints.size()) {
            NSLog(@"oh i think we drew all there is..");
            return mat;
        }
        std::vector<cv::Point2f> reducedP = reducedPoints[i];
        CvScalar yellow = CV_RGB(255,255,0);
        for (int i=0; i < reducedP.size(); i++) {
            // std::cout << reducedP[i] << "\n";
            cv::circle(mat, reducedP[i], 3, yellow);
        }
    }
    return mat;
}
- (NSArray *) drawFeatures:(NSArray *) images {
    NSMutableArray *drawImages=[NSMutableArray arrayWithCapacity:[images count]];
    for (int i=0; i <= [self.frameFeatures count];i++) {
        if (i==0) {
            FrameFeature *f=self.frameFeatures[0];
            Points *p=f.startingPoints;
            cv::Mat imageMat;
            UIImageToMat(images[0], imageMat);
            std::vector<cv::Point2f> pp=p.point2;
            CvScalar yellow = CV_RGB(255,255,0);
            for (int z=0; z < pp.size(); z++) {
                cv::circle(imageMat, pp[z], 3, yellow);
            }
            UIImage *z=MatToUIImage(imageMat);
            [drawImages addObject:z];
        }
        else {
            [drawImages addObject:[self drawFeature:i-1 onImage:images[i]]];
        }
    }
    return drawImages;
}
- (UIImage *) drawFeature:(int) frame onImage:(UIImage *) image {
    if (_postProcessDone==false) {
        NSLog(@"Cannot draw features til postprocessing is done");
        return nil;
    }
    cv::Mat imageMat;
    UIImageToMat(image, imageMat);
    std::vector<cv::Point2f> reducedP;
    if (frame == -1) {
        
    }
    else {
        
    }
    reducedP = self->reducedPoints[frame];
    CvScalar yellow = CV_RGB(255,255,0);
    for (int i=0; i < reducedP.size(); i++) {
        // std::cout << reducedP[i] << "\n";
        cv::circle(imageMat, reducedP[i], 3, yellow);
    }
    UIImage *i=MatToUIImage(imageMat);
    return i;
}


static UIImage *UIImageFromCVMat(cv::Mat &cvMat) {
    NSData *data = [NSData dataWithBytes:cvMat.data length:cvMat.elemSize()*cvMat.total()];
    
    CGColorSpaceRef colorSpace;
    CGBitmapInfo bitmapInfo;
    
    if (cvMat.elemSize() == 1) {
        colorSpace = CGColorSpaceCreateDeviceGray();
        bitmapInfo = kCGImageAlphaNone | kCGBitmapByteOrderDefault;
    } else {
        colorSpace = CGColorSpaceCreateDeviceRGB();
        bitmapInfo = kCGBitmapByteOrder32Little | (
                                                   cvMat.elemSize() == 3? kCGImageAlphaNone : kCGImageAlphaNoneSkipFirst
                                                   );
    }
    
    
    //let context = CGBitmapContextCreate(baseAddress,width,height,8,bytesPerRow, colorSpace, CGBitmapInfo.ByteOrder32Little.rawValue | CGImageAlphaInfo.PremultipliedFirst.rawValue)

    
    bitmapInfo=  kCGBitmapByteOrder32Little | kCGImageAlphaFirst;
    
    
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
    
    // Creating CGImage from cv::Mat
    CGImageRef imageRef = CGImageCreate(
                                        cvMat.cols,                 //width
                                        cvMat.rows,                 //height
                                        8,                          //bits per component
                                        8 * cvMat.elemSize(),       //bits per pixel
                                        cvMat.step[0],              //bytesPerRow
                                        colorSpace,                 //colorspace
                                        bitmapInfo,                 // bitmap info
                                        provider,                   //CGDataProviderRef
                                        NULL,                       //decode
                                        false,                      //should interpolate
                                        kCGRenderingIntentDefault   //intent
                                        );
    
    // Getting UIImage from CGImage
    UIImage *finalImage = [UIImage imageWithCGImage:imageRef];
    CGImageRelease(imageRef);
    CGDataProviderRelease(provider);
    CGColorSpaceRelease(colorSpace);
    
    return finalImage;
}


//http://stackoverflow.com/questions/14387806/convert-an-opencv-affine-matrix-to-cgaffinetransform
static CGAffineTransform convertToCGAffine(cv::Mat &mat) {
    
    CGAffineTransform t = CGAffineTransformIdentity;
    t.a = mat.at<double>(0,0);
    t.b = mat.at<double>(1,0);
    t.c = mat.at<double>(0,1);
    
    t.b = mat.at<double>(0,1);
    t.c = mat.at<double>(1,0);
    
    t.d = mat.at<double>(1,1);
    t.tx = mat.at<double>(0,2);
    t.ty = mat.at<double>(1,2);
    // return CGAffineTransformMake(mat.at<double>(0,0), mat.at<double>(1,0), mat.at<double>(0,1), mat.at<double>(1,1), mat.at<double>(0,2), mat.at<double>(1,2));
    return t;
}

- (UIImage *)imageWithImage:(UIImage *)image scaledToSize:(CGSize)newSize
{
    UIGraphicsBeginImageContext(newSize);
    [image drawInRect:CGRectMake(0, 0, newSize.width, newSize.height)];
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return newImage;
}

- (CGImageRef) scaleImage:(CGImageRef) image scaledToSize:(CGSize) newSize {
    
    int width = newSize.width;
    int height = newSize.height;
    size_t bitsPerComponent=CGImageGetBitsPerComponent(image);
    size_t bytesPerRow=CGImageGetBytesPerRow(image);
    CGColorSpaceRef colorSpace=CGImageGetColorSpace(image);
    CGBitmapInfo bitmapInfo=CGImageGetBitmapInfo(image);
    
    CGContextRef con = CGBitmapContextCreate(nil, width, height, bitsPerComponent, bytesPerRow, colorSpace, bitmapInfo);
    CGContextSetInterpolationQuality(con, kCGInterpolationHigh);
    CGContextDrawImage(con, CGRectMake(0, 0, width, height), image);
    CGImageRef ref = CGBitmapContextCreateImage(con);
    
   // CGContextRelease(con);
   // CGColorSpaceRelease(colorSpace);
    return ref;
}



@end

