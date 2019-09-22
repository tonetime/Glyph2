
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>
#import "Points.h"
#import "CEMovieMaker.h"

@interface Stabilize3 : NSObject


@property NSMutableArray *frameFeatures;
@property NSArray* stdDeviations;
@property bool postProcessDone;

- (void) printStdStats;
- (void) postProcess;

-(NSArray *) processVideo:(NSArray *) images;
-(NSArray *) processVideo:(NSURL *) url andSaveImages:(bool) saveImages;
-(UIImage *) processFrame:(CMSampleBufferRef) ref andSaveImages:(bool) saveImages;
-(NSArray *) applyTransforms:(NSArray *) images;
-(NSArray *) drawFeatures:(NSArray *) images;

- (NSArray *) applyVideoTransform:(NSURL *) sourceUrl  andMovie:(CEMovieMaker *) movie andShowPoints:(bool) showPoints;
- (NSArray *) applyVideoTransformCI:(NSURL *) sourceUrl  andMovie:(CEMovieMaker *) movie andShowPoints:(bool) showPoints;

+ (Stabilize3 *)sharedInstance;
+ (void)resetSharedInstance;
- (float) skippedFramesPct;


@end