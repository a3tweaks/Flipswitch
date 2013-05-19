#import "A3ToggleManager.h"
#import "A3ToggleManagerMain.h"
#import "A3ToggleService.h"
#import "A3Toggle.h"

#import <dlfcn.h>
#import "LightMessaging/LightMessaging.h"

static LMConnection connection = {
	MACH_PORT_NULL,
	kA3ToggleServiceName
};

NSString * const A3ToggleManagerTogglesChangedNotification = @"A3ToggleManagerTogglesChangedNotification";


static A3ToggleManager *_toggleManager;

@implementation A3ToggleManager

static void TogglesChangedCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
	[[NSNotificationCenter defaultCenter] postNotificationName:A3ToggleManagerTogglesChangedNotification object:_toggleManager userInfo:nil];
}

+ (void)initialize
{
	if (self == [A3ToggleManager class]) {
		if (objc_getClass("SpringBoard")) {
			_toggleManager = [[A3ToggleManagerMain alloc] init];
		} else {
			_toggleManager = [[self alloc] init];
			CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), self, TogglesChangedCallback, (CFStringRef)A3ToggleManagerTogglesChangedNotification, NULL, CFNotificationSuspensionBehaviorCoalesce);
		}
	}
}

+ (A3ToggleManager *)sharedToggleManager
{
    return _toggleManager;
}

- (NSArray *)toggleIdentifiers
{
	LMResponseBuffer responseBuffer;
	if (LMConnectionSendTwoWay(&connection, A3ToggleServiceMessageGetIdentifiers, NULL, 0, &responseBuffer)) {
		return nil;
	}
	return LMResponseConsumePropertyList(&responseBuffer);
}

- (NSString *)titleForToggleIdentifier:(NSString *)toggleIdentifier
{
	LMResponseBuffer responseBuffer;
	if (LMConnectionSendTwoWayPropertyList(&connection, A3ToggleServiceMessageGetTitleForIdentifier, toggleIdentifier, &responseBuffer)) {
		return nil;
	}
	return LMResponseConsumePropertyList(&responseBuffer);
}

- (id)glyphImageIdentifierForToggleIdentifier:(NSString *)toggleIdentifier controlState:(UIControlState)controlState size:(CGFloat)size scale:(CGFloat)scale
{
 	NSDictionary *args = [NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:toggleIdentifier, [NSNumber numberWithFloat:size], [NSNumber numberWithFloat:scale], [NSNumber numberWithInteger:controlState], nil] forKeys:[NSArray arrayWithObjects:@"toggleIdentifier", @"size", @"scale", @"controlState", nil]];

	LMResponseBuffer responseBuffer;
	if (LMConnectionSendTwoWayPropertyList(&connection, A3ToggleServiceMessageGetImageIdentifierForToggle, args, &responseBuffer)) {
		return nil;
	}
	return LMResponseConsumePropertyList(&responseBuffer);
}

- (UIImage *)toggleImageForToggleIdentifier:(NSString *)toggleIdentifier controlState:(UIControlState)controlState scale:(CGFloat)scale usingTemplateBundle:(NSBundle *)templateBundle;
{
	// TODO: Define template format, read in template used to describe what background images to use and how to draw the glyphs
	id identifier = [self glyphImageIdentifierForToggleIdentifier:toggleIdentifier controlState:controlState size:29 scale:scale];
	if ([identifier isKindOfClass:[NSString class]]) {
		return [UIImage imageWithContentsOfFile:identifier];
	} else {
		// TODO: Allow glyph identifiers of data containing image bytes or UImage
		return nil;
	}
}

- (UIImage *)toggleImageForToggleIdentifier:(NSString *)toggleIdentifier controlState:(UIControlState)controlState usingTemplateBundle:(NSBundle *)templateBundle;
{
	CGFloat scale = [UIScreen instancesRespondToSelector:@selector(scale)] ? [UIScreen mainScreen].scale : 1.0f;
	return [self toggleImageForToggleIdentifier:toggleIdentifier controlState:controlState scale:scale usingTemplateBundle:templateBundle];
}

- (A3ToggleState)toggleStateForToggleIdentifier:(NSString *)toggleIdentifier
{
	LMResponseBuffer responseBuffer;
	if (LMConnectionSendTwoWayPropertyList(&connection, A3ToggleServiceMessageGetStateForIdentifier, toggleIdentifier, &responseBuffer)) {
		return NO;
	}
	return LMResponseConsumeInteger(&responseBuffer);
}

- (void)applyActionForToggleIdentifier:(NSString *)toggleIdentifier
{
	LMConnectionSendOneWayData(&connection, A3ToggleServiceMessageApplyActionForIdentifier, (CFDataRef)[NSPropertyListSerialization dataFromPropertyList:toggleIdentifier format:NSPropertyListBinaryFormat_v1_0 errorDescription:NULL]);
}

- (void)setToggleState:(A3ToggleState)state onToggleIdentifier:(NSString *)toggleIdentifier
{
	NSArray *propertyList = [NSArray arrayWithObjects:[NSNumber numberWithBool:state], toggleIdentifier, nil];
	LMConnectionSendOneWayData(&connection, A3ToggleServiceMessageSetStateForIdentifier, (CFDataRef)[NSPropertyListSerialization dataFromPropertyList:propertyList format:NSPropertyListBinaryFormat_v1_0 errorDescription:NULL]);
}


- (BOOL)hasAlternateActionForToggleIdentifier:(NSString *)toggleIdentifier
{
	LMResponseBuffer responseBuffer;
	if (LMConnectionSendTwoWayPropertyList(&connection, A3ToggleServiceMessageHasAlternateActionForIdentifier, toggleIdentifier, &responseBuffer)) {
		return NO;
	}
	return LMResponseConsumeInteger(&responseBuffer);
}

- (void)applyAlternateActionForToggleIdentifier:(NSString *)toggleIdentifier
{
	LMConnectionSendOneWayData(&connection, A3ToggleServiceMessageApplyAlternateActionForIdentifier, (CFDataRef)[NSPropertyListSerialization dataFromPropertyList:toggleIdentifier format:NSPropertyListBinaryFormat_v1_0 errorDescription:NULL]);
}

@end

@implementation A3ToggleManager (SpringBoard)

- (void)registerToggle:(id<A3Toggle>)toggle forIdentifier:(NSString *)toggleIdentifier
{
	[NSException raise:NSInternalInconsistencyException format:@"Cannot register toggles outside of SpringBoard!"];
}

- (void)unregisterToggleIdentifier:(NSString *)toggleIdentifier;
{
	[NSException raise:NSInternalInconsistencyException format:@"Cannot unregister toggles outside of SpringBoard!"];
}

- (void)stateDidChangeForToggleIdentifier:(NSString *)toggleIdentifier
{
	[NSException raise:NSInternalInconsistencyException format:@"Cannot update toggle state from outside of SpringBoard!"];
}

@end

