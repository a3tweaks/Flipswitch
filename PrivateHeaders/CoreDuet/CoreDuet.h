#import <Foundation/Foundation.h>

@interface _CDBatterySaver : NSObject
+ (_CDBatterySaver *)batterySaver;
- (int)getPowerMode;
- (int)setMode:(int)newMode;
- (BOOL)setPowerMode:(int)newMode error:(NSError **)error;
@end
