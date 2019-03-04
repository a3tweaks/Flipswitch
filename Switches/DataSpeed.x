#import <FSSwitchDataSource.h>
#import <FSSwitchPanel.h>
#include <dlfcn.h>

#ifndef CTREGISTRATION_H_
extern CFStringRef const kCTRegistrationDataStatusChangedNotification;
extern CFStringRef const kCTRegistrationDataRateUnknown;
extern CFStringRef const kCTRegistrationDataRate2G;
extern CFStringRef const kCTRegistrationDataRate3G;
extern CFStringRef const kCTRegistrationDataRate4G;
CFArrayRef CTRegistrationCopySupportedDataRates();
CFStringRef CTRegistrationGetCurrentMaxAllowedDataRate();
void CTRegistrationSetMaxAllowedDataRate(CFStringRef dataRate);
#endif

#ifndef CTTELEPHONYCENTER_H_
CFNotificationCenterRef CTTelephonyCenterGetDefault();
void CTTelephonyCenterAddObserver(CFNotificationCenterRef center, const void *observer, CFNotificationCallback callBack, CFStringRef name, const void *object, CFNotificationSuspensionBehavior suspensionBehavior);
void CTTelephonyCenterRemoveObserver(CFNotificationCenterRef center, const void *observer, CFStringRef name, const void *object);
#endif

@interface NSObject (FSSwitchDataSource)
- (Class <FSSwitchSettingsViewController>)settingsViewControllerClassForSwitchIdentifier:(NSString *)switchIdentifier;
@end

@interface DataSpeedSwitch : NSObject <FSSwitchDataSource> {
@private
	NSBundle *_bundle;
}
@property (nonatomic, readonly) NSBundle *bundle;
@end

static BOOL Supports4G(void)
{
	CFArrayRef supportedDataRates = CTRegistrationCopySupportedDataRates();
	if (!supportedDataRates) {
		return NO;
	}
	BOOL result = [(NSArray *)supportedDataRates containsObject:(id)kCTRegistrationDataRate4G];
	CFRelease(supportedDataRates);
	return result;
}

static CFStringRef ChosenDataRateForSwitchState(FSSwitchState state)
{
	CFStringRef key = state == FSSwitchStateOn ? CFSTR("onDataRate") : CFSTR("offDataRate");
	Boolean valid;
	CFIndex value = CFPreferencesGetAppIntegerValue(key, CFSTR("com.a3tweaks.switch.dataspeed"), &valid);

	if (!valid) {
		if (Supports4G()) {
			return state == FSSwitchStateOn ? kCTRegistrationDataRate4G : kCTRegistrationDataRate3G;
		}
		return state == FSSwitchStateOn ? kCTRegistrationDataRate3G : kCTRegistrationDataRate2G;
	}

	switch (value) {
		case 0:
			return kCTRegistrationDataRate4G;
		case 1:
			return kCTRegistrationDataRate3G;
		default:
			return kCTRegistrationDataRate2G;
 	}
}

static void FSDataStatusChanged(void);

@implementation DataSpeedSwitch

- (id)init
{
	[self release];
	return nil;
}

- (id)initWithBundle:(NSBundle *)bundle
{
	if ((self = [super init])) {
		_bundle = [bundle retain];
	}

	return self;
}

- (void)dealloc
{
	[_bundle release];
	[super dealloc];
}

@synthesize bundle = _bundle;

- (NSBundle *)bundleForSwitchIdentifier:(NSString *)switchIdentifier
{
	return _bundle;
}

- (FSSwitchState)stateForSwitchIdentifier:(NSString *)switchIdentifier
{
	NSArray *supportedDataRates = [(NSArray *)CTRegistrationCopySupportedDataRates() autorelease];
	CFStringRef desiredDataRate = ChosenDataRateForSwitchState(FSSwitchStateOn);
	NSUInteger desiredRateIndex = [supportedDataRates indexOfObject:(id)desiredDataRate];
	if (desiredRateIndex == NSNotFound)
		return FSSwitchStateOff;
	NSUInteger currentRateIndex = [supportedDataRates indexOfObject:(id)CTRegistrationGetCurrentMaxAllowedDataRate()];
	if (currentRateIndex == NSNotFound)
		return FSSwitchStateOff;
	return currentRateIndex >= desiredRateIndex;
}

- (void)applyState:(FSSwitchState)newState forSwitchIdentifier:(NSString *)switchIdentifier
{
	if (newState == FSSwitchStateIndeterminate)
		return;
	NSArray *supportedDataRates = [(NSArray *)CTRegistrationCopySupportedDataRates() autorelease];
	CFStringRef desiredDataRate = ChosenDataRateForSwitchState(newState);
	NSUInteger desiredRateIndex = [supportedDataRates indexOfObject:(id)desiredDataRate];
	if (desiredRateIndex == NSNotFound)
		return;
	NSUInteger currentRateIndex = [supportedDataRates indexOfObject:(id)CTRegistrationGetCurrentMaxAllowedDataRate()];
	if (currentRateIndex == NSNotFound)
		return;
	if (currentRateIndex != desiredRateIndex) {
		void *coreTelephony = dlopen("/System/Library/Frameworks/CoreTelephony.framework/CoreTelephony", RTLD_LAZY);
		if (coreTelephony) {
			void (*CTRegistrationSetMaxAllowedDataRate)(CFStringRef) = dlsym(coreTelephony, "CTRegistrationSetMaxAllowedDataRate");
			if (CTRegistrationSetMaxAllowedDataRate) {
				CTRegistrationSetMaxAllowedDataRate((CFStringRef)desiredDataRate);
			}
		}
	}
}

- (void)applyAlternateActionForSwitchIdentifier:(NSString *)switchIdentifier
{
	NSURL *url = [NSURL URLWithString:(kCFCoreFoundationVersionNumber > 700.0f ? @"prefs:root=General&path=MOBILE_DATA_SETTINGS_ID" : @"prefs:root=General&path=Network")];
	[[FSSwitchPanel sharedPanel] openURLAsAlternateAction:url];
}

- (Class <FSSwitchSettingsViewController>)settingsViewControllerClassForSwitchIdentifier:(NSString *)switchIdentifier
{
	if (Supports4G()) {
		return [super settingsViewControllerClassForSwitchIdentifier:switchIdentifier];
	}
	return Nil;
}

static DataSpeedSwitch *activeSwitch;
static NSString *activeSwitchPath;

static void FSDataStatusChanged(void)
{
    NSString *bundlePath = nil;
	CFArrayRef supportedDataRates = CTRegistrationCopySupportedDataRates();
	if (supportedDataRates) {
		if ([(NSArray *)supportedDataRates containsObject:(id)kCTRegistrationDataRate3G]) {
			if ([(NSArray *)supportedDataRates containsObject:(id)kCTRegistrationDataRate4G] && CFEqual(ChosenDataRateForSwitchState(FSSwitchStateOn), kCTRegistrationDataRate4G)) {
				bundlePath = @"/Library/Switches/LTE.bundle";
			} else {
				bundlePath = @"/Library/Switches/3G.bundle";
			}
		}
		CFRelease(supportedDataRates);
	}
	DataSpeedSwitch *oldActiveSwitch = activeSwitch;
	if (!bundlePath && !oldActiveSwitch)
		return;
	NSString *oldActiveSwitchPath = activeSwitchPath;
	activeSwitchPath = [bundlePath copy];
	if (bundlePath) {
		if ([oldActiveSwitchPath isEqualToString:bundlePath]) {
			[[FSSwitchPanel sharedPanel] stateDidChangeForSwitchIdentifier:oldActiveSwitch.bundle.bundleIdentifier];
			return;
		}
		NSBundle *newBundle = [NSBundle bundleWithPath:bundlePath];
		activeSwitch = [[DataSpeedSwitch alloc] initWithBundle:newBundle];
		[[FSSwitchPanel sharedPanel] registerDataSource:activeSwitch forSwitchIdentifier:newBundle.bundleIdentifier];
	} else {
		activeSwitch = nil;
	}
	[oldActiveSwitchPath release];
	if (oldActiveSwitch) {
		[[FSSwitchPanel sharedPanel] unregisterSwitchIdentifier:oldActiveSwitch.bundle.bundleIdentifier];
		[oldActiveSwitch release];
	}
}

@end

%ctor
{
	if (kCFCoreFoundationVersionNumber < 700.0 || kCFCoreFoundationVersionNumber >= 1556.00) {
		return;
	}
	CTTelephonyCenterAddObserver(CTTelephonyCenterGetDefault(), NULL, (CFNotificationCallback)FSDataStatusChanged, kCTRegistrationDataStatusChangedNotification, NULL, CFNotificationSuspensionBehaviorCoalesce);
	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)FSDataStatusChanged, CFSTR("com.a3tweaks.switch.dataspeed"), NULL, CFNotificationSuspensionBehaviorCoalesce);
	FSDataStatusChanged();
}
