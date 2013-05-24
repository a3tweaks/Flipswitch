#import "NSBundle+A3Images.h"
#import "ControlStateVariants.h"

@implementation NSBundle (A3Images)

- (NSArray *)A3ImageImageFileTypes
{
	return [NSArray arrayWithObjects:@"pdf", @"png", nil];
}

- (NSUInteger)imageSizeForA3ImageName:(NSString *)imageName closestToSize:(CGFloat)sourceSize inDirectory:(NSString *)directory
{
	for (NSString *fileType in self.A3ImageImageFileTypes) {
		NSArray *images = [self pathsForResourcesOfType:fileType inDirectory:directory];
		NSMutableIndexSet *sizes = [[NSMutableIndexSet alloc] init];
		for (NSString *fullPath in images) {
			NSString *fileName = [fullPath lastPathComponent];
			NSInteger location = [fileName rangeOfString:@"-" options:NSLiteralSearch | NSBackwardsSearch].location;
			if (location == NSNotFound) {
				if ([fileName isEqualToString:imageName])
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
		[sizes release];
		if (closestSize != NSNotFound)
			return closestSize;
	}
	return NSNotFound;
}

- (NSString *)imagePathForA3ImageName:(NSString *)imageName imageSize:(NSUInteger)imageSize controlState:(UIControlState)controlState inDirectory:(NSString *)directory;
{
	if (!imageName)
		return nil;
	if (imageSize == NSNotFound)
		return nil;
	NSString *suffix = imageSize ? [NSString stringWithFormat:@"-%u", imageSize] : @"";
	for (NSString *fileType in self.A3ImageImageFileTypes) {
		UIControlState bitsToKeep[] = {
			~UIControlStateNormal,
			~UIControlStateDisabled,
			~(UIControlStateDisabled | UIControlStateHighlighted),
			~(UIControlStateDisabled | UIControlStateHighlighted | UIControlStateSelected)
		};
		for (size_t i = 0; i < sizeof(bitsToKeep) / sizeof(*bitsToKeep); i++) {
			NSString *filePath = [self pathForResource:[ApplyControlStateVariantToName(imageName, controlState & bitsToKeep[i]) stringByAppendingString:suffix] ofType:fileType inDirectory:directory];
			if (filePath)
				return filePath;
		}
	}
	return nil;
}

@end
