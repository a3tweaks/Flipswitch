#import "A3ToggleManager.h"

__attribute__((visibility("hidden")))
@interface A3ToggleManagerMain : A3ToggleManager {
@private
	NSMutableDictionary *_toggleImplementations;
}
- (UIImage *)processImageForBackground:(UIImage *)backgroundImage withToggleMask:(UIImage *)toggleMask withOverlay:(UIImage *)overlay;
@end

