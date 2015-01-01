#import <FSSwitchDataSource.h>
#import <FSSwitchPanel.h>

#import <Preferences/Preferences.h>
#import <dlfcn.h>

#import <CaptainHook/CaptainHook.h>

#import "../../NSObject+FSSwitchDataSource.h"

@interface SBTelephonyManager : NSObject
+ (SBTelephonyManager *)sharedTelephonyManager;
@end

@interface WirelessModemController : PSListController {
}
- (id)internetTethering:(PSSpecifier *)specifier;
- (void)setInternetTethering:(id)value specifier:(PSSpecifier *)specifier;
@end

typedef enum {
	NETRB_SVC_STATE_ON = 1023,
	NETRB_SVC_STATE_OFF = 1022,
} NETRB_SVC_STATE;

@interface MISManager : NSObject
+ (MISManager *)sharedManager;
- (void)setState:(NETRB_SVC_STATE)state;
- (void)getState:(NETRB_SVC_STATE *)outState andReason:(int *)reason;
@end

static WirelessModemController *controller;
static MISManager *manager;
static PSSpecifier *specifier;
static NSInteger insideSwitch;
static FSSwitchState pendingState;

%group WirelessModemSettings

%hook UIAlertView

- (void)show
{
	if (insideSwitch) {
		// Make sure we're suppressing the right alert view
		if ([self numberOfButtons] == 2) {
			id<UIAlertViewDelegate> delegate = [self delegate];
			if ([delegate respondsToSelector:@selector(alertView:clickedButtonAtIndex:)]) {
				[delegate alertView:self clickedButtonAtIndex:0];
				return;
			}
		}
	}
	%orig();
}

%end

%hook WirelessModemController

- (void)_btPowerChangedHandler:(NSNotification *)notification
{
	// Just eat it!
}

%end

%end

@interface HotspotSwitch : NSObject <FSSwitchDataSource>
@end

static void UpdateSwitchStatus(void)
{
	[[FSSwitchPanel sharedPanel] performSelector:@selector(stateDidChangeForSwitchIdentifier:) withObject:[NSBundle bundleForClass:[HotspotSwitch class]].bundleIdentifier afterDelay:0.0];
}

%hook SBTelephonyManager

- (void)noteWirelessModemChanged
{
	%orig();
	pendingState = FSSwitchStateIndeterminate;
	UpdateSwitchStatus();
}

- (void)_queue_noteWirelessModemDynamicStoreChanged
{
	%orig();
	pendingState = FSSwitchStateIndeterminate;
	UpdateSwitchStatus();
}

%end

static void StateChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
	UpdateSwitchStatus();
}

@implementation HotspotSwitch

- (FSSwitchState)stateForSwitchIdentifier:(NSString *)switchIdentifier
{
	if (pendingState != FSSwitchStateIndeterminate)
		return pendingState;
	if (manager) {
		NETRB_SVC_STATE state = 0;
		[manager getState:&state andReason:NULL];
		switch (state) {
			case NETRB_SVC_STATE_ON:
				return FSSwitchStateOn;
			case NETRB_SVC_STATE_OFF:
				return FSSwitchStateOff;
			default:
				return FSSwitchStateIndeterminate;
		}
	}
	return [[controller internetTethering:specifier] boolValue];
}

- (void)applyState:(FSSwitchState)newState forSwitchIdentifier:(NSString *)switchIdentifier
{
	if (newState == FSSwitchStateIndeterminate)
		return;
	if (manager) {
		pendingState = newState;
		[manager setState:(newState == FSSwitchStateOn) ? NETRB_SVC_STATE_ON : NETRB_SVC_STATE_OFF];
		return;
	}
	insideSwitch++;
	[controller setInternetTethering:[NSNumber numberWithBool:newState] specifier:specifier];
	insideSwitch--;
}

- (NSString *)descriptionOfState:(FSSwitchState)state forSwitchIdentifier:(NSString *)switchIdentifier
{
	switch (state) {
		case FSSwitchStateOn:
			if ([%c(SBTelephonyManager) respondsToSelector:@selector(sharedTelephonyManager)]) {
				SBTelephonyManager *manager = [%c(SBTelephonyManager) sharedTelephonyManager];
				int *_numberOfNetworkTetheredDevices = CHIvarRef(manager, _numberOfNetworkTetheredDevices, int);
				if (_numberOfNetworkTetheredDevices) {
					int deviceCount = *_numberOfNetworkTetheredDevices;
					switch (deviceCount) {
						case 0:
							break;
						case 1:
							return @"1 Connection";
						default:
							return [NSString stringWithFormat:@"%d Connections", deviceCount];
					}
				}
			}
		default:
			return [super descriptionOfState:state forSwitchIdentifier:switchIdentifier];
	}
}

@end

%ctor {
	pendingState = FSSwitchStateIndeterminate;
	Class _MISManager = objc_getClass("MISManager");
	%init();
	if ([_MISManager instancesRespondToSelector:@selector(getState:andReason:)] && [_MISManager instancesRespondToSelector:@selector(setState:)] && [_MISManager respondsToSelector:@selector(sharedManager)] && (manager = [_MISManager sharedManager]))
		return;
	// Load WirelessModemSettings
	dlopen("/System/Library/PreferenceBundles/WirelessModemSettings.bundle/WirelessModemSettings", RTLD_LAZY);
	%init(WirelessModemSettings);
	// Create root controller
	PSRootController *rootController = [[PSRootController alloc] initWithTitle:@"Preferences" identifier:@"com.apple.Preferences"];
	// Create controller
	controller = [[%c(WirelessModemController) alloc] initForContentSize:(CGSize){ 0.0f, 0.0f }];
	[controller setRootController:rootController];
	[controller setParentController:rootController];
	// Create Specifier
	specifier = [[PSSpecifier preferenceSpecifierNamed:@"Tethering" target:controller set:@selector(setInternetTethering:specifier:) get:@selector(internetTethering:) detail:Nil cell:PSSwitchCell edit:Nil] retain];
	CFNotificationCenterAddObserver(CFNotificationCenterGetLocalCenter(), StateChanged, StateChanged, CFSTR("SBNetworkTetheringStateChangedNotification"), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
}
