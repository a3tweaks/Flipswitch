#import "A3Toggle.h"
#import "NSBundle+A3Images.h"

@implementation NSObject (A3Toggle)

- (A3ToggleState)stateForToggleIdentifier:(NSString *)toggleIdentifier
{
	return A3ToggleStateIndeterminate;
}

- (void)applyState:(A3ToggleState)newState forToggleIdentifier:(NSString *)toggleIdentifier
{
	if (newState == A3ToggleStateIndeterminate || newState == [self stateForToggleIdentifier:toggleIdentifier]) {
		[(id<A3ToggleState>)self flipToggleStateForToggleIdentifier:toggleIdentifier];
	}
}

- (void)applyActionForToggleIdentifier:(NSString *)toggleIdentifier
{
	switch ([self stateForToggleIdentifier:toggleIdentifier]) {
		case A3ToggleStateOff:
			[self applyState:A3ToggleStateOn forToggleIdentifier:toggleIdentifier];
			break;
		case A3ToggleStateOn:
			[self applyState:A3ToggleStateOff forToggleIdentifier:toggleIdentifier];
			break;
		case A3ToggleStateIndeterminate:
			break;
	}
}

- (NSString *)titleForToggleIdentifier:(NSString *)toggleIdentifier
{
	return [[NSBundle bundleForClass:[self class]] objectForInfoDictionaryKey:@"CFBundleDisplayName"] ?: toggleIdentifier;
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
