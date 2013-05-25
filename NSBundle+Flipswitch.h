#import <UIKit/UIKit.h>

@interface NSBundle (Flipswitch)
- (NSUInteger)imageSizeForFlipswitchImageName:(NSString *)glyphName closestToSize:(CGFloat)sourceSize inDirectory:(NSString *)directory;

- (NSString *)imagePathForFlipswitchImageName:(NSString *)imageName imageSize:(NSUInteger)imageSize preferredScale:(CGFloat)preferredScale controlState:(UIControlState)controlState inDirectory:(NSString *)directory;
- (NSString *)imagePathForFlipswitchImageName:(NSString *)imageName imageSize:(NSUInteger)imageSize preferredScale:(CGFloat)preferredScale controlState:(UIControlState)controlState inDirectory:(NSString *)directory loadedControlState:(UIControlState *)outImageControlState;
@end
