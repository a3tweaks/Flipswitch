#import <UIKit/UIKit.h>

@interface A3ToggleManager : NSObject
{

}

+ (A3ToggleManager *)sharedInstance;

- (NSArray *)allToggles;

- (NSString *)toggleNameForToggleID:(NSString *)toggleID;
- (UIImage *)toggleImageWithBackground:(UIImage *)backgroundImage overlay:(UIImage *)overlayMask andState:(BOOL)state;

- (BOOL)toggleStateForToggleID:(NSString *)toggleID;
- (void)setToggleState:(BOOL)state onToggleID:(NSString *)toggleID;

@end