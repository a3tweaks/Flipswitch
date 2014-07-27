#import "FSSwitchDataSource.h"
#import "FSSwitchPanel.h"
#import "FSCapability.h"
#import "NSBundle+Flipswitch.h"

@implementation NSObject (FSSwitchDataSource)

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
		[(id<FSSwitchDataSource>)self applyActionForSwitchIdentifier:switchIdentifier];
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

- (id)glyphImageDescriptorOfState:(FSSwitchState)switchState variant:(NSString *)variant size:(CGFloat)size scale:(CGFloat)scale forSwitchIdentifier:(NSString *)switchIdentifier
{
	if (variant) {
		NSBundle *bundle = [self bundleForSwitchIdentifier:switchIdentifier];
		if (!bundle)
			return nil;
		NSString *stateName = [NSString stringWithFormat:@"glyph-%@-%@", variant, NSStringFromFSSwitchState(switchState)];
		NSUInteger closestSize;
		closestSize = [bundle imageSizeForFlipswitchImageName:stateName closestToSize:size inDirectory:nil];
		if (closestSize != NSNotFound)
			return [bundle imagePathForFlipswitchImageName:stateName imageSize:closestSize preferredScale:scale controlState:UIControlStateNormal inDirectory:nil];
		NSString *glyphVariant = [NSString stringWithFormat:@"glyph-%@", variant];
		closestSize = [bundle imageSizeForFlipswitchImageName:glyphVariant closestToSize:size inDirectory:nil];
		if (closestSize != NSNotFound)
			return [bundle imagePathForFlipswitchImageName:glyphVariant imageSize:closestSize preferredScale:scale controlState:UIControlStateNormal inDirectory:nil];
	}
	return [self glyphImageDescriptorOfState:switchState size:size scale:scale forSwitchIdentifier:switchIdentifier];
}

- (void)switchWasRegisteredForIdentifier:(NSString *)switchIdentifier
{
}

- (void)switchWasUnregisteredForIdentifier:(NSString *)switchIdentifier
{
}

- (BOOL)shouldShowSwitchIdentifier:(NSString *)switchIdentifier
{
	NSBundle *bundle = [self bundleForSwitchIdentifier:switchIdentifier];
	NSArray *capabilities = [bundle objectForInfoDictionaryKey:@"required-capabilities"];
	if ([capabilities isKindOfClass:[NSArray class]])
		for (NSString *capability in capabilities)
			if ([capability isKindOfClass:[NSString class]])
				if (!FSSystemHasCapability(capability))
					return NO;

	return YES;
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
	id urlValue = (kCFCoreFoundationVersionNumber >= 800.0 ? [[self bundleForSwitchIdentifier:switchIdentifier] objectForInfoDictionaryKey:@"alternate-action-url-7"] : nil)
		?: [[self bundleForSwitchIdentifier:switchIdentifier] objectForInfoDictionaryKey:@"alternate-action-url"];
	if (urlValue) {
		NSURL *url = [NSURL URLWithString:[urlValue description]];
		if (url) {
			[[FSSwitchPanel sharedPanel] openURLAsAlternateAction:url];
		}
	}
}

- (BOOL)switchWithIdentifierIsEnabled:(NSString *)switchIdentifier
{
	return YES;
}

- (void)beginPrewarmingForSwitchIdentifier:(NSString *)switchIdentifier
{
}

- (void)cancelPrewarmingForSwitchIdentifier:(NSString *)switchIdentifier
{
}

- (NSString *)descriptionOfState:(FSSwitchState)state forSwitchIdentifier:(NSString *)switchIdentifier
{
	switch (state) {
		case FSSwitchStateOn:
			return @"On";
		case FSSwitchStateOff:
			return @"Off";
		default:
			return nil;
	}
}

- (Class <FSSwitchSettingsViewController>)settingsViewControllerClassForSwitchIdentifier:(NSString *)switchIdentifier
{
	NSString *className = [[self bundleForSwitchIdentifier:switchIdentifier] objectForInfoDictionaryKey:@"settings-view-controller-class"];
	return NSClassFromString(className);
}

- (BOOL)switchWithIdentifierIsSimpleAction:(NSString *)switchIdentifier
{
	id result = [[self bundleForSwitchIdentifier:switchIdentifier] objectForInfoDictionaryKey:@"is-simple-action"];
	return [result boolValue];
}

@end
