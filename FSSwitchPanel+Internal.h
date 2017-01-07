#import "FSSwitchPanel.h"

@interface FSSwitchPanel ()
- (id)glyphImageDescriptorOfState:(FSSwitchState)switchState variant:(NSString *)varaint size:(CGFloat)size scale:(CGFloat)scale forSwitchIdentifier:(NSString *)switchIdentifier;
@end

@class UIColor;
UIColor *FSColorWithHexString(NSString *stringToConvert);
