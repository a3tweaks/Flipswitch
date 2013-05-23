#import "A3PreferenceToggle.h"

#import "A3ToggleManager.h"

#import <notify.h>

@implementation A3PreferenceToggle

- (id)initWithBundle:(NSBundle *)_bundle
{
	if ((self = [super init])) {
		bundle = [_bundle retain];
	}
	return self;
}

- (void)dealloc
{
	[bundle release];
	[toggleIdentifier_ release];
	[super dealloc];
}

- (NSBundle *)bundleForA3ToggleIdentifier:(NSString *)toggleIdentifier
{
	return bundle;
}

- (A3ToggleState)stateForToggleIdentifier:(NSString *)toggleIdentifier
{
	NSString *key = [bundle objectForInfoDictionaryKey:@"key"];
	NSString *defaults = [bundle objectForInfoDictionaryKey:@"defaults"] ?: bundle.bundleIdentifier;
	CFPropertyListRef value = CFPreferencesCopyAppValue((CFStringRef)key, (CFStringRef)defaults);
	BOOL result = [(id)value ?: [bundle objectForInfoDictionaryKey:@"default"] boolValue];
	if (value)
		CFRelease(value);
	if ([[bundle objectForInfoDictionaryKey:@"negate"] boolValue])
		result = !result;
	return result;
}

- (void)applyState:(A3ToggleState)newState forToggleIdentifier:(NSString *)toggleIdentifier
{
	if (newState == A3ToggleStateIndeterminate)
		return;
	NSString *key = [bundle objectForInfoDictionaryKey:@"key"];
	NSString *defaults = [bundle objectForInfoDictionaryKey:@"defaults"] ?: bundle.bundleIdentifier;
	if ([[bundle objectForInfoDictionaryKey:@"negate"] boolValue])
		newState = !newState;
	CFPreferencesSetAppValue((CFStringRef)key, newState ? kCFBooleanTrue : kCFBooleanFalse, (CFStringRef)defaults);
	CFPreferencesAppSynchronize((CFStringRef)defaults);
	NSString *notification = [bundle objectForInfoDictionaryKey:@"PostNotification"];
	if (notification) {
		notify_post([notification UTF8String]);
	}
}

- (void)_preferenceChanged
{
	NSString *defaults = [bundle objectForInfoDictionaryKey:@"defaults"] ?: bundle.bundleIdentifier;
	if (defaults) {
		CFPreferencesAppSynchronize((CFStringRef)defaults);
	}
	[[A3ToggleManager sharedToggleManager] stateDidChangeForToggleIdentifier: toggleIdentifier_];
}

static void A3PreferenceToggleChangedCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
	A3PreferenceToggle *toggle = observer;
	[toggle _preferenceChanged];
}

- (void)toggleWasRegisteredForIdentifier:(NSString *)toggleIdentifier
{
	[toggleIdentifier_ release];
	toggleIdentifier_ = [toggleIdentifier copy];
	NSString *notification = [bundle objectForInfoDictionaryKey:@"PostNotification"];
	if ([notification isKindOfClass:[NSString class]]) {
		CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), self, A3PreferenceToggleChangedCallback, (CFStringRef)notification, NULL, CFNotificationSuspensionBehaviorCoalesce);
	}
}

- (void)toggleWasUnregisteredForIdentifier:(NSString *)toggleIdentifier
{
	NSString *notification = [bundle objectForInfoDictionaryKey:@"PostNotification"];
	if ([notification isKindOfClass:[NSString class]]) {
		CFNotificationCenterRemoveObserver(CFNotificationCenterGetDarwinNotifyCenter(), self, (CFStringRef)notification, NULL);
	}
	[toggleIdentifier_ release];
	toggleIdentifier_ = nil;
}

@end
