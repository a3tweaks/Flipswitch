#import "NSBundle+A3Images.h"
#import "ControlStateVariants.h"

@implementation NSBundle (A3Images)

- (NSArray *)A3ImageImageFileTypes
{
	return [NSArray arrayWithObjects:@"pdf", @"png", nil];
}

- (NSUInteger)imageSizeForA3ImageName:(NSString *)imageName closestToSize:(CGFloat)sourceSize inDirectory:(NSString *)directory
{
	NSMutableIndexSet *sizes = [[NSMutableIndexSet alloc] init];
	for (NSString *fileType in self.A3ImageImageFileTypes) {
		NSArray *images = [self pathsForResourcesOfType:fileType inDirectory:directory];
		for (NSString *fullPath in images) {
			NSString *fileName = [fullPath lastPathComponent];
			NSInteger location = [fileName rangeOfString:@"-" options:NSLiteralSearch | NSBackwardsSearch].location;
			if (location == NSNotFound) {
				if ([[fileName stringByDeletingPathExtension] isEqualToString:imageName])
					[sizes addIndex:0];
			} else {
				if ([[fileName substringToIndex:location] isEqualToString:imageName]) {
					NSInteger value = (NSUInteger)[[fileName substringFromIndex:location + 1] integerValue];
					if (value > 0)
						[sizes addIndex:(NSUInteger)value];
				}
			}
		}
		NSUInteger closestSize = [sizes indexGreaterThanOrEqualToIndex:(NSUInteger)sourceSize];
		if (closestSize == NSNotFound)
			closestSize = [sizes indexLessThanIndex:(NSUInteger)sourceSize];
		if (closestSize != NSNotFound) {
			[sizes release];
			return closestSize;
		}
	}
	[sizes release];
	return NSNotFound;
}

- (NSString *)imagePathForA3ImageName:(NSString *)imageName imageSize:(NSUInteger)imageSize preferredScale:(CGFloat)preferredScale controlState:(UIControlState)controlState inDirectory:(NSString *)directory loadedControlState:(UIControlState *)outImageControlState
{
	if (!imageName)
		return nil;
	if (imageSize == NSNotFound)
		return nil;
	NSString *suffix = imageSize ? [NSString stringWithFormat:@"-%u", imageSize] : @"";
	NSString *scaleSuffix = preferredScale > 1.0f ? [NSString stringWithFormat:@"@%.0fx"] : nil;
	for (NSString *fileType in self.A3ImageImageFileTypes) {
		for (size_t i = 0; i < sizeof(ControlStateVariantMasks) / sizeof(*ControlStateVariantMasks); i++) {
			UIControlState newState = controlState & ControlStateVariantMasks[i];
			NSString *name = [ControlStateVariantApply(imageName, newState) stringByAppendingString:suffix];
			NSString *filePath = scaleSuffix ? [self pathForResource:[name stringByAppendingString:scaleSuffix] ofType:fileType inDirectory:directory] : nil;
			if (!filePath)
				filePath = [self pathForResource:name ofType:fileType inDirectory:directory];
			if (filePath) {
				if (outImageControlState) {
					*outImageControlState = newState;
				}
				return filePath;
			}
		}
	}
	return nil;
}

- (NSString *)imagePathForA3ImageName:(NSString *)imageName imageSize:(NSUInteger)imageSize preferredScale:(CGFloat)preferredScale controlState:(UIControlState)controlState inDirectory:(NSString *)directory
{
	return [self imagePathForA3ImageName:imageName imageSize:imageSize preferredScale:preferredScale controlState:controlState inDirectory:directory loadedControlState:NULL];
}

@end
