#import "FSPreferenceSwitchDataSource.h"

#import "FSSwitchPanel.h"

#import <notify.h>

@implementation FSPreferenceSwitchDataSource

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
	[switchIdentifier_ release];
	[super dealloc];
}

- (NSBundle *)bundleForSwitchIdentifier:(NSString *)switchIdentifier
{
	return bundle;
}

- (FSSwitchState)stateForSwitchIdentifier:(NSString *)switchIdentifier
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

- (void)applyState:(FSSwitchState)newState forSwitchIdentifier:(NSString *)switchIdentifier
{
	if (newState == FSSwitchStateIndeterminate)
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
	[[FSSwitchPanel sharedPanel] stateDidChangeForSwitchIdentifier: switchIdentifier_];
}

static void FSPreferenceSwitchDataSourceChangedCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
	FSPreferenceSwitchDataSource *self = observer;
	[self _preferenceChanged];
}

- (void)switchWasRegisteredForIdentifier:(NSString *)switchIdentifier
{
	[switchIdentifier_ release];
	switchIdentifier_ = [switchIdentifier copy];
	NSString *notification = [bundle objectForInfoDictionaryKey:@"PostNotification"];
	if ([notification isKindOfClass:[NSString class]]) {
		CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), self, FSPreferenceSwitchDataSourceChangedCallback, (CFStringRef)notification, NULL, CFNotificationSuspensionBehaviorCoalesce);
	}
}

- (void)switchWasUnregisteredForIdentifier:(NSString *)switchIdentifier
{
	NSString *notification = [bundle objectForInfoDictionaryKey:@"PostNotification"];
	if ([notification isKindOfClass:[NSString class]]) {
		CFNotificationCenterRemoveObserver(CFNotificationCenterGetDarwinNotifyCenter(), self, (CFStringRef)notification, NULL);
	}
	[switchIdentifier_ release];
	switchIdentifier_ = nil;
}

@end
