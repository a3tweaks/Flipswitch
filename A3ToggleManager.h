#import <UIKit/UIKit.h>

@interface A3ToggleManager : NSObject
{

}

+ (A3ToggleManager *)sharedInstance;

- (NSString *)toggleNameForToggleID:(NSString *)toggleID;
- (UIImage *)toggleImageWithBackground:(UIImage *)backgroundImage overlay:(UIImage *)overlayMask andState:(BOOL)state;

- (BOOL)toggleStateForToggleID:(NSString *)toggleID;
- (void)runMainActionOnToggleID:(NSString *)toggleID;

@end
