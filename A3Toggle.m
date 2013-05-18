#import "A3Toggle.h"
#import "NSBundle+A3Images.h"

@implementation NSObject (A3Toggle)

- (NSString *)titleForToggleIdentifier:(NSString *)toggleIdentifier
{
	// TODO: Read from bundle/plist metadata
	return toggleIdentifier;
}

- (id)glyphImageDescriptorForControlState:(UIControlState)controlState size:(CGFloat)size scale:(CGFloat)scale forToggleIdentifier:(NSString *)toggleIdentifier;
{
	NSBundle *bundle = [NSBundle bundleForClass:[self class]];
	if (!bundle)
		return nil;
	NSUInteger closestSize = [self imageSizeForA3ImageName:@"glyph" closestToSize:size * scale inDirectory:nil];
	if (closestSize == NSNotFound)
		return nil;
	return [self imagePathForA3ImageName:@"glyph" imageSize:closestSize controlState:controlState inDirectory:nil];
}

@end
