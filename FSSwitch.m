#import "FSSwitch.h"
#import "FSSwitchPanel.h"
#import "NSBundle+Flipswitch.h"

extern BOOL GSSystemHasCapability(NSString *capability);

NSString *NSStringFromFSSwitchState(FSSwitchState state)
{
	switch (state) {
		case FSSwitchStateOn:
			return @"on";
		case FSSwitchStateOff:
			return @"off";
		case FSSwitchStateIndeterminate:
		default:
			return @"indeterminate";
	}
}


@implementation NSObject (FSSwitch)

- (NSBundle *)bundleForSwitchIdentifier:(NSString *)switchIdentifier
{
	return [NSBundle bundleForClass:[self class]];
}

- (FSSwitchState)stateForSwitchIdentifier:(NSString *)switchIdentifier
{
	return FSSwitchStateIndeterminate;
}

- (void)applyState:(FSSwitchState)newState forSwitchIdentifier:(NSString *)switchIdentifier
{
	if (newState == FSSwitchStateIndeterminate || newState != [self stateForSwitchIdentifier:switchIdentifier]) {
		[(id<FSSwitch>)self applyActionForSwitchIdentifier:switchIdentifier];
	}
}

- (void)applyActionForSwitchIdentifier:(NSString *)switchIdentifier
{
	switch ([self stateForSwitchIdentifier:switchIdentifier]) {
		case FSSwitchStateOff:
			[self applyState:FSSwitchStateOn forSwitchIdentifier:switchIdentifier];
			break;
		case FSSwitchStateOn:
			[self applyState:FSSwitchStateOff forSwitchIdentifier:switchIdentifier];
			break;
		case FSSwitchStateIndeterminate:
			break;
	}
}

- (NSString *)titleForSwitchIdentifier:(NSString *)switchIdentifier
{
	return [[self bundleForSwitchIdentifier:switchIdentifier] objectForInfoDictionaryKey:@"CFBundleDisplayName"] ?: switchIdentifier;
}

- (BOOL)shouldShowSwitchIdentifier:(NSString *)switchIdentifier
{
	id key = [[self bundleForSwitchIdentifier:switchIdentifier] objectForInfoDictionaryKey:@"required-capability-key"];
	if ([key isKindOfClass:[NSString class]])
	{
		return GSSystemHasCapability((NSString *)key);
	}

	return YES;
}

- (id)glyphImageDescriptorOfState:(FSSwitchState)switchState size:(CGFloat)size scale:(CGFloat)scale forSwitchIdentifier:(NSString *)switchIdentifier
{
	NSBundle *bundle = [self bundleForSwitchIdentifier:switchIdentifier];
	if (!bundle)
		return nil;
	NSString *stateName = [@"glyph-" stringByAppendingString:NSStringFromFSSwitchState(switchState)];
	NSUInteger closestSize;
	closestSize = [bundle imageSizeForFlipswitchImageName:stateName closestToSize:size inDirectory:nil];
	if (closestSize != NSNotFound)
		return [bundle imagePathForFlipswitchImageName:stateName imageSize:closestSize preferredScale:scale controlState:UIControlStateNormal inDirectory:nil];
	closestSize = [bundle imageSizeForFlipswitchImageName:@"glyph" closestToSize:size inDirectory:nil];
	if (closestSize != NSNotFound)
		return [bundle imagePathForFlipswitchImageName:@"glyph" imageSize:closestSize preferredScale:scale controlState:UIControlStateNormal inDirectory:nil];
	return nil;
}

- (void)switchWasRegisteredForIdentifier:(NSString *)switchIdentifier
{
}

- (void)switchWasUnregisteredForIdentifier:(NSString *)switchIdentifier
{
}

- (BOOL)hasAlternateActionForSwitchIdentifier:(NSString *)switchIdentifier
{
	if ([self methodForSelector:@selector(applyAlternateActionForSwitchIdentifier:)] != [NSObject instanceMethodForSelector:@selector(applyAlternateActionForSwitchIdentifier:)])
		return YES;
	if ([[self bundleForSwitchIdentifier:switchIdentifier] objectForInfoDictionaryKey:@"alternate-action-url"])
		return YES;
	return NO;
}

- (void)applyAlternateActionForSwitchIdentifier:(NSString *)switchIdentifier
{
	id urlValue = [[self bundleForSwitchIdentifier:switchIdentifier] objectForInfoDictionaryKey:@"alternate-action-url"];
	if (urlValue) {
		NSURL *url = [NSURL URLWithString:[urlValue description]];
		if (url) {
			[[FSSwitchPanel sharedPanel] openURLAsAlternateAction:url];
		}
	}
}

@end
