#import <UIKit/UIKit.h>


@interface NSArray (Statistics)

- (NSNumber *)calculateStat:(NSString *)stat;

- (NSNumber *)sum;

- (NSNumber *)mean;

- (NSNumber *)min;

- (NSNumber *)max;

- (NSNumber *)median;

- (NSNumber *)variance;

- (NSNumber *)stdev;

@end