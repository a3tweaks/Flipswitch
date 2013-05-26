#import "FSSBSettingsSwitch.h"

#import "FSSwitchPanel.h"

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

static inline NSString *ToggleNameFromSwitchIdentifer(NSString *switchIdentifier)
{
	NSInteger location = [switchIdentifier rangeOfString:@"."].location;
	return (location == NSNotFound) ? switchIdentifier : [switchIdentifier substringFromIndex:location + 1];
}
#define SwitchIdentifierFromToggleName(toggleName) ([@"sbsettings." stringByAppendingString:toggleName])

static CFMutableDictionaryRef switches;

@implementation FSSBSettingsSwitch

static FSSBSettingsSwitch *sharedSwitch;

+ (void)initialize
{
	if (self == [FSSBSettingsSwitch class]) {
		sharedSwitch = [[self alloc] init];
	}
}

+ (id)sharedSwitch
{
	return sharedSwitch;
}

+ (NSString *)switchesPath
{
	return @"/var/mobile/Library/SBSettings/Switches/";
}

- (id)init
{
	if ((self = [super init])) {
		switches = CFDictionaryCreateMutable(kCFAllocatorDefault, 0, &kCFTypeDictionaryKeyCallBacks, NULL);
		NSFileManager *fileManager = [NSFileManager defaultManager];
		NSString *switchesPath = [FSSBSettingsSwitch switchesPath];
		for (NSString *subpath in [fileManager contentsOfDirectoryAtPath:switchesPath error:NULL]) {
			if ([subpath hasPrefix:@"."])
				continue;
			if ([subpath isEqualToString:@"Fast Notes"])
				continue;
			if ([subpath isEqualToString:@"Brightness"])
				continue;
			if ([subpath isEqualToString:@"Processes"])
				continue;
			NSString *switchPath = [[switchesPath stringByAppendingPathComponent:subpath] stringByAppendingPathComponent:@"Switch.dylib"];
			void *toggle = dlopen([switchPath UTF8String], RTLD_LAZY);
			if (toggle && isCapable(toggle)) {
				[[FSSwitchPanel sharedPanel] registerDataSource:self forSwitchIdentifier:SwitchIdentifierFromToggleName(subpath)];
				CFDictionaryAddValue(switches, subpath, toggle);
			} else {
				dlclose(toggle);
			}
		}
	}
	return self;
}

- (NSString *)titleForSwitchIdentifier:(NSString *)switchIdentifier
{
	NSString *toggleName = ToggleNameFromSwitchIdentifer(switchIdentifier);
	return toggleName;
}

- (FSSwitchState)stateForSwitchIdentifier:(NSString *)switchIdentifier
{
	NSString *toggleName = ToggleNameFromSwitchIdentifer(switchIdentifier);
	void *toggle = (void *)CFDictionaryGetValue(switches, toggleName);
	return isEnabled(toggle);
}

- (void)applyState:(FSSwitchState)newState forSwitchIdentifier:(NSString *)switchIdentifier
{
	if (newState == FSSwitchStateIndeterminate)
		return;
	NSString *toggleName = ToggleNameFromSwitchIdentifer(switchIdentifier);
	void *toggle = (void *)CFDictionaryGetValue(switches, toggleName);
	BOOL currentState = isEnabled(toggle);
	if (currentState != newState) {
		setState(toggle, newState);
		notify_post("com.sbsettings.refreshallswitches");
	}
}

- (BOOL)hasAlternateActionForSwitchIdentifier:(NSString *)switchIdentifier
{
	NSString *toggleName = ToggleNameFromSwitchIdentifer(switchIdentifier);
	void *toggle = (void *)CFDictionaryGetValue(switches, toggleName);
	return dlsym(toggle, "invokeHoldAction") != NULL;
}

- (void)applyAlternateActionForSwitchIdentifier:(NSString *)switchIdentifier
{
	NSString *toggleName = ToggleNameFromSwitchIdentifer(switchIdentifier);
	void *toggle = (void *)CFDictionaryGetValue(switches, toggleName);
	invokeHoldAction(toggle);
}

@end
