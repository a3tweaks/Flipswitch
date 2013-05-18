#import <UIKit/UIKit.h>

@interface NSBundle (A3Images)
- (NSUInteger)imageSizeForA3ImageName:(NSString *)glyphName closestToSize:(CGFloat)sourceSize inDirectory:(NSString *)directory;
- (NSString *)imagePathForA3ImageName:(NSString *)imageName imageSize:(NSUInteger)imageSize controlState:(UIControlState)controlState inDirectory:(NSString *)directory;
@end
