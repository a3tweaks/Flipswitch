#import "FSSwitchPanel.h"

@interface FSSwitchPanel (Prerender)
- (void)prerenderImagesOfSwitchState:(FSSwitchState)state controlState:(UIControlState)controlState scale:(CGFloat)scale usingTemplate:(NSBundle *)template toPath:(NSString *)outputPath withFilenameSuffix:(NSString *)suffix;
@end
