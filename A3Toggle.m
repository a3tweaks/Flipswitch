#import "A3Toggle.h"
#import "NSBundle+A3Images.h"

@implementation NSObject (A3Toggle)

- (NSBundle *)bundleForA3ToggleIdentifier:(NSString *)toggleIdentifier
{
	return [NSBundle bundleForClass:[self class]];
}

- (A3ToggleState)stateForToggleIdentifier:(NSString *)toggleIdentifier
{
	return A3ToggleStateIndeterminate;
}

- (void)applyState:(A3ToggleState)newState forToggleIdentifier:(NSString *)toggleIdentifier
{
	if (newState == A3ToggleStateIndeterminate || newState != [self stateForToggleIdentifier:toggleIdentifier]) {
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
	return [[self bundleForA3ToggleIdentifier:toggleIdentifier] objectForInfoDictionaryKey:@"CFBundleDisplayName"] ?: toggleIdentifier;
}

- (id)glyphImageDescriptorForControlState:(UIControlState)controlState size:(CGFloat)size scale:(CGFloat)scale forToggleIdentifier:(NSString *)toggleIdentifier;
{
	NSBundle *bundle = [self bundleForA3ToggleIdentifier:toggleIdentifier];
	if (!bundle)
		return nil;
	NSUInteger closestSize = [self imageSizeForA3ImageName:@"glyph" closestToSize:size * scale inDirectory:nil];
	if (closestSize == NSNotFound)
		return nil;
	return [self imagePathForA3ImageName:@"glyph" imageSize:closestSize controlState:controlState inDirectory:nil];
}

- (void)toggleWasRegisteredForIdentifier:(NSString *)toggleIdentifier
{
}

- (void)toggleWasUnregisteredForIdentifier:(NSString *)toggleIdentifier
{
}

- (BOOL)hasAlternateActionForToggleIdentifier:(NSString *)toggleIdentifier
{
	return [self methodForSelector:@selector(applyAlternateActionForToggleIdentifier:)] != [NSObject instanceMethodForSelector:@selector(applyAlternateActionForToggleIdentifier:)];
}

- (void)applyAlternateActionForToggleIdentifier:(NSString *)toggleIdentifier
{
}

@end
