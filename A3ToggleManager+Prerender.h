#import "A3ToggleManager.h"

@interface A3ToggleManager (Prerender)
- (void)prerenderImagesOfToggleState:(A3ToggleState)state controlState:(UIControlState)controlState scale:(CGFloat)scale usingTemplate:(NSBundle *)template toPath:(NSString *)outputPath withFilenameSuffix:(NSString *)suffix;
@end
