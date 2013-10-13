#import "NSBundle+Flipswitch.h"
#import "ControlStateVariants.h"

@implementation NSBundle (Flipswitch)

- (NSBundle *)flipswitchThemedBundle
{
	NSString *path = [[self pathForResource:@"Info" ofType:@"plist"] stringByDeletingLastPathComponent];
	return [path isEqualToString:[self bundlePath]] ? self : [NSBundle bundleWithPath:path];
}

- (NSArray *)FSImageImageFileTypes
{
	return [NSArray arrayWithObjects:@"pdf", @"png", nil];
}

- (NSUInteger)imageSizeForFlipswitchImageName:(NSString *)imageName closestToSize:(CGFloat)sourceSize inDirectory:(NSString *)directory
{
	NSMutableIndexSet *sizes = [[NSMutableIndexSet alloc] init];
	for (NSString *fileType in self.FSImageImageFileTypes) {
		NSArray *images = [self pathsForResourcesOfType:fileType inDirectory:directory];
		for (NSString *fullPath in images) {
			NSString *fileName = [fullPath lastPathComponent];
			NSInteger location = [fileName rangeOfString:@"-" options:NSLiteralSearch | NSBackwardsSearch].location;
			if (location == NSNotFound) {
				if ([[fileName stringByDeletingPathExtension] isEqualToString:imageName])
					[sizes addIndex:0];
			} else {
				NSInteger lastPartInteger = [[fileName substringFromIndex:location + 1] integerValue];
				if (lastPartInteger == 0) {
					if ([[fileName stringByDeletingPathExtension] isEqualToString:imageName])
						[sizes addIndex:0];
				} else if (lastPartInteger > 9) {
					if ([[fileName substringToIndex:location] isEqualToString:imageName])
						[sizes addIndex:(NSUInteger)lastPartInteger];
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

- (NSString *)imagePathForFlipswitchImageName:(NSString *)imageName imageSize:(NSUInteger)imageSize preferredScale:(CGFloat)preferredScale controlState:(UIControlState)controlState inDirectory:(NSString *)directory loadedControlState:(UIControlState *)outImageControlState
{
	if (!imageName)
		return nil;
	if (imageSize == NSNotFound)
		return nil;
	NSString *suffix = imageSize ? [NSString stringWithFormat:@"-%lu", (unsigned long)imageSize] : @"";
	NSString *scaleSuffix = preferredScale > 1.0f ? [NSString stringWithFormat:@"@%.0fx", preferredScale] : nil;
	for (NSString *fileType in self.FSImageImageFileTypes) {
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

- (NSString *)imagePathForFlipswitchImageName:(NSString *)imageName imageSize:(NSUInteger)imageSize preferredScale:(CGFloat)preferredScale controlState:(UIControlState)controlState inDirectory:(NSString *)directory
{
	return [self imagePathForFlipswitchImageName:imageName imageSize:imageSize preferredScale:preferredScale controlState:controlState inDirectory:directory loadedControlState:NULL];
}

@end
