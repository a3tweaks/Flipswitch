#import "NSBundle+A3Images.h"

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
			NSString *fileName = [[fullPath lastPathComponent] stringByDeletingPathExtension];
			NSArray *components = [fileName componentsSeparatedByString:@"-"];
			NSUInteger count = [components count];
			if (count && [[components objectAtIndex:0] isEqualToString:imageName]) {
				if (count == 1)
					[sizes addIndex:0];
				else {
					NSInteger value = (NSUInteger)[[components objectAtIndex:1] integerValue];
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

static NSString *ApplyControlStateSuffixToString(NSString *prefix, UIControlState controlState) {
	if (!controlState)
		return prefix;
	NSMutableString *result = [[prefix mutableCopy] autorelease];
	if (controlState & UIControlStateSelected)
		[result appendString:@"-on"];
	if (controlState & UIControlStateHighlighted)
		[result appendString:@"-down"];
	if (controlState & UIControlStateDisabled)
		[result appendString:@"-disabled"];
	return result;
}

- (NSString *)imagePathForA3ImageName:(NSString *)imageName imageSize:(NSUInteger)imageSize controlState:(UIControlState)controlState inDirectory:(NSString *)directory;
{
	if (!imageName)
		return nil;
	if (imageSize == NSNotFound)
		return nil;
	NSString *prefix = imageSize ? [imageName stringByAppendingFormat:@"-%u", imageSize] : imageName;
	for (NSString *fileType in self.A3ImageImageFileTypes) {
		UIControlState bitsToKeep[] = {
			~UIControlStateNormal,
			~UIControlStateDisabled,
			~(UIControlStateDisabled | UIControlStateHighlighted),
			~(UIControlStateDisabled | UIControlStateHighlighted | UIControlStateSelected)
		};
		for (size_t i = 0; i < sizeof(bitsToKeep) / sizeof(*bitsToKeep); i++) {
			NSString *filePath = [self pathForResource:ApplyControlStateSuffixToString(prefix, controlState & bitsToKeep[i]) ofType:fileType inDirectory:directory];
			if (filePath)
				return filePath;
		}
	}
	return nil;
}

@end
