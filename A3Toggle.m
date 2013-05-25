#import "A3Toggle.h"
#import "A3ToggleManager.h"
#import "NSBundle+A3Images.h"

extern BOOL GSSystemHasCapability(NSString *capability);

NSString *NSStringFromA3ToggleState(A3ToggleState state)
{
	switch (state) {
		case A3ToggleStateOn:
			return @"on";
		case A3ToggleStateOff:
			return @"off";
		case A3ToggleStateIndeterminate:
		default:
			return @"indeterminate";
	}
}


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
		[(id<A3Toggle>)self applyActionForToggleIdentifier:toggleIdentifier];
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

- (BOOL)shouldShowToggleForToggleIdentifier:(NSString *)toggleIdentifier
{
	id key = [[self bundleForA3ToggleIdentifier:toggleIdentifier] objectForInfoDictionaryKey:@"required-capability-key"];
	if ([key isKindOfClass:[NSString class]])
	{
		return GSSystemHasCapability((NSString *)key);
	}

	return YES;
}

- (id)glyphImageDescriptorOfToggleState:(A3ToggleState)toggleState size:(CGFloat)size scale:(CGFloat)scale forToggleIdentifier:(NSString *)toggleIdentifier
{
	NSBundle *bundle = [self bundleForA3ToggleIdentifier:toggleIdentifier];
	if (!bundle)
		return nil;
	NSString *stateName = NSStringFromA3ToggleState(toggleState);
	NSUInteger closestSize;
	closestSize = [bundle imageSizeForA3ImageName:stateName closestToSize:size inDirectory:nil];
	if (closestSize != NSNotFound)
		return [bundle imagePathForA3ImageName:stateName imageSize:closestSize preferredScale:scale controlState:UIControlStateNormal inDirectory:nil];
	closestSize = [bundle imageSizeForA3ImageName:@"glyph" closestToSize:size inDirectory:nil];
	if (closestSize != NSNotFound)
		return [bundle imagePathForA3ImageName:@"glyph" imageSize:closestSize preferredScale:scale controlState:UIControlStateNormal inDirectory:nil];
	return nil;
}

- (void)toggleWasRegisteredForIdentifier:(NSString *)toggleIdentifier
{
}

- (void)toggleWasUnregisteredForIdentifier:(NSString *)toggleIdentifier
{
}

- (BOOL)hasAlternateActionForToggleIdentifier:(NSString *)toggleIdentifier
{
	if ([self methodForSelector:@selector(applyAlternateActionForToggleIdentifier:)] != [NSObject instanceMethodForSelector:@selector(applyAlternateActionForToggleIdentifier:)])
		return YES;
	if ([[self bundleForA3ToggleIdentifier:toggleIdentifier] objectForInfoDictionaryKey:@"alternate-action-url"])
		return YES;
	return NO;
}

- (void)applyAlternateActionForToggleIdentifier:(NSString *)toggleIdentifier
{
	id urlValue = [[self bundleForA3ToggleIdentifier:toggleIdentifier] objectForInfoDictionaryKey:@"alternate-action-url"];
	if (urlValue) {
		NSURL *url = [NSURL URLWithString:[urlValue description]];
		if (url) {
			[[A3ToggleManager sharedToggleManager] openURLAsAlternateAction:url];
		}
	}
}

@end
