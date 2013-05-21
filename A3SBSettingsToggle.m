#import "A3SBSettingsToggle.h"

#import "A3ToggleManager.h"

#include <notify.h>
#include <dlfcn.h>
#import <CoreFoundation/CFUserNotification.h>

#define SBSFunction(toggle, name, def, funcType, ...) ({ const void *func = dlsym((toggle), #name); func ? ((funcType)func)(__VA_ARGS__) : (def); })
#define isCapable(toggle) SBSFunction(toggle, isCapable, YES, BOOL (*)(void))
#define isEnabled(toggle) SBSFunction(toggle, isEnabled, NO, BOOL (*)(void))
#define getStateFast(toggle) SBSFunction(toggle, getStateFast, NO, BOOL (*)(void))
#define setState(toggle, newState) SBSFunction(toggle, setState, NO, BOOL (*)(BOOL), newState)
#define getDelayTime(toggle) SBSFunction(toggle, getDelayTime, 0.0f, float (*)(void))
#define allowInCall(toggle) SBSFunction(toggle, allowInCall, NO, BOOL (*)(void))
#define invokeHoldAction(toggle) SBSFunction(toggle, invokeHoldAction, NO, BOOL (*)(void))
#define getStateTryFast(toggle) SBSFunction(toggle, getStateFast, isEnabled(toggle), BOOL (*)(void))

static inline NSString *ToggleNameFromToggleIdentifer(NSString *toggleIdentifier)
{
	NSInteger location = [toggleIdentifier rangeOfString:@"."].location;
	return (location == NSNotFound) ? toggleIdentifier : [toggleIdentifier substringFromIndex:location + 1];
}
#define ToggleIdentifierFromToggleName(toggleName) ([@"sbsettings." stringByAppendingString:toggleName])

static CFMutableDictionaryRef toggles;

@implementation A3SBSettingsToggle

static A3SBSettingsToggle *sharedToggle;

+ (void)initialize
{
	if (self == [A3SBSettingsToggle class]) {
		sharedToggle = [[self alloc] init];
	}
}

+ (id)sharedToggle
{
	return sharedToggle;
}

+ (NSString *)togglesPath
{
	return @"/var/mobile/Library/SBSettings/Toggles/";
}

- (id)init
{
	if ((self = [super init])) {
		toggles = CFDictionaryCreateMutable(kCFAllocatorDefault, 0, &kCFTypeDictionaryKeyCallBacks, NULL);
		NSFileManager *fileManager = [NSFileManager defaultManager];
		NSString *togglesPath = [A3SBSettingsToggle togglesPath];
		for (NSString *subpath in [fileManager contentsOfDirectoryAtPath:togglesPath error:NULL]) {
			if ([subpath hasPrefix:@"."])
				continue;
			if ([subpath isEqualToString:@"Fast Notes"])
				continue;
			if ([subpath isEqualToString:@"Brightness"])
				continue;
			if ([subpath isEqualToString:@"Processes"])
				continue;
			NSString *togglePath = [[togglesPath stringByAppendingPathComponent:subpath] stringByAppendingPathComponent:@"Toggle.dylib"];
			void *toggle = dlopen([togglePath UTF8String], RTLD_LAZY);
			if (toggle && isCapable(toggle)) {
				[[A3ToggleManager sharedToggleManager] registerToggle:self forIdentifier:ToggleIdentifierFromToggleName(subpath)];
				CFDictionaryAddValue(toggles, subpath, toggle);
			} else {
				dlclose(toggle);
			}
		}
	}
	return self;
}

- (NSString *)titleForToggleIdentifier:(NSString *)toggleIdentifier
{
	NSString *toggleName = ToggleNameFromToggleIdentifer(toggleIdentifier);
	return toggleName;
}

- (A3ToggleState)stateForToggleIdentifier:(NSString *)toggleIdentifier
{
	NSString *toggleName = ToggleNameFromToggleIdentifer(toggleIdentifier);
	void *toggle = (void *)CFDictionaryGetValue(toggles, toggleName);
	return isEnabled(toggle);
}

- (void)applyState:(A3ToggleState)newState forToggleIdentifier:(NSString *)toggleIdentifier
{
	if (newState == A3ToggleStateIndeterminate)
		return;
	NSString *toggleName = ToggleNameFromToggleIdentifer(toggleIdentifier);
	void *toggle = (void *)CFDictionaryGetValue(toggles, toggleName);
	BOOL currentState = isEnabled(toggle);
	if (currentState != newState) {
		setState(toggle, newState);
		notify_post("com.sbsettings.refreshalltoggles");
	}
}

- (BOOL)hasAlternateActionForToggleIdentifier:(NSString *)toggleIdentifier
{
	NSString *toggleName = ToggleNameFromToggleIdentifer(toggleIdentifier);
	void *toggle = (void *)CFDictionaryGetValue(toggles, toggleName);
	return dlsym(toggle, "invokeHoldAction") != NULL;
}

- (void)applyAlternateActionForToggleIdentifier:(NSString *)toggleIdentifier
{
	NSString *toggleName = ToggleNameFromToggleIdentifer(toggleIdentifier);
	void *toggle = (void *)CFDictionaryGetValue(toggles, toggleName);
	invokeHoldAction(toggle);
}

@end
