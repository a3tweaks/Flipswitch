#import "A3PreferenceToggle.h"

#import "A3ToggleManager.h"

#import <notify.h>

static inline NSBundle *BundleForToggleIdentifier(NSString *toggleIdentifier)
{
	return [NSBundle bundleWithPath:[@"/Library/Toggles/" stringByAppendingPathComponent:toggleIdentifier]];
}

@implementation A3PreferenceToggle

- (id)init
{
	if ((self = [super init])) {
		notificationRegistrations = [[NSMutableDictionary alloc] init];
	}
	return self;
}

- (void)dealloc
{
	[notificationRegistrations release];
	[super dealloc];
}

- (NSBundle *)bundleForA3ToggleIdentifier:(NSString *)toggleIdentifier
{
	return BundleForToggleIdentifier(toggleIdentifier);
}

- (A3ToggleState)stateForToggleIdentifier:(NSString *)toggleIdentifier
{
	NSBundle *bundle = [self bundleForA3ToggleIdentifier:toggleIdentifier];
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
	NSBundle *bundle = [self bundleForA3ToggleIdentifier:toggleIdentifier];
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

static void A3PreferenceToggleChangedCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
	NSString *toggleIdentifier = observer;
	NSBundle *bundle = BundleForToggleIdentifier(toggleIdentifier);
	NSString *defaults = [bundle objectForInfoDictionaryKey:@"defaults"] ?: bundle.bundleIdentifier;
	if (defaults) {
		CFPreferencesAppSynchronize((CFStringRef)defaults);
	}
	[[A3ToggleManager sharedToggleManager] stateDidChangeForToggleIdentifier:observer];
}

- (void)toggleWasRegisteredForIdentifier:(NSString *)toggleIdentifier
{
	NSBundle *bundle = [self bundleForA3ToggleIdentifier:toggleIdentifier];
	NSString *notification = [bundle objectForInfoDictionaryKey:@"PostNotification"];
	if ([notification isKindOfClass:[NSString class]]) {
		toggleIdentifier = [toggleIdentifier copy];
		CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), toggleIdentifier, A3PreferenceToggleChangedCallback, (CFStringRef)notification, NULL, CFNotificationSuspensionBehaviorCoalesce);
		[notificationRegistrations setObject:notification forKey:toggleIdentifier];
		[toggleIdentifier release];
	}
}

- (void)toggleWasUnregisteredForIdentifier:(NSString *)toggleIdentifier
{
	NSString *notification = [notificationRegistrations objectForKey:toggleIdentifier];
	if (notification) {
		// Must unregister with the exact same observer pointer we registered with. Slow, but this shouldn't be in the common path
		for (NSString *key in notificationRegistrations) {
			if ([key isEqualToString:toggleIdentifier]) {
				toggleIdentifier = key;
				break;
			}
		}
		CFNotificationCenterRemoveObserver(CFNotificationCenterGetDarwinNotifyCenter(), toggleIdentifier, (CFStringRef)notification, NULL);
		[notificationRegistrations removeObjectForKey:toggleIdentifier];
	}
}

@end
